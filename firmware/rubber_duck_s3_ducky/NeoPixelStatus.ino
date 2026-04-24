// ============================================================
// NeoPixel Status LED (Ducky Custom PCB)
// ============================================================
// Single WS2812B driven through BSS138 level shifter on GPIO38.
// Uses the ESP32 Arduino core's built-in neopixelWrite() — no
// external library needed.
//
// Status vocabulary:
//   Boot:        Blue pulse
//   Idle:        Gentle green breathing
//   Eval:        Sentiment hue flash (green→red)
//   Permission:  Red pulse
//   Audio:       Dim cyan
//   Demo mode:   Purple
// ============================================================

#if ENABLE_NEOPIXEL

// --- State ---
static uint8_t  neoR = 0, neoG = 0, neoB = 0;     // Current displayed color
static uint8_t  neoTargetR = 0, neoTargetG = 0, neoTargetB = 0;
static bool     neoFlashActive = false;
static unsigned long neoFlashStart = 0;
#define NEO_FLASH_MS 300

static unsigned long lastNeoUpdate = 0;
#define NEO_UPDATE_MS 40   // ~25 fps

// --- Breathing state ---
static unsigned long breathePhaseStart = 0;
#define NEO_BREATHE_PERIOD 4000  // ms per full breathe cycle

// ============================================================
// HSV to RGB helper (h: 0-360, s: 0-1, v: 0-1)
// ============================================================
static void hsvToRgb(float h, float s, float v, uint8_t &r, uint8_t &g, uint8_t &b) {
  float c = v * s;
  float x = c * (1.0f - fabsf(fmodf(h / 60.0f, 2.0f) - 1.0f));
  float m = v - c;

  float rf, gf, bf;
  if      (h < 60)  { rf = c; gf = x; bf = 0; }
  else if (h < 120) { rf = x; gf = c; bf = 0; }
  else if (h < 180) { rf = 0; gf = c; bf = x; }
  else if (h < 240) { rf = 0; gf = x; bf = c; }
  else if (h < 300) { rf = x; gf = 0; bf = c; }
  else              { rf = c; gf = 0; bf = x; }

  r = (uint8_t)((rf + m) * 255.0f);
  g = (uint8_t)((gf + m) * 255.0f);
  b = (uint8_t)((bf + m) * 255.0f);
}

// ============================================================
// Setup
// ============================================================
void setupNeoPixel() {
  pinMode(NEOPIXEL_PIN, OUTPUT);

  // Boot indicator: brief blue flash
  neopixelWrite(NEOPIXEL_PIN, 0, 0, 40);
  delay(200);
  neopixelWrite(NEOPIXEL_PIN, 0, 0, 0);

  breathePhaseStart = millis();
  Serial.printf("[neo] WS2812B ready on GPIO%d (via BSS138 level shifter)\n", NEOPIXEL_PIN);
}

// ============================================================
// Trigger a brief color flash (called on eval, permission, etc.)
// ============================================================
void neoPixelFlash(uint8_t r, uint8_t g, uint8_t b) {
  neoFlashActive = true;
  neoFlashStart = millis();
  neoR = r;
  neoG = g;
  neoB = b;
  neopixelWrite(NEOPIXEL_PIN, r, g, b);
}

// ============================================================
// Set sentiment color from eval scores
// ============================================================
void neoSetFromScores(EvalScores &scores) {
  float sentiment =
    scores.soundness  * 0.30f +
    scores.elegance   * 0.25f +
    scores.creativity * 0.20f +
    scores.ambition   * 0.15f -
    scores.risk       * 0.10f;

  // Map sentiment (-1..1) to hue: red(0) → yellow(60) → green(120)
  float hue = (sentiment + 1.0f) / 2.0f * 120.0f;
  hue = constrain(hue, 0.0f, 120.0f);

  // Intensity from ambition
  float value = 0.3f + fabsf(scores.ambition) * 0.7f;

  uint8_t r, g, b;
  hsvToRgb(hue, 1.0f, value, r, g, b);
  neoPixelFlash(r, g, b);
}

// ============================================================
// Fixed-rate update — call from loop()
// ============================================================
void updateNeoPixel() {
  unsigned long now = millis();
  if ((now - lastNeoUpdate) < NEO_UPDATE_MS) return;
  lastNeoUpdate = now;

  // --- Flash phase: hold color for NEO_FLASH_MS, then fade out ---
  if (neoFlashActive) {
    if ((now - neoFlashStart) < NEO_FLASH_MS) {
      // Hold flash color — already written
      return;
    }
    neoFlashActive = false;
    // Fall through to normal state
  }

  // --- Permission pending: red pulse ---
  if (permissionPending) {
    float t = (float)((now % 1000)) / 1000.0f;
    float wave = 0.5f + 0.5f * sinf(t * 2.0f * M_PI);
    uint8_t brightness = (uint8_t)(wave * 60.0f + 5.0f);
    neopixelWrite(NEOPIXEL_PIN, brightness, 0, 0);
    return;
  }

  // --- Audio streaming: dim cyan ---
  if (isAudioStreaming()) {
    neopixelWrite(NEOPIXEL_PIN, 0, 15, 20);
    return;
  }

  // --- Idle: gentle green breathing ---
  float phase = (float)((now - breathePhaseStart) % NEO_BREATHE_PERIOD) / (float)NEO_BREATHE_PERIOD;
  float wave = 0.5f + 0.5f * sinf(phase * 2.0f * M_PI - M_PI / 2.0f);

  uint8_t brightness = (uint8_t)(wave * 20.0f + 2.0f);
  neopixelWrite(NEOPIXEL_PIN, 0, brightness, brightness / 4);
}

#else

void setupNeoPixel() {}
void updateNeoPixel() {}
void neoPixelFlash(uint8_t r, uint8_t g, uint8_t b) {}

#endif // ENABLE_NEOPIXEL
