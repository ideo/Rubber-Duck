// ============================================================
// Easing Functions
// ============================================================
// Ported from metro_0.1 — all take t in [0,1], return [0,1]

float cubicEase(float t) {
  if (t < 0.5f) {
    return 4.0f * t * t * t;
  } else {
    float p = (2.0f * t) - 2.0f;
    return 0.5f * p * p * p + 1.0f;
  }
}

float quarticEase(float t) {
  if (t < 0.5f) {
    return 8.0f * t * t * t * t;
  } else {
    float p = (2.0f * t) - 2.0f;
    return -0.5f * p * p * p * p + 1.0f;
  }
}

float quinticEase(float t) {
  if (t < 0.5f) {
    return 16.0f * t * t * t * t * t;
  } else {
    float p = (2.0f * t) - 2.0f;
    return 0.5f * p * p * p * p * p + 1.0f;
  }
}

// Simple linear interpolation
float lerpf(float current, float target, float factor) {
  return current + (target - current) * factor;
}
