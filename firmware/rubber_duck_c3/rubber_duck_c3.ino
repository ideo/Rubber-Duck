// ============================================================
// RUBBER DUCK C3 — Main Firmware
// ============================================================
// Audio duck: Seeed XIAO ESP32-C3 (or S3) + MAX98357 I2S DAC
// + servo. Receives eval scores AND streamed TTS audio from
// the widget over USB CDC serial.
//
// Serial protocol:
//   Text mode: same as Teensy/S3 ducks (newline-terminated)
//   Audio mode: binary framing (entered via A,16000,16,1\n)
//
// Board: Seeed XIAO ESP32-C3 or XIAO ESP32-S3 Sense
//        (select the correct board in Arduino IDE)
//
// Wiring (S3 with ICS-43434 I2S mic):
//   D0  → Servo signal
//   D1  → ICS-43434 SD (data out)
//   D2  → MAX98357 BCLK
//   D3  → MAX98357 LRC (WS)
//   D4  → MAX98357 DIN
//   D5  → (free — was analog mic)
//   D8  → Button (internal pullup)
//   D9  → ICS-43434 SCK (bit clock)
//   D10 → ICS-43434 WS (word select)
//   3V3 → MAX98357 VIN + SD (enable) + ICS-43434 VDD
//   GND → MAX98357 GND + Servo GND + ICS-43434 GND + L/R
//   5V  → Servo VCC (if available, otherwise 3V3)
// ============================================================

#include "Config.h"

// --- Global State ---
EvalScores latestScores = {0, 0, 0, 0, 0, 'U', false};
bool newEvalAvailable = false;

// --- Permission State ---
bool          permissionPending = false;
unsigned long permissionStartTime = 0;
unsigned long lastPermissionNag = 0;
unsigned long nextNagInterval = 0;

// --- Deferred Chirp (play after TTS drain) ---
bool       deferredChirp = false;
EvalScores deferredChirpScores = {0, 0, 0, 0, 0, 'U', false};

// --- Timing ---
unsigned long lastServoUpdate = 0;
unsigned long lastExpressionTime = 0;

// --- Button State ---
bool          buttonDown   = false;
unsigned long buttonDownAt = 0;

void setup() {
  Serial.setRxBufferSize(16384); // Large USB CDC RX buffer — prevents byte loss during i2s writes
  Serial.begin(SERIAL_BAUD);
  Serial.setTimeout(10);         // Short timeout for readBytes (default 1000ms!)
  while (!Serial && millis() < 3000) {
    delay(10);
  }
  delay(200);

  Serial.println();
  Serial.println("=== RUBBER DUCK C3 ===");

  // Mic must init before audio on S3 — I2S mic takes I2S_NUM_0,
  // speaker moves to I2S_NUM_1. On C3, mic uses ADC (no I2S conflict).
  #if ENABLE_MIC
    setupMic();
  #endif
  #if ENABLE_AUDIO
    setupAudio();
  #endif
  #if ENABLE_SERVO
    setupServo();
  #endif
  #if ENABLE_BUTTON
    pinMode(BUTTON_PIN, INPUT_PULLUP);
  #endif

  // Startup servo wiggle + chirp
  #if ENABLE_SERVO
    startupServoAnimation();
  #endif
  #if ENABLE_AUDIO
    playStartupChirp();
  #endif

  Serial.println("[duck] Ready. XIAO ESP32 + MAX98357");
  Serial.println("[duck] Protocol: text + binary audio framing");
  Serial.print("[duck] Ring buffer: ");
  Serial.print(RING_BUF_SAMPLES);
  Serial.print(" samples (");
  Serial.print(RING_BUF_SAMPLES * 2 / 1024);
  Serial.println("KB)");
}

