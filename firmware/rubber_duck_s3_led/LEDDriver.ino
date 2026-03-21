// ============================================================
// LED Driver — TLC59711 Reducer + Animation Engine
// ============================================================
// Drives a 10-segment LED bar graph through a TLC59711
// 12-channel 16-bit PWM driver. Two spare channels (10-11)
// available for accent lighting.
//
// Expression vocabulary (LED-first duck):
//   - Fill level: overall approval (0-10 segments)
//   - Per-segment brightness: 16-bit smooth fading
//   - Flash burst: brief all-on when new eval arrives
//   - Breathe pulse: idle heartbeat when at rest
//   - Scatter shimmer: risk → random per-segment flicker
//   - Permission strobe: alternating segments during nag
//
// The TLC59711 uses Adafruit's library (bit-banged SPI).
// Install: Arduino Library Manager → "Adafruit TLC59711"

#if ENABLE_LED_BAR

#include <Adafruit_TLC59711.h>

Adafruit_TLC59711 tlc(TLC_NUM_DRIVERS, TLC_CLOCK_PIN, TLC_DATA_PIN);

// --- Per-Segment State (16-bit) ---
uint16_t ledCurrent[LED_BAR_SEGMENTS]  = {0};
float    ledTarget[LED_BAR_SEGMENTS]   = {0};  // 0.0-1.0 (mapped to 16-bit on write)
float    ledCurrentF[LED_BAR_SEGMENTS] = {0};  // Float tracking for smooth lerp

// --- Accent Channel State ---
float    accentTargetA = 0.0;
float    accentTargetB = 0.0;
float    accentCurrentA = 0.0;
float    accentCurrentB = 0.0;

// --- Animation State ---
bool     ledFlashing = false;
unsigned long ledFlashStart = 0;
unsigned long lastLEDUpdate = 0;

// --- Shimmer State (risk overlay) ---
// Each segment gets a slow sine wave at a different phase/speed.
// Looks like nervous breathing, not a bad connection.
float    shimmerIntensity = 0.0;       // 0.0 = none, 1.0 = full
float    shimmerPhase[LED_BAR_SEGMENTS] = {0};
float    shimmerSpeed[LED_BAR_SEGMENTS] = {0};  // Radians per frame

// --- Breathe State (idle) ---
bool     breatheActive = false;
unsigned long breatheStart = 0;

// --- Knight Rider Sweep (impressed/whistle equivalent) ---
bool     sweepActive = false;
unsigned long sweepStart = 0;
#define  SWEEP_DURATION_MS  1800  // Full sweep cycle time
#define  SWEEP_WIDTH        2.0f  // Width of the bright spot (in segments)
#define  SWEEP_SENTIMENT_THRESHOLD 0.6f  // Trigger above this sentiment

// --- Permission Strobe ---
bool     permStrobePhase = false;
unsigned long lastPermStrobe = 0;
#define  PERM_STROBE_MS 400

// ============================================================
// REDUCER: scores → LED bar target
// ============================================================
LEDBarTarget ledBarReducer(EvalScores &scores) {
  LEDBarTarget target;

  // Weighted approval → fill count (same formula as Teensy)
  float approval =
    scores.soundness  * 0.30f +
    scores.elegance   * 0.25f +
    scores.creativity * 0.20f +
    scores.ambition   * 0.15f -
    scores.risk       * 0.10f;

  // Map from (-1..1) to (0..10)
  int fill = (int)round(((approval + 1.0f) / 2.0f) * (float)LED_BAR_SEGMENTS);
  target.fillCount = constrain(fill, 0, LED_BAR_SEGMENTS);

  // Brightness from ambition intensity
  target.segmentBrightness = 0.4f + fabs(scores.ambition) * 0.6f;

  // Accent channels: creativity drives accent A, elegance drives accent B
  target.accentBrightness = (scores.creativity + 1.0f) / 2.0f;  // 0..1

  // Risk → shimmer intensity
  shimmerIntensity = max(0.0f, scores.risk) * 0.5f;

  // Pulse rate from ambition (high ambition = faster pulse overlay)
  target.pulseRate = fabs(scores.ambition) * 2.0f;  // 0-2 Hz

  // Knight Rider sweep on highly positive sentiment (the LED "whistle")
  float sentiment = (scores.soundness + scores.elegance + scores.creativity) / 3.0f;
  if (sentiment > SWEEP_SENTIMENT_THRESHOLD) {
    sweepActive = true;
    sweepStart = millis();
  } else {
    sweepActive = false;
  }

  target.flash = true;  // Always flash on new eval

  return target;
}

