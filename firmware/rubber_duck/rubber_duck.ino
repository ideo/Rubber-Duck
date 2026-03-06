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
#include <Adafruit_NeoPixel.h>

// --- Global State ---
EvalScores latestScores = {0, 0, 0, 0, 0, 'U', false};
bool newEvalAvailable = false;

// --- Hardware ---
PWMServo servo;
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// --- Timing ---
unsigned long lastServoUpdate = 0;
unsigned long lastLEDUpdate = 0;

void setup() {
  Serial.begin(SERIAL_BAUD);

  // Servo
  if (ENABLE_SERVO_DUCK) {
    servo.attach(SERVO_PIN);
    servo.write(SERVO_CENTER);
    Serial.println("[duck] Servo duck enabled on pin " + String(SERVO_PIN));
  }

  // LEDs
  if (ENABLE_LED_DUCK) {
    strip.begin();
    strip.setBrightness(LED_BRIGHTNESS);
    strip.clear();
    strip.show();
    Serial.println("[duck] LED duck enabled on pin " + String(LED_PIN));

    pinMode(PIEZO_PIN, OUTPUT);
    Serial.println("[duck] Piezo enabled on pin " + String(PIEZO_PIN));
  }

  // USB Audio bridge (mic → USB)
  setupAudioBridge();

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

  // Process new evaluation if available
  if (newEvalAvailable) {
    newEvalAvailable = false;

    if (ENABLE_SERVO_DUCK) {
      ServoTarget target = servoReducer(latestScores);
      setServoTarget(target);
    }

    if (ENABLE_LED_DUCK) {
      LEDTarget target = ledReducer(latestScores);
      setLEDTarget(target);
      playChirp(target);
    }

    // Debug output
    printEval(latestScores);
  }

  // Fixed-rate updates
  if (ENABLE_SERVO_DUCK && (now - lastServoUpdate >= SERVO_UPDATE_MS)) {
    lastServoUpdate = now;
    updateServo();
  }

  if (ENABLE_LED_DUCK && (now - lastLEDUpdate >= SERVO_UPDATE_MS)) {
    lastLEDUpdate = now;
    updateLEDs();
  }

  // USB Audio bridge
  updateAudioBridge();
}

// --- Startup animation: sweep servo + fill LEDs ---
void startupAnimation() {
  if (ENABLE_LED_DUCK) {
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
  }

  if (ENABLE_SERVO_DUCK) {
    servo.write(SERVO_CENTER - 30);
    delay(300);
    servo.write(SERVO_CENTER + 30);
    delay(300);
    servo.write(SERVO_CENTER);
    delay(200);
  }

  if (ENABLE_LED_DUCK) {
    // Happy chirp
    tone(PIEZO_PIN, 400, 100);
    delay(120);
    tone(PIEZO_PIN, 600, 100);
    delay(120);
    noTone(PIEZO_PIN);
  }
}

// --- Debug print ---
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
