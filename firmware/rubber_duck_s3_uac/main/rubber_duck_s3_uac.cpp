// ============================================================
// RUBBER DUCK S3 UAC — Main Firmware
// ============================================================
// Seeed XIAO ESP32S3 Sense + servo + built-in NeoPixel.
// TTS/mic via USB Audio Class (UAC) — appears as "Duck Duck Duck"
// in macOS CoreAudio.
//
// Built with ESP-IDF + Arduino as component.
// ============================================================

#include <Arduino.h>
#include "Config.h"

// Forward declarations for functions defined later in this file
void updatePermissionNag(unsigned long now);

// --- Global State ---
EvalScores latestScores = {0, 0, 0, 0, 0, 'U', false};
bool newEvalAvailable = false;
float volumeScale = 0.8f;  // Default 80%, updated by widget VOL command

// --- Permission State ---
bool          permissionPending = false;
unsigned long permissionStartTime = 0;
unsigned long lastPermissionNag = 0;
unsigned long nextNagInterval = 0;

// --- Timing ---
unsigned long lastServoUpdate = 0;
unsigned long lastExpressionTime = 0;

// --- Button State ---
bool     buttonDown       = false;
unsigned long buttonDownAt = 0;

void setup() {
  Serial.begin(SERIAL_BAUD);
  while (!Serial && millis() < 3000) {
    delay(10);  // Wait up to 3s for USB-CDC to enumerate
  }
  delay(200);
  Serial.println();
  Serial.println("=== BOOT ===");

  #if ENABLE_AUDIO
    setupAudioI2S();
  #endif
  #if ENABLE_UAC
    setupUSBAudio();
  #endif
  #if ENABLE_STATUS_LED
    setupStatusLED();
  #endif
  #if ENABLE_SERVO
    setupServo();
  #endif

  #if ENABLE_BUTTON
    pinMode(BUTTON_PIN, INPUT_PULLUP);
  #endif

  // Startup animation
  #if ENABLE_STATUS_LED
    startupLEDAnimation();
  #endif
  #if ENABLE_SERVO
    startupServoAnimation();
  #endif

  Serial.println("[duck2] Ready. XIAO ESP32S3 UAC");
  Serial.println("[duck2] Protocol: {U|C},creativity,soundness,ambition,elegance,risk");
}

void loop() {
  unsigned long now = millis();

  // Serial input
  readSerial();

  // Button handling
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

  // Process new evaluation
  if (newEvalAvailable && !calibrationMode) {
    newEvalAvailable = false;

    if (permissionPending) {
      exitPermission();
    }

    #if ENABLE_STATUS_LED
      setStatusFromEval(latestScores);
    #endif

    #if ENABLE_SERVO
    {
      ServoTarget target = servoReducer(latestScores);
      setServoTarget(target);
    }
    #endif

    printEval(latestScores);
    lastExpressionTime = now;
  }

  // Expression decay → idle breathe
  if (latestScores.isValid && !permissionPending &&
      (now - lastExpressionTime) > EXPRESSION_HOLD_MS) {
    latestScores.isValid = false;
    #if ENABLE_STATUS_LED
      startStatusBreathe();
    #endif
  }

  // Fixed-rate updates
  if (now - lastServoUpdate >= SERVO_UPDATE_MS) {
    lastServoUpdate = now;

    #if ENABLE_SERVO
    if (!calibrationMode) {
      updateServo();
    }
    #endif

    #if ENABLE_STATUS_LED
      updateStatusLED();
    #endif
  }

  // Permission nag loop
  if (permissionPending) {
    updatePermissionNag(now);
  }
}

// --- Permission State Machine ---

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

  Serial.println("[perm] nag");
}

void enterPermission() {
  permissionPending = true;
  permissionStartTime = millis();
  lastPermissionNag = 0;
  #if ENABLE_STATUS_LED
    setPermissionStrobe(true);
  #endif
  Serial.println("[perm] === PERMISSION PENDING ===");
}

void exitPermission() {
  permissionPending = false;
  #if ENABLE_STATUS_LED
    setPermissionStrobe(false);
  #endif
  resetAmbient();
  Serial.println("[perm] === PERMISSION RESOLVED ===");
}

// --- Debug print ---
void printEval(EvalScores &scores) {
  Serial.print("[duck2] ");
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
