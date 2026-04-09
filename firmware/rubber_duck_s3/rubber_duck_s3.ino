// ============================================================
// DUCK DUCK DUCK — ESP32-S3 Firmware
// ============================================================
// Seeed XIAO ESP32-S3 + MAX98357 I2S DAC + ICS-43434 mic + servo.
// Receives eval scores and streamed TTS audio from the widget
// over USB CDC serial.
//
// Serial protocol:
//   Text mode: newline-terminated (same as all duck variants)
//   Audio mode: binary framing (entered via A,16000,16,1\n)
//
// Board: Seeed XIAO ESP32-S3 (select ESP32S3 Dev Module in Arduino)
//
// Wiring:
//   D0  → MAX98357 LRC (WS)
//   D1  → MAX98357 BCLK
//   D2  → MAX98357 DIN
//   D3  → Servo signal
//   D4  → (free)
//   D5  → Button (internal pullup)
//   D8  → ICS-43434 BCLK (bit clock)
//   D9  → ICS-43434 DOUT (data out)
//   D10 → ICS-43434 LRCL (word select)
//   3V3 → MAX98357 VIN + SD (enable) + ICS-43434 VDD
//   GND → MAX98357 GND + Servo GND + ICS-43434 GND + L/R
//   5V  → Servo VCC (if available, otherwise 3V3)
// ============================================================

#include "Config.h"
#include "StoredPhrases.h"

// Forward declarations — StoredAudio.ino
void storedAudioPlay(const int16_t* phrase, uint32_t sampleCount);
void storedAudioPlayQuip();
void storedAudioPlayVolume(uint8_t step);
bool isStoredAudioPlaying();
bool isAudioBusy();
void snapToCenter();

// Defined in ServoControl.ino
extern bool deadLevelActive;
extern unsigned long deadLevelStart;
extern int demoStep;

// --- Global State ---
EvalScores latestScores = {0, 0, 0, 0, 0, 'U', false};
bool newEvalAvailable = false;
float volumeScale = 0.5f;  // Default 50%, updated by widget VOL command

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
bool          longPressConsumed = false;  // Prevent short-press firing after 2s hold

// --- Button Modes ---
bool          demoMode = false;
unsigned long demoModeEnteredAt = 0;
unsigned long lastDemoPress = 0;
#define       DEMO_AUTO_EXIT_MS 30000  // Exit demo mode after 30s of no button press

unsigned long lastVolumePress = 0;
#define       VOLUME_CYCLE_WINDOW_MS 15000  // Press within 15s to cycle, otherwise just announce

// Volume presets (parallel to VOL_PHRASE_TABLE in StoredPhrases.h)
const float   volumePresets[] = { 0.75f, 0.50f, 0.25f, 0.05f, 0.00f };
#define       NUM_VOLUME_PRESETS 5
uint8_t       volumeStep = 1;  // Default: Normal (0.50)

// --- Stored Audio / Connection State ---
bool          widgetConnected = false;
unsigned long lastSerialRx    = 0;
bool          deferredQuip = false;
bool          deferredAwake = false;
bool          deferredConnected = false;
bool          deferredDemoMode = false;
bool          deferredNormalMode = false;
bool          deferredVolume = false;
uint8_t       deferredVolumeStep = 0;

void setup() {
  Serial.setRxBufferSize(16384); // Large USB CDC RX buffer — prevents byte loss during i2s writes
  Serial.begin(SERIAL_BAUD);
  Serial.setTimeout(10);         // Short timeout for readBytes (default 1000ms!)
  while (!Serial && millis() < 1000) {
    delay(10);
  }

  if (Serial) {
    Serial.println();
    Serial.println("=== DUCK DUCK DUCK S3 ===");
  }

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
    deferredAwake = true;
  #endif

  if (Serial) {
    Serial.println("[duck] Ready. XIAO ESP32 + MAX98357");
    Serial.println("[duck] Protocol: text + binary audio framing");
    Serial.flush();  // Ensure CDC buffer is sent before accepting commands
  }
  delay(200);  // Let USB CDC stabilize
}

