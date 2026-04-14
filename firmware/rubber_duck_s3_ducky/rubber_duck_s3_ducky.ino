// ============================================================
// RUBBER DUCK S3 DUCKY — Main Firmware
// ============================================================
// Custom Ducky PCB with ESP32-S3-WROOM-1-N8R8 module.
//
// On-board peripherals:
//   MAX98357  I2S speaker amp (GPIO7 DIN, GPIO13 BCLK, GPIO12 LRCLK)
//   ICS-43432 I2S MEMS mic    (GPIO1 SD, shared BCLK/LRCLK)
//   WS2812B   NeoPixel LED    (GPIO38 via BSS138 level shifter)
//   Servo     3-pin header    (GPIO3 signal, 5V, GND)
//   Button    user button S3  (GPIO2, active LOW)
//   USB-C     power + data    (GPIO19/20 D-/D+)
//
// I2S architecture: speaker and mic share BCLK/LRCLK on a single
// I2S port in full-duplex mode. setupAudio() MUST run before
// setupMic() — the RX handle is allocated by AudioStream.ino.
//
// Serial protocol:
//   Text mode: newline-terminated (same as all duck variants)
//   Audio mode: binary framing (entered via A,16000,16,1\n)
//
// Board config in Arduino IDE:
//   Board: ESP32S3 Dev Module
//   USB CDC On Boot: Enabled
//   USB Mode: Hardware CDC and JTAG
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

// Forward declarations — NeoPixelStatus.ino
extern void neoSetFromScores(EvalScores &scores);

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
bool          longPressConsumed = false;

// --- Button Modes ---
bool          demoMode = false;
unsigned long demoModeEnteredAt = 0;
unsigned long lastDemoPress = 0;
#define       DEMO_AUTO_EXIT_MS 30000

unsigned long lastVolumePress = 0;
#define       VOLUME_CYCLE_WINDOW_MS 15000

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
  Serial.setRxBufferSize(16384);
  Serial.begin(SERIAL_BAUD);
  Serial.setTimeout(10);
  while (!Serial && millis() < 1000) {
    delay(10);
  }

  if (Serial) {
    Serial.println();
    Serial.println("=== DUCK DUCK DUCK — Ducky PCB ===");
  }

  // NeoPixel first — gives immediate visual feedback during boot
  #if ENABLE_NEOPIXEL
    setupNeoPixel();
  #endif

  // Audio MUST init before mic — full-duplex I2S allocates both TX+RX.
  // The RX handle (sharedMicRxHandle) is created by setupAudio().
  #if ENABLE_AUDIO
    setupAudio();
  #endif
  #if ENABLE_MIC
    setupMic();
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
    Serial.println("[duck] Ready. Ducky PCB — ESP32-S3 + MAX98357 + ICS-43432");
    Serial.println("[duck] Protocol: text + binary audio framing");
    Serial.flush();
  }
  delay(200);
}