void loop() {
  unsigned long now = millis();

  // --- Serial input (text or binary depending on mode) ---
  // Read serial FIRST and OFTEN — CDC buffer overflow = lost bytes = desync.
  readSerial();

  // --- Feed I2S from ring buffer (if streaming or chirping) ---
  #if ENABLE_AUDIO
    updateChirp();      // Generate chirp samples into ring buffer
    audioFeedI2S();     // Drain ring buffer to I2S DMA
    // Read serial again immediately after I2S write to minimize CDC buffer buildup
    readSerial();

    // Play deferred chirp after TTS drain completes
    if (deferredChirp && !isAudioStreaming()) {
      ChirpTarget ct = chirpReducer(deferredChirpScores);
      playChirp(ct);
      deferredChirp = false;
    }
  #endif

  // --- Mic capture: sample ADC + stream frames to widget ---
  #if ENABLE_MIC
    updateMic();
  #endif

  // --- Button handling ---
  #if ENABLE_BUTTON
  {
    bool pressed = (digitalRead(BUTTON_PIN) == LOW);

    if (pressed && !buttonDown) {
      buttonDown = true;
      buttonDownAt = now;
    }
    else if (pressed && buttonDown) {
      if ((now - buttonDownAt) >= LONG_PRESS_MS) {
        snapToCenter();
        buttonDown = false;
      }
    }
    else if (!pressed && buttonDown) {
      buttonDown = false;
      unsigned long held = now - buttonDownAt;

      if (held < LONG_PRESS_MS && held > 50) {
        if (calibrationMode) {
          advanceCalibration();
        } else {
          triggerDemoPreset();
        }
      }
    }
  }
  #endif

  // --- Process new evaluation ---
  if (newEvalAvailable && !calibrationMode) {
    newEvalAvailable = false;

    if (permissionPending) {
      exitPermission();
    }

    #if ENABLE_SERVO
    {
      ServoTarget target = servoReducer(latestScores);
      setServoTarget(target);
    }
    #endif

    // Chirp on eval — normally plays before TTS (widget delays audio mode entry).
    // If somehow audio IS streaming (e.g. rapid-fire evals), defer the chirp.
    #if ENABLE_AUDIO
    if (!isAudioStreaming()) {
      ChirpTarget ct = chirpReducer(latestScores);
      playChirp(ct);
      deferredChirp = false;
    } else {
      deferredChirp = true;
      deferredChirpScores = latestScores;
    }
    #endif

    printEval(latestScores);
    lastExpressionTime = now;
  }

  // --- Fixed-rate servo update ---
  if (now - lastServoUpdate >= SERVO_UPDATE_MS) {
    lastServoUpdate = now;

    #if ENABLE_SERVO
    if (!calibrationMode) {
      updateServo();
    }
    #endif
  }

  // --- Permission nag loop ---
  if (permissionPending) {
    updatePermissionNag(now);
  }
}

// ============================================================
// Permission State Machine
// ============================================================

void updatePermissionNag(unsigned long now) {
  if ((now - lastPermissionNag) <= nextNagInterval) return;

  lastPermissionNag = now;
  unsigned long elapsed = now - permissionStartTime;

  if (elapsed > PERMISSION_RARE_AT) {
    nextNagInterval = PERMISSION_RARE_BASE + random(PERMISSION_RARE_JITTER);
  } else if (elapsed > PERMISSION_BACKOFF_AT) {
    nextNagInterval = PERMISSION_LAZY_BASE + random(PERMISSION_LAZY_JITTER);
  } else {
    nextNagInterval = PERMISSION_NAG_BASE + random(-PERMISSION_NAG_JITTER, PERMISSION_NAG_JITTER + 1);
  }

  #if ENABLE_AUDIO
    playPermissionChirp();
  #endif
  Serial.println("[perm] nag");
}

void enterPermission() {
  permissionPending = true;
  permissionStartTime = millis();
  lastPermissionNag = 0;

  // If TTS is playing, stop it — permission takes over
  #if ENABLE_AUDIO
  if (isAudioStreaming()) {
    audioStreamEnd();
    Serial.println("[perm] Interrupted TTS for permission");
  }
  #endif

  #if ENABLE_AUDIO
    playPermissionChirp();
  #endif
  Serial.println("[perm] === PERMISSION PENDING ===");
}

void exitPermission() {
  permissionPending = false;
  chirpServoOffset = 0.0f;  // Clear any stuck whistle/chirp offset
  resetAmbient();            // Settle back from nag positions
  Serial.println("[perm] === PERMISSION RESOLVED ===");
}

// ============================================================
// Debug
// ============================================================

void printEval(EvalScores &scores) {
  Serial.print("[duck] ");
  Serial.print(scores.source == 'U' ? "USER" : "CLAUDE");
  Serial.print(" | cre:");
  Serial.print(scores.creativity, 2);
  Serial.print(" snd:");
  Serial.print(scores.soundness, 2);
  Serial.print(" amb:");
  Serial.print(scores.ambition, 2);
  Serial.print(" elg:");
  Serial.print(scores.elegance, 2);
  Serial.print(" rsk:");
  Serial.println(scores.risk, 2);
}