// ============================================================
// Apply target (called when eval arrives)
// ============================================================
void setLEDBarTarget(LEDBarTarget &target) {
  // Fill from center outward with anti-aliased edges.
  // fillCount maps to a float radius — edge segments get fractional brightness.
  float center = ((float)LED_BAR_SEGMENTS - 1.0f) / 2.0f;  // 4.5
  float radius = (float)target.fillCount / 2.0f;  // 0-5.0

  for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
    float dist = fabs((float)i - center);  // 0.5 for seg4/5, 1.5 for seg3/6, etc.
    float coverage = constrain(radius - dist + 0.5f, 0.0f, 1.0f);
    ledTarget[i] = coverage * target.segmentBrightness;
  }

  accentTargetA = target.accentBrightness;
  accentTargetB = target.accentBrightness * 0.6f;  // Dimmer complement

  // Trigger flash
  if (target.flash) {
    ledFlashing = true;
    ledFlashStart = millis();
  }

  // Stop idle breathing — we have real data now
  breatheActive = false;
}

// ============================================================
// Setup (called from main setup())
// ============================================================
void setupLEDs() {
  tlc.begin();
  tlc.simpleSetBrightness(127);  // Global brightness (0-127)

  // Clear all channels
  for (int i = 0; i < TLC_NUM_CHANNELS; i++) {
    tlc.setPWM(i, 0);
  }
  tlc.write();

  // Randomize shimmer phases so segments don't sync
  for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
    shimmerPhase[i] = ((float)random(0, 628)) / 100.0f;  // 0 to 2π
    shimmerSpeed[i] = 0.03f + ((float)random(0, 40)) / 1000.0f;  // 0.03-0.07 rad/frame (~0.5-1.1Hz)
  }

  breatheActive = true;
  breatheStart = millis();

  Serial.println("[led] TLC59711 initialized (" +
                 String(TLC_NUM_CHANNELS) + " channels, data=" +
                 String(TLC_DATA_PIN) + " clk=" + String(TLC_CLOCK_PIN) + ")");
}

// ============================================================
// Startup animation — sweep fill then fade
// ============================================================
void startupLEDAnimation() {
  // Sweep on: grow from center outward
  // Order: 4,5 → 3,6 → 2,7 → 1,8 → 0,9
  int center = LED_BAR_SEGMENTS / 2;
  for (int ring = 0; ring < center; ring++) {
    int left = center - 1 - ring;
    int right = center + ring;
    tlc.setPWM(LED_BAR_FIRST_CH + left, LED_MAX_BRIGHTNESS);
    tlc.setPWM(LED_BAR_FIRST_CH + right, LED_MAX_BRIGHTNESS);
    tlc.write();
    delay(80);
  }

  // Accent flash
  tlc.setPWM(LED_ACCENT_CH_A, LED_MAX_BRIGHTNESS);
  tlc.setPWM(LED_ACCENT_CH_B, LED_MAX_BRIGHTNESS);
  tlc.write();
  delay(200);

  // Sweep off: shrink back to center
  for (int ring = center - 1; ring >= 0; ring--) {
    int left = center - 1 - ring;
    int right = center + ring;
    tlc.setPWM(LED_BAR_FIRST_CH + left, 0);
    tlc.setPWM(LED_BAR_FIRST_CH + right, 0);
    tlc.write();
    delay(50);
  }
  tlc.setPWM(LED_ACCENT_CH_A, 0);
  tlc.setPWM(LED_ACCENT_CH_B, 0);
  tlc.write();
}

