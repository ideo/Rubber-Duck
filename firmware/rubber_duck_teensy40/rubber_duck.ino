// ============================================================
// RUBBER DUCK — Main Firmware
// ============================================================
// Receives multi-dimensional evaluation scores over serial,
// drives servo and LED+piezo actuators via reducers.
//
// Serial protocol (newline-terminated):
//   U,0.20,0.70,0.00,0.60,-0.30    (user evaluation)
//   C,0.20,0.70,0.00,0.60,-0.30    (claude evaluation)
//   Order: creativity, soundness, ambition, elegance, risk
//
// USB Audio: Set USB Type to "Serial + MIDI + Audio" in Arduino IDE
//   Tools → USB Type → Serial + MIDI + Audio
//   This makes the Teensy appear as both a serial device AND a USB microphone.
//
// Compatible with Teensy 4.0 / 3.x / Arduino boards
// ============================================================

#include "Config.h"
#include <PWMServo.h>

#if ENABLE_I2S_AUDIO || ENABLE_USB_AUDIO
#include <Audio.h>
#endif

// --- Global State ---
EvalScores latestScores = {0, 0, 0, 0, 0, 'U', false};
bool newEvalAvailable = false;

// --- Permission State ---
bool          permissionPending = false;
unsigned long permissionStartTime = 0;
unsigned long lastPermissionNag = 0;
unsigned long nextNagInterval = 0;      // Randomized per-nag

// --- Hardware ---
PWMServo servo;

// --- Timing ---
unsigned long lastServoUpdate = 0;

// --- Button State (for short/long press detection) ---
bool     buttonDown       = false;
unsigned long buttonDownAt = 0;
#define LONG_PRESS_MS     2000   // Hold 2s for snap-to-center

void setup() {
  Serial.begin(SERIAL_BAUD);

  // Servo
  #if ENABLE_SERVO_DUCK
    servo.attach(SERVO_PIN);
    servo.write(SERVO_CENTER);
    Serial.println("[duck] Servo duck enabled on pin " + String(SERVO_PIN));
  #endif

  // LEDs + Piezo
  #if ENABLE_LED_DUCK
    strip.begin();
    strip.setBrightness(LED_BRIGHTNESS);
    strip.clear();
    strip.show();
    Serial.println("[duck] LED duck enabled on pin " + String(LED_PIN));

    pinMode(PIEZO_PIN, OUTPUT);
    Serial.println("[duck] Piezo enabled on pin " + String(PIEZO_PIN));
  #endif

  // Audio subsystem — shared memory for I2S output + USB mic
  #if ENABLE_I2S_AUDIO || ENABLE_USB_AUDIO
    AudioMemory(20);
  #endif

  // I2S Audio (MAX98357 chirps)
  setupI2SAudio();

  // USB Audio bridge (mic → USB)
  setupAudioBridge();

  // Mode toggle button
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.println("[duck] Mode button on pin " + String(BUTTON_PIN));

  // Startup animation
  startupAnimation();

  Serial.println("[duck] Ready. Waiting for evaluations...");
  Serial.println("[duck] Protocol: {U|C},creativity,soundness,ambition,elegance,risk");
  Serial.println("[duck] Audio cmds: G,<gain> M,<0|1> V");
}

