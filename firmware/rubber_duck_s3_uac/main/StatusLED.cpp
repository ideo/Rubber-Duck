// ============================================================
// StatusLED — Single NeoPixel status indicator
// ============================================================
// Uses the XIAO ESP32S3's built-in RGB LED (GPIO 48).
// neopixelWrite() is provided by the Arduino-ESP32 core.
// ============================================================

#include <Arduino.h>
#include "Config.h"

#if ENABLE_STATUS_LED

// --- Current color state (0–255 each) ---
static uint8_t currentR = 0, currentG = 0, currentB = 0;
static uint8_t targetR  = 0, targetG  = 0, targetB  = 0;

// --- Animation state ---
static bool     flashActive = false;
static bool     flashPhase  = false;
static unsigned long flashStart = 0;

static bool     breatheActive = false;
static float    breathePhase  = 0.0f;

static bool     permStrobing = false;

// --- Helpers ---
static uint8_t lerpByte(uint8_t a, uint8_t b, float t) {
  return (uint8_t)(a + (b - a) * t);
}

static void applyColor(uint8_t r, uint8_t g, uint8_t b) {
  currentR = r; currentG = g; currentB = b;
  neopixelWrite(STATUS_LED_PIN, r, g, b);
}

// --- Public API ---

void setupStatusLED() {
  pinMode(STATUS_LED_PIN, OUTPUT);
  applyColor(0, 0, 0);
}

void startupLEDAnimation() {
  // Quick green pulse to say "I'm alive"
  for (int i = 0; i <= 64; i += 4) {
    applyColor(0, i, 0);
    delay(10);
  }
  for (int i = 64; i >= 0; i -= 4) {
    applyColor(0, i, 0);
    delay(10);
  }
  applyColor(0, 0, 0);
}

// Set a target color to lerp toward
void setStatusColor(uint8_t r, uint8_t g, uint8_t b) {
  targetR = r; targetG = g; targetB = b;
  breatheActive = false;
  flashActive = false;
}

// Map eval sentiment to a color
void setStatusFromEval(EvalScores &scores) {
  float sentiment = scores.soundness * 0.3f + scores.elegance * 0.25f
                  + scores.creativity * 0.2f + scores.ambition * 0.15f
                  - scores.risk * 0.1f;

  // Map -1..1 → red..yellow..green
  uint8_t r, g, b = 0;
  if (sentiment > 0.3f) {
    // Good: green
    r = 0; g = 40; b = 0;
  } else if (sentiment > 0.0f) {
    // Neutral: dim yellow
    r = 30; g = 25; b = 0;
  } else if (sentiment > -0.3f) {
    // Meh: orange
    r = 40; g = 10; b = 0;
  } else {
    // Bad: red
    r = 40; g = 0; b = 0;
  }

  setStatusColor(r, g, b);

  // Brief flash on new eval
  flashActive = true;
  flashPhase = true;
  flashStart = millis();
}

void startStatusBreathe() {
  breatheActive = true;
  breathePhase = 0.0f;
}

void setPermissionStrobe(bool active) {
  permStrobing = active;
  if (!active) {
    applyColor(0, 0, 0);
  }
}

void updateStatusLED() {
  unsigned long now = millis();

  // Permission strobe takes priority — orange flash
  if (permStrobing) {
    bool on = ((now / 200) % 2) == 0;
    applyColor(on ? 60 : 0, on ? 25 : 0, 0);
    return;
  }

  // Flash on eval (bright burst, then fade)
  if (flashActive) {
    if (millis() - flashStart < STATUS_FLASH_MS) {
      // Bright white burst
      applyColor(80, 80, 80);
      return;
    } else {
      flashActive = false;
    }
  }

  // Idle breathe — gentle pulse
  if (breatheActive) {
    breathePhase += (2.0f * PI) / (STATUS_BREATHE_PERIOD / SERVO_UPDATE_MS);
    if (breathePhase > 2.0f * PI) breathePhase -= 2.0f * PI;
    float brightness = (sin(breathePhase) + 1.0f) * 0.5f;
    brightness = STATUS_BREATHE_MIN + brightness * (STATUS_BREATHE_MAX - STATUS_BREATHE_MIN);
    applyColor((uint8_t)(brightness * 236), (uint8_t)(brightness * 185), (uint8_t)(brightness * 71));
    return;
  }

  // Lerp toward target color
  uint8_t r = lerpByte(currentR, targetR, 0.08f);
  uint8_t g = lerpByte(currentG, targetG, 0.08f);
  uint8_t b = lerpByte(currentB, targetB, 0.08f);
  applyColor(r, g, b);
}

#else
// Stubs when status LED is disabled
void setupStatusLED() {}
void startupLEDAnimation() {}
void setStatusColor(uint8_t, uint8_t, uint8_t) {}
void setStatusFromEval(EvalScores &scores) {}
void startStatusBreathe() {}
void setPermissionStrobe(bool) {}
void updateStatusLED() {}
#endif