void loop() {
  unsigned long now = millis();

  // --- Serial input (text or binary depending on mode) ---
  readSerial();

  // --- Feed I2S from ring buffer (if streaming or chirping) ---
  #if ENABLE_AUDIO
    updateChirp();
    storedAudioFeed();
    audioFeedI2S();
    readSerial();  // Read again after I2S write to minimize CDC buffer buildup

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

  // --- Mic capture: stream frames to widget ---
  #if ENABLE_MIC
    updateMic();
  #endif

  // --- NeoPixel status update ---
  #if ENABLE_NEOPIXEL
    updateNeoPixel();
  #endif

  // --- Button handling ---
  // Normal mode: short press cycles volume levels
  // Demo mode: short press cycles demo presets with quips
  // 2s hold: toggle between modes
  // 5s hold: reboot
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
        Serial.println("[duck] Rebooting via button...");
        Serial.flush();
        delay(100);
        esp_restart();
      } else if (held >= LONG_PRESS_MS && !longPressConsumed) {
        longPressConsumed = true;
        demoMode = !demoMode;
        if (demoMode) {
          Serial.println("[button] Entering demo mode");
          deferredDemoMode = true;
          demoModeEnteredAt = now;
          lastDemoPress = now;
          #if ENABLE_AUDIO
            playStartupChirp();
          #endif
          #if ENABLE_NEOPIXEL
            neoPixelFlash(40, 0, 60);  // Purple flash for demo mode
          #endif
          deadLevelActive = true;
          deadLevelStart = now;
          snapToCenter();
          demoStep = 0;
        } else {
          Serial.println("[button] Exiting demo mode");
          deferredNormalMode = true;
          #if ENABLE_NEOPIXEL
            neoPixelFlash(0, 40, 0);   // Green flash for normal mode
          #endif
        }
      }
    }
    else if (!pressed && buttonDown) {
      buttonDown = false;
      unsigned long held = now - buttonDownAt;

      if (!longPressConsumed && held > 50) {
        if (calibrationMode) {
          advanceCalibration();
        } else if (demoMode) {
          triggerDemoPreset();
          deferredQuip = true;
          lastDemoPress = now;
        } else {
          bool shouldCycle = (now - lastVolumePress) < VOLUME_CYCLE_WINDOW_MS;
          lastVolumePress = now;

          if (shouldCycle) {
            volumeStep = (volumeStep + 1) % NUM_VOLUME_PRESETS;
            float vol = volumePresets[volumeStep];
            if (volumeStep == NUM_VOLUME_PRESETS - 1) {
              volumeScale = 0.25f;
            } else {
              volumeScale = vol;
            }
            char volCmd[16];
            snprintf(volCmd, sizeof(volCmd), "VOL,%.2f", vol);
            Serial.println(volCmd);
            Serial.printf("[button] Volume -> %.2f (step %d)\n", vol, volumeStep);
          } else {
            Serial.printf("[button] Volume announce (step %d)\n", volumeStep);
          }
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

    // NeoPixel sentiment flash
    #if ENABLE_NEOPIXEL
    {
      float sentiment =
        latestScores.soundness  * 0.30f +
        latestScores.elegance   * 0.25f +
        latestScores.creativity * 0.20f +
        latestScores.ambition   * 0.15f -
        latestScores.risk       * 0.10f;

      // Map sentiment (-1..1) to hue: red(0) -> yellow(60) -> green(120)
      float hue = (sentiment + 1.0f) / 2.0f * 120.0f;
      hue = constrain(hue, 0.0f, 120.0f);
      float value = 0.3f + fabsf(latestScores.ambition) * 0.7f;

      // Simple HSV->RGB for the flash
      float c = value;
      float x = c * (1.0f - fabsf(fmodf(hue / 60.0f, 2.0f) - 1.0f));
      uint8_t r, g, b;
      if      (hue < 60)  { r = (uint8_t)(c * 255); g = (uint8_t)(x * 255); b = 0; }
      else                 { r = (uint8_t)(x * 255); g = (uint8_t)(c * 255); b = 0; }
      neoPixelFlash(r, g, b);
    }
    #endif

    // Chirp on eval
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

  // --- Demo mode auto-exit ---
  if (demoMode && (now - lastDemoPress) > DEMO_AUTO_EXIT_MS) {
    demoMode = false;
    Serial.println("[button] Demo mode auto-exit (30s timeout)");
  }
}

// ============================================================
// Permission State Machine
// ============================================================

void updatePermissionNag(unsigned long now) {
  if ((now - lastPermissionNag) <= nextNagInterval) return;

  #if ENABLE_AUDIO
  if (isAudioStreaming()) {
    lastPermissionNag = now;
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

  #if ENABLE_NEOPIXEL
    neoPixelFlash(60, 0, 0);  // Red flash on nag
  #endif
}

void enterPermission() {
  permissionPending = true;
  permissionStartTime = millis();
  lastPermissionNag = 0;

  #if ENABLE_AUDIO
  if (isAudioStreaming()) {
    audioStreamEnd();
    Serial.println("[perm] Interrupted TTS for permission");
  }
  #endif

  #if ENABLE_AUDIO
    playPermissionChirp();
  #endif

  #if ENABLE_NEOPIXEL
    neoPixelFlash(80, 0, 0);  // Bright red flash
  #endif

  Serial.println("[perm] === PERMISSION PENDING ===");
}

void exitPermission() {
  permissionPending = false;
  chirpServoOffset = 0.0f;
  resetAmbient();
  Serial.println("[perm] === PERMISSION RESOLVED ===");
}

// ============================================================
// Debug
// ============================================================

void printEval(EvalScores &scores) {
  // Scores already logged widget-side — firmware stays quiet
}