void loop() {
  unsigned long now = millis();

  // --- Serial input (text or binary depending on mode) ---
  // Read serial FIRST and OFTEN — CDC buffer overflow = lost bytes = desync.
  readSerial();

  // --- Feed I2S from ring buffer (if streaming or chirping) ---
  #if ENABLE_AUDIO
    updateChirp();      // Generate chirp samples into ring buffer
    storedAudioFeed();  // Feed stored phrase samples into ring buffer
    audioFeedI2S();     // Drain ring buffer to I2S DMA
    // Read serial again immediately after I2S write to minimize CDC buffer buildup
    readSerial();

    // Play deferred chirp after TTS drain completes
    if (deferredChirp && !isAudioStreaming()) {
      ChirpTarget ct = chirpReducer(deferredChirpScores);
      playChirp(ct);
      deferredChirp = false;
    }

    // Play deferred phrases after chirp finishes
    if (!isAudioBusy() && !isStoredAudioPlaying()) {
      if (deferredAwake) {
        storedAudioPlay(PHRASE_AWAKE, PHRASE_AWAKE_LEN);
        deferredAwake = false;
      } else if (deferredConnected) {
        storedAudioPlay(PHRASE_CONNECTED, PHRASE_CONNECTED_LEN);
        deferredConnected = false;
      } else if (deferredDemoMode) {
        storedAudioPlay(PHRASE_DEMO_MODE, PHRASE_DEMO_MODE_LEN);
        deferredDemoMode = false;
      } else if (deferredNormalMode) {
        storedAudioPlay(PHRASE_NORMAL_MODE, PHRASE_NORMAL_MODE_LEN);
        deferredNormalMode = false;
      } else if (deferredVolume) {
        storedAudioPlayVolume(deferredVolumeStep);
        deferredVolume = false;
      } else if (deferredQuip) {
        storedAudioPlayQuip();
        deferredQuip = false;
      }
    }

  #endif

  // --- Mic capture: sample ADC + stream frames to widget ---
  #if ENABLE_MIC
    updateMic();
  #endif

  // --- Button handling ---
  // Normal mode: short press cycles volume levels
  // Demo mode: short press cycles demo presets with quips
  // 2s hold: toggle between modes
  // 5s hold: bootloader (both modes)
  #if ENABLE_BUTTON
  {
    bool pressed = (digitalRead(BUTTON_PIN) == LOW);

    if (pressed && !buttonDown) {
      buttonDown = true;
      buttonDownAt = now;
      longPressConsumed = false;
    }
    else if (pressed && buttonDown) {
      unsigned long held = now - buttonDownAt;
      if (held >= 5000) {
        // 5s hold → bootloader (both modes)
        Serial.println("[duck] Entering bootloader via button...");
        Serial.flush();
        delay(100);
        esp_restart();
      } else if (held >= LONG_PRESS_MS && !longPressConsumed) {
        // 2s hold → toggle demo mode
        longPressConsumed = true;
        demoMode = !demoMode;
        if (demoMode) {
          Serial.println("[button] Entering demo mode");
          deferredDemoMode = true;
          demoModeEnteredAt = now;
          lastDemoPress = now;
          // Startup chirp + dead level hold until first button press
          #if ENABLE_AUDIO
            playStartupChirp();
          #endif
          deadLevelActive = true;
          deadLevelStart = now;
          snapToCenter();
          demoStep = 0;
        } else {
          Serial.println("[button] Exiting demo mode");
          deferredNormalMode = true;
        }
      }
    }
    else if (!pressed && buttonDown) {
      buttonDown = false;
      unsigned long held = now - buttonDownAt;

      // Short press (< 2s, > 50ms debounce), only if 2s hold wasn't consumed
      if (!longPressConsumed && held > 50) {
        if (calibrationMode) {
          advanceCalibration();
        } else if (demoMode) {
          // Demo mode: cycle presets + quip
          triggerDemoPreset();
          deferredQuip = true;
          lastDemoPress = now;
        } else {
          // Normal mode: first press announces current, subsequent presses within 15s cycle
          bool shouldCycle = (now - lastVolumePress) < VOLUME_CYCLE_WINDOW_MS;
          lastVolumePress = now;

          if (shouldCycle) {
            volumeStep = (volumeStep + 1) % NUM_VOLUME_PRESETS;
            float vol = volumePresets[volumeStep];
            // For Silent, play at indoor voice level, then drop to 0 after phrase
            if (volumeStep == NUM_VOLUME_PRESETS - 1) {
              volumeScale = 0.25f;
            } else {
              volumeScale = vol;
            }
            // Send volume to widget
            char volCmd[16];
            snprintf(volCmd, sizeof(volCmd), "VOL,%.2f", vol);
            Serial.println(volCmd);
            Serial.printf("[button] Volume → %.2f (step %d)\n", vol, volumeStep);
          } else {
            Serial.printf("[button] Volume announce (step %d)\n", volumeStep);
          }
          // Either way, announce the current level
          deferredVolume = true;
          deferredVolumeStep = volumeStep;
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

  // --- Dead level hold (overrides servo) ---
  updateDeadLevel();

  // --- Fixed-rate servo update ---
  if (now - lastServoUpdate >= SERVO_UPDATE_MS) {
    lastServoUpdate = now;

    #if ENABLE_SERVO
    if (!calibrationMode && !deadLevelActive) {
      updateServo();
    }
    #endif
  }

  // --- Permission nag loop ---
  if (permissionPending) {
    updatePermissionNag(now);
  }

  // --- Demo mode auto-exit after 30s of no button press ---
  if (demoMode && (now - lastDemoPress) > DEMO_AUTO_EXIT_MS) {
    demoMode = false;
    Serial.println("[button] Demo mode auto-exit (30s timeout)");
  }
}

// ============================================================
// Permission State Machine
// ============================================================

// Defers while TTS is speaking — timer restarts after speech ends.
void updatePermissionNag(unsigned long now) {
  if ((now - lastPermissionNag) <= nextNagInterval) return;

  // Don't chirp over TTS — defer the nag until speech finishes
  #if ENABLE_AUDIO
  if (isAudioStreaming()) {
    lastPermissionNag = now;  // Reset timer so it starts fresh after TTS
    return;
  }
  #endif

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
  // Scores already logged widget-side — firmware stays quiet
}
