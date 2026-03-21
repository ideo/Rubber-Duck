// ============================================================
// RUBBER DUCK ESP32 — Main Firmware
// ============================================================
// Second duck: Seeed XIAO ESP32S3 Sense + TLC59711 LED driver.
// Receives the same serial protocol as the Teensy duck but
// expresses through 12-channel 16-bit PWM LEDs (+ optional servo).
//
// Serial protocol (newline-terminated):
//   U,0.20,0.70,0.00,0.60,-0.30    (user evaluation)
//   C,0.20,0.70,0.00,0.60,-0.30    (claude evaluation)
//   Order: creativity, soundness, ambition, elegance, risk
//
// Board: Seeed XIAO ESP32S3 Sense (Arduino IDE / PlatformIO)
// Libraries needed:
//   - Adafruit TLC59711 (Library Manager)
//   - (Servo uses raw LEDC PWM — no library needed)
// ============================================================

#include "Config.h"

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

  #if ENABLE_LED_BAR
    setupLEDs();
  #endif
  #if ENABLE_SERVO
    setupServo();
  #endif

  #if ENABLE_BUTTON
    pinMode(BUTTON_PIN, INPUT_PULLUP);
  #endif

  // Startup animation
  #if ENABLE_LED_BAR
    startupLEDAnimation();
  #endif
  #if ENABLE_SERVO
    startupServoAnimation();
  #endif

  Serial.println("[duck2] Ready. XIAO ESP32S3 + TLC59711");
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

    #if ENABLE_LED_BAR
    {
      LEDBarTarget ledTarget = ledBarReducer(latestScores);
      setLEDBarTarget(ledTarget);
    }
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

  // Expression decay → idle breathe (when servo is disabled, main loop owns this)
  #if ENABLE_LED_BAR && !ENABLE_SERVO
  if (latestScores.isValid && !permissionPending &&
      (now - lastExpressionTime) > EXPRESSION_HOLD_MS) {
    latestScores.isValid = false;  // Only trigger once
    startBreathe();
  }
  #endif

  // Fixed-rate updates
  if (now - lastServoUpdate >= SERVO_UPDATE_MS) {
    lastServoUpdate = now;

    #if ENABLE_SERVO
    if (!calibrationMode) {
      updateServo();
    }
    #endif

    #if ENABLE_LED_BAR
      updateLEDs();
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

  // LED strobe handles the visual nag in updateLEDs()
  Serial.println("[perm] nag");
}

void enterPermission() {
  permissionPending = true;
  permissionStartTime = millis();
  lastPermissionNag = 0;
  Serial.println("[perm] === PERMISSION PENDING ===");
}

void exitPermission() {
  permissionPending = false;
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
