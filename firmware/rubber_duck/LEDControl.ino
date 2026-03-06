// ============================================================
// LED Duck — Reducer + Control
// ============================================================
// The LED duck is a 10-segment bar graph on a PCB with a piezo.
// Expression vocabulary:
//   - Fill level: overall approval (0-10 segments)
//   - Brightness: ambition intensity
//   - Flash: brief all-on burst when new eval arrives
//   - Sound: ascending chirp (good) / descending buzz (bad)

// --- LED State ---
float    ledCurrentBrightness[10] = {0};
float    ledTargetBrightness[10]  = {0};
bool     ledIsFlashing = false;
unsigned long ledFlashStart = 0;

// --- Piezo State ---
bool     chirpActive = false;
unsigned long chirpStart = 0;
int      chirpStartFreq = 400;
int      chirpEndFreq = 600;
bool     chirpBuzzy = false;

// ============================================================
// REDUCER: scores → LED + piezo target
// ============================================================
LEDTarget ledReducer(EvalScores &scores) {
  LEDTarget target;

  // Weighted approval → fill count
  float approval =
    scores.soundness  * 0.30 +
    scores.elegance   * 0.25 +
    scores.creativity * 0.20 +
    scores.ambition   * 0.15 -
    scores.risk       * 0.10;

  // Map from (-1..1) to (0..10)
  int fillCount = (int)round(((approval + 1.0f) / 2.0f) * 10.0f);
  target.fillCount = constrain(fillCount, 0, 10);

  // Brightness from ambition intensity
  target.brightness = 0.4 + abs(scores.ambition) * 0.6;

  // Sound: sentiment determines direction
  float sentiment = (scores.soundness + scores.elegance + scores.creativity) / 3.0f;
  target.chirpFreq = CHIRP_BASE_FREQ + (int)(sentiment * 200);

  if (sentiment > 0) {
    // Ascending chirp (positive)
    target.chirpEndFreq = target.chirpFreq * 1.4;
  } else {
    // Descending tone (negative)
    target.chirpEndFreq = target.chirpFreq * 0.6;
  }

  // Risk → buzzy quality
  target.chirpBuzzy = (scores.risk > 0.3);

  return target;
}

// ============================================================
// Set new target (called when eval arrives)
// ============================================================
void setLEDTarget(LEDTarget &target) {
  for (int i = 0; i < NUM_LEDS; i++) {
    ledTargetBrightness[i] = (i < target.fillCount) ? target.brightness : 0.0;
  }

  // Trigger flash
  ledIsFlashing = true;
  ledFlashStart = millis();
}

// ============================================================
// Trigger piezo chirp
// ============================================================
void playChirp(LEDTarget &target) {
  chirpActive = true;
  chirpStart = millis();
  chirpStartFreq = target.chirpFreq;
  chirpEndFreq = target.chirpEndFreq;
  chirpBuzzy = target.chirpBuzzy;

  tone(PIEZO_PIN, chirpStartFreq);
}

// ============================================================
// Fixed-rate update (called every SERVO_UPDATE_MS)
// ============================================================
void updateLEDs() {
  unsigned long now = millis();

  // Flash phase: all LEDs bright amber
  if (ledIsFlashing) {
    if (now - ledFlashStart < LED_FLASH_MS) {
      for (int i = 0; i < NUM_LEDS; i++) {
        strip.setPixelColor(i, strip.Color(255, 153, 34)); // bright amber
      }
      strip.show();
      return;
    } else {
      ledIsFlashing = false;
    }
  }

  // Lerp each segment toward target with staggered timing
  for (int i = 0; i < NUM_LEDS; i++) {
    // Stagger: each segment slightly slower than the previous
    float speed = LED_LERP_SPEED * (1.0 - i * 0.06);
    ledCurrentBrightness[i] = lerpf(ledCurrentBrightness[i], ledTargetBrightness[i], speed);

    // Map brightness to amber color
    float b = ledCurrentBrightness[i];
    uint8_t r = (uint8_t)(255 * b);
    uint8_t g = (uint8_t)(100 * b);  // amber tint
    uint8_t bl = (uint8_t)(5 * b);   // tiny blue for warmth

    strip.setPixelColor(i, strip.Color(r, g, bl));
  }
  strip.show();

  // Piezo chirp: slide frequency over duration
  if (chirpActive) {
    unsigned long elapsed = now - chirpStart;
    if (elapsed < CHIRP_DURATION) {
      float t = (float)elapsed / (float)CHIRP_DURATION;
      int freq = chirpStartFreq + (int)((chirpEndFreq - chirpStartFreq) * t);

      if (chirpBuzzy) {
        // Buzzy: rapid on/off toggling for sawtooth-like effect
        if ((elapsed / 10) % 2 == 0) {
          tone(PIEZO_PIN, freq);
        } else {
          noTone(PIEZO_PIN);
        }
      } else {
        tone(PIEZO_PIN, freq);
      }
    } else {
      noTone(PIEZO_PIN);
      chirpActive = false;
    }
  }
}