void loop() {
  unsigned long now = millis();

  // Check for incoming serial data
  readSerial();

  // Button handling: short press = demo preset cycle, long press = snap to center
  bool pressed = (digitalRead(BUTTON_PIN) == LOW);

  if (pressed && !buttonDown) {
    // Button just pressed down
    buttonDown = true;
    buttonDownAt = now;
  }
  else if (pressed && buttonDown) {
    // Button held — check for long press
    if ((now - buttonDownAt) >= LONG_PRESS_MS) {
      snapToCenter();
      buttonDown = false;  // Consume the press, don't fire short press on release
    }
  }
  else if (!pressed && buttonDown) {
    // Button released — short press if wasn't consumed by long press
    buttonDown = false;
    unsigned long held = now - buttonDownAt;

    if (held < LONG_PRESS_MS && held > 50) {  // 50ms debounce floor
      if (calibrationMode) {
        advanceCalibration();
      } else {
        triggerDemoPreset();
      }
    }
  }

  // Process new evaluation if available (skip during calibration)
  if (newEvalAvailable && !calibrationMode) {
    newEvalAvailable = false;

    // Any new eval means the session moved on — permission was handled
    if (permissionPending) {
      exitPermission();
    }

    #if ENABLE_SERVO_DUCK
      ServoTarget target = servoReducer(latestScores);
      setServoTarget(target);
    #endif

    #if ENABLE_LED_DUCK
    {
      LEDTarget ledTarget = ledReducer(latestScores);
      setLEDTarget(ledTarget);
      playChirp(ledTarget);
    }
    #endif

    // I2S chirp (independent of LED duck)
    #if ENABLE_I2S_AUDIO
    {
      ChirpTarget chirp = chirpReducer(latestScores);
      playI2SChirp(chirp);
    }
    #endif

    // Debug output
    printEval(latestScores);
  }

  // Dead level hold (must run before servo update)
  updateDeadLevel();

  // Fixed-rate updates (skip spring physics during calibration)
  #if ENABLE_SERVO_DUCK
  if (!calibrationMode && !deadLevelActive && (now - lastServoUpdate >= SERVO_UPDATE_MS)) {
    lastServoUpdate = now;
    updateServo();
  }
  #endif

  #if ENABLE_LED_DUCK
  if (now - lastLEDUpdate >= SERVO_UPDATE_MS) {
    lastLEDUpdate = now;
    updateLEDs();
  }
  #endif

  // Permission nag loop
  if (permissionPending) {
    updatePermissionNag(now);
  }

  // I2S audio chirp update
  updateI2SAudio();

  // USB Audio bridge
  updateAudioBridge();
}

// --- Startup animation: sweep servo + fill LEDs ---
void startupAnimation() {
  #if ENABLE_LED_DUCK
    for (int i = 0; i < NUM_LEDS; i++) {
      strip.setPixelColor(i, strip.Color(255, 153, 34));  // Amber
      strip.show();
      delay(60);
    }
    delay(200);
    for (int i = NUM_LEDS - 1; i >= 0; i--) {
      strip.setPixelColor(i, strip.Color(0, 0, 0));
      strip.show();
      delay(40);
    }
  #endif

  #if ENABLE_SERVO_DUCK
    servo.write(SERVO_CENTER - 30);
    delay(300);
    servo.write(SERVO_CENTER + 30);
    delay(300);
    servo.write(SERVO_CENTER);
    delay(200);
  #endif

  #if ENABLE_LED_DUCK
    // Happy chirp (piezo)
    tone(PIEZO_PIN, 400, 100);
    delay(120);
    tone(PIEZO_PIN, 600, 100);
    delay(120);
    noTone(PIEZO_PIN);
  #endif

  #if ENABLE_I2S_AUDIO
    playStartupChirp();
  #endif
}

// --- Permission State Machine ---

// Three-tier nag: urgent (4-8s) → lazy (15-30s) → rare (5-10min)
// Defers while TTS is speaking — timer restarts after speech ends.
void updatePermissionNag(unsigned long now) {
  if ((now - lastPermissionNag) <= nextNagInterval) return;

  // Don't chirp over TTS — defer the nag until speech finishes
  if (ttsActive) {
    lastPermissionNag = now;  // Reset timer so it starts fresh after TTS
    return;
  }

  lastPermissionNag = now;
  unsigned long elapsed = now - permissionStartTime;

  if (elapsed > PERMISSION_RARE_AT) {
    nextNagInterval = PERMISSION_RARE_BASE + random(PERMISSION_RARE_JITTER);
  } else if (elapsed > PERMISSION_BACKOFF_AT) {
    nextNagInterval = PERMISSION_LAZY_BASE + random(PERMISSION_LAZY_JITTER);
  } else {
    nextNagInterval = PERMISSION_NAG_BASE + random(-PERMISSION_NAG_JITTER, PERMISSION_NAG_JITTER + 1);
  }

  #if ENABLE_I2S_AUDIO
    playPermissionChirp();
  #endif
}

void enterPermission() {
  permissionPending = true;
  permissionStartTime = millis();
  lastPermissionNag = 0;  // Chirp immediately
  Serial.println("[perm] === PERMISSION PENDING ===");

  #if ENABLE_I2S_AUDIO
    playPermissionChirp();
  #endif
}

void exitPermission() {
  permissionPending = false;
  chirpServoOffset = 0.0;
  resetAmbient();  // Settle back from nag positions
  Serial.println("[perm] === PERMISSION RESOLVED ===");
}

// --- Debug print ---
void printEval(EvalScores &scores) {
  // Scores already logged widget-side — firmware stays quiet
}