// ============================================================
// Fixed-rate update (called every SERVO_UPDATE_MS from loop)
// ============================================================
void updateLEDs() {
  unsigned long now = millis();

  // --- Flash phase: all segments at max ---
  if (ledFlashing) {
    if (now - ledFlashStart < LED_FLASH_MS) {
      for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
        tlc.setPWM(LED_BAR_FIRST_CH + i, LED_MAX_BRIGHTNESS);
      }
      tlc.setPWM(LED_ACCENT_CH_A, LED_MAX_BRIGHTNESS);
      tlc.setPWM(LED_ACCENT_CH_B, LED_MAX_BRIGHTNESS / 2);
      tlc.write();
      return;
    }
    ledFlashing = false;
  }

  // --- Knight Rider sweep: bright spot bounces left↔right ---
  if (sweepActive) {
    unsigned long elapsed = now - sweepStart;
    if (elapsed > SWEEP_DURATION_MS) {
      sweepActive = false;
      // Fall through to normal expression rendering below
    } else {
      // Ping-pong: 0→1→0 over the duration
      float t = (float)elapsed / (float)SWEEP_DURATION_MS;
      float ping = (t < 0.5f) ? (t * 2.0f) : (2.0f - t * 2.0f);  // 0→1→0
      // Ease it for smooth acceleration at edges
      float eased = 0.5f - 0.5f * cos(ping * PI);
      // Map to segment position (0.0 to 9.0)
      float spotCenter = eased * (float)(LED_BAR_SEGMENTS - 1);

      for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
        float dist = fabs((float)i - spotCenter);
        float brightness = constrain(1.0f - (dist / SWEEP_WIDTH), 0.0f, 1.0f);
        // Square it for tighter falloff
        brightness *= brightness;
        uint16_t pwm = (uint16_t)(brightness * LED_MAX_BRIGHTNESS);
        tlc.setPWM(LED_BAR_FIRST_CH + i, pwm);
      }

      tlc.setPWM(LED_ACCENT_CH_A, (uint16_t)(eased * LED_MAX_BRIGHTNESS * 0.5f));
      tlc.setPWM(LED_ACCENT_CH_B, (uint16_t)((1.0f - eased) * LED_MAX_BRIGHTNESS * 0.5f));
      tlc.write();
      return;
    }
  }

  // --- Permission strobe: alternating odd/even segments ---
  if (permissionPending) {
    if (now - lastPermStrobe > PERM_STROBE_MS) {
      permStrobePhase = !permStrobePhase;
      lastPermStrobe = now;
    }

    for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
      bool on = (i % 2 == 0) ? permStrobePhase : !permStrobePhase;
      uint16_t val = on ? (LED_MAX_BRIGHTNESS / 2) : (LED_MAX_BRIGHTNESS / 8);
      tlc.setPWM(LED_BAR_FIRST_CH + i, val);
    }

    // Accent channels pulse with strobe
    tlc.setPWM(LED_ACCENT_CH_A, permStrobePhase ? LED_MAX_BRIGHTNESS : 0);
    tlc.setPWM(LED_ACCENT_CH_B, permStrobePhase ? 0 : LED_MAX_BRIGHTNESS);
    tlc.write();
    return;
  }

  // --- Idle breathe (when no recent eval) ---
  // A soft shape grows and shrinks from center. The "radius" is floating-point,
  // so edge segments get fractional brightness (anti-aliased).
  // Radius oscillates between ~1.0 (center 2 only) and ~3.0 (center 6 segments).
  if (breatheActive) {
    float t = (float)((now - breatheStart) % LED_BREATHE_PERIOD) / (float)LED_BREATHE_PERIOD;
    float wave = 0.5f + 0.5f * sin(t * 2.0f * PI - PI / 2.0f);  // 0→1→0

    float radius = 1.5f + wave * 1.0f;  // 1.5 to 2.5 segments from center (3-5 pixels)
    float peakBright = LED_BREATHE_MIN + (LED_BREATHE_MAX - LED_BREATHE_MIN) * wave;

    float center = ((float)LED_BAR_SEGMENTS - 1.0f) / 2.0f;  // 4.5

    for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
      float dist = fabs((float)i - center);  // 0.5 for seg4/5, 1.5 for seg3/6, etc.
      float coverage = constrain(radius - dist + 0.5f, 0.0f, 1.0f);
      // coverage: 1.0 = fully inside shape, 0.0 = fully outside, fractional = edge
      uint16_t val = (uint16_t)(coverage * peakBright * LED_MAX_BRIGHTNESS);
      tlc.setPWM(LED_BAR_FIRST_CH + i, val);
    }

    tlc.setPWM(LED_ACCENT_CH_A, (uint16_t)(peakBright * 0.3f * LED_MAX_BRIGHTNESS));
    tlc.setPWM(LED_ACCENT_CH_B, 0);
    tlc.write();
    return;
  }

  // --- Normal expression: lerp toward target with smooth shimmer ---
  for (int i = 0; i < LED_BAR_SEGMENTS; i++) {
    // Smooth 16-bit interpolation
    float speed = LED_LERP_SPEED * (1.0f - i * 0.04f);
    ledCurrentF[i] = lerpf(ledCurrentF[i], ledTarget[i], speed);

    // Risk shimmer: slow per-segment sine waves (nervous breathing, not glitchy)
    float shimmer = 0.0f;
    if (shimmerIntensity > 0.01f) {
      shimmerPhase[i] += shimmerSpeed[i];
      if (shimmerPhase[i] > 6.2832f) shimmerPhase[i] -= 6.2832f;
      shimmer = sin(shimmerPhase[i]) * shimmerIntensity * 0.3f;
    }

    float finalBrightness = constrain(ledCurrentF[i] + shimmer, 0.0f, 1.0f);
    uint16_t pwm = (uint16_t)(finalBrightness * LED_MAX_BRIGHTNESS);
    tlc.setPWM(LED_BAR_FIRST_CH + i, pwm);
  }

  // Accent channels
  accentCurrentA = lerpf(accentCurrentA, accentTargetA, LED_LERP_SPEED);
  accentCurrentB = lerpf(accentCurrentB, accentTargetB, LED_LERP_SPEED);
  tlc.setPWM(LED_ACCENT_CH_A, (uint16_t)(accentCurrentA * LED_MAX_BRIGHTNESS));
  tlc.setPWM(LED_ACCENT_CH_B, (uint16_t)(accentCurrentB * LED_MAX_BRIGHTNESS));

  tlc.write();
}

// ============================================================
// Enter idle breathing (called after expression hold expires)
// ============================================================
void startBreathe() {
  if (!breatheActive) {
    breatheActive = true;
    breatheStart = millis();
  }
}

#else

// Stubs when LED bar is disabled
void setupLEDs() {}
void startupLEDAnimation() {}
void updateLEDs() {}
void setLEDBarTarget(LEDBarTarget &target) {}
void startBreathe() {}
unsigned long lastLEDUpdate = 0;

#endif // ENABLE_LED_BAR
