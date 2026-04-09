// ============================================================
// Servo Control (ESP32-C3 Duck)
// ============================================================
// Same spring physics and idle heartbeat as the S3/Teensy ducks.
// Uses raw LEDC PWM (no library needed).
//
// LEDC: 50Hz, 14-bit resolution. 500µs = 0°, 2400µs = 180°.

#if ENABLE_SERVO

// LEDC config for servo PWM
#define SERVO_LEDC_FREQ     50
#define SERVO_LEDC_BITS     14
#define SERVO_PULSE_MIN     410     // 500µs  = 0°
#define SERVO_PULSE_MAX     1966    // 2400µs = 180°

void servoWriteAngle(int angle) {
  angle = constrain(angle, 0, 180);
  uint32_t duty = SERVO_PULSE_MIN + (uint32_t)((SERVO_PULSE_MAX - SERVO_PULSE_MIN) * angle) / 180;
  ledcWrite(SERVO_PIN, duty);
}

// --- Servo State ---
float servoCurrentAngle = 0.0;
float servoTargetAngle  = 0.0;
float servoVelocity     = 0.0;

float servoOscillationAmp   = 0.0;
float servoOscillationPhase = 0.0;

// --- Crab Typing ---
// Full L/R snap from center. Amplitude = how far each side. Speed = ms per side.
float crabTypeAmp     = 0.0f;    // Degrees each direction from center
unsigned long crabTypeInterval = 300;  // ms per side (L or R)
bool  crabTypeLeft    = true;    // Current side
unsigned long crabTypeLastFlip = 0;
bool  crabTyping      = false;   // Active?
unsigned long lastRealActivity = 0;  // Last eval/TTS — for idle escalation

unsigned long lastEvalTime = 0;

// --- Idle Heartbeat ---
unsigned long nextIdleHop = 0;
int   idleClusterRemaining = 0;      // Micro-hops left in current cluster
unsigned long nextClusterHop = 0;    // When to fire next micro-hop

// --- Ambient (subconscious) Layer ---
float ambientCurrentOffset = 0.0;
float ambientTargetOffset  = 0.0;
float ambientVelocity      = 0.0;
bool  ambientSpringActive  = false;  // true = spring (nags), false = lerp (idle)

// --- TTS Talking Animation ---
unsigned long lastTTSRetarget = 0;

// --- Calibration ---
bool  calibrationMode = false;
int   calibrationStep = 0;
const int calibrationAngles[] = { SERVO_CENTER, SERVO_MIN, SERVO_MAX, SERVO_CENTER };
const char* calibrationLabels[] = { "CENTER", "MIN", "MAX", "CENTER" };
#define CALIBRATION_STEPS 4

// ============================================================
// REDUCER: scores → servo target
// ============================================================
ServoTarget servoReducer(EvalScores &scores) {
  ServoTarget target;

  float approval =
    scores.soundness  * 0.35f +
    scores.elegance   * 0.25f +
    scores.creativity * 0.20f +
    scores.ambition   * 0.10f -
    scores.risk       * 0.10f;

  // Crab mode: approval maps to typing character.
  // Positive = lighter/faster, negative = heavier/slower, neutral = small/fast.
  float intensity = fabs(approval);

  if (approval > 0.7f) {
    // Very positive (impressed): big swings, moderate speed
    target.angle = 33.0f;
    target.oscillationAmp = 250.0f;
  } else if (approval > 0.3f) {
    // Positive (excited): large, fast
    target.angle = 30.0f;
    target.oscillationAmp = 150.0f;
  } else if (approval > -0.3f) {
    // Neutral (skeptical/bored/nervous): medium
    target.angle = 16.0f;
    target.oscillationAmp = (fabs(approval) < 0.1f) ? 250.0f : 150.0f;  // Near-zero = bored/slow
  } else if (approval > -0.6f) {
    // Negative: medium-large, moderate
    target.angle = 20.0f;
    target.oscillationAmp = 180.0f;
  } else {
    // Very negative (disgusted): huge, slow
    target.angle = 50.0f;
    target.oscillationAmp = 250.0f;
  }

  return target;
}

// ============================================================
// Set target (called when eval arrives)
// ============================================================
void setServoTarget(ServoTarget &target) {
  crabTypeAmp = target.angle;
  crabTypeInterval = (unsigned long)target.oscillationAmp;
  crabTyping = true;
  crabTypeLastFlip = millis();
  lastEvalTime = millis();
  lastRealActivity = millis();
}

// ============================================================
// Fixed-rate update
// ============================================================
void updateServo() {
  unsigned long now = millis();
  bool ttsPlaying = isAudioStreaming();

  // TTS talking: start typing if not already
  if (ttsPlaying && !crabTyping) {
    crabTypeAmp = 8.0f;
    crabTypeInterval = 250;
    crabTyping = true;
    crabTypeLastFlip = now;
    lastRealActivity = now;
  }

  // Stop typing when expression expires and nothing is playing
  if (!ttsPlaying && crabTyping && (now - lastEvalTime) > EXPRESSION_HOLD_MS) {
    crabTyping = false;
    if (nextIdleHop < now + 3000) {
      nextIdleHop = now + 3000;  // Breathing room after eval typing, but don't shorten idle gap
    }
  }

  // Idle fidget: occasional typing bursts
  if (!crabTyping && !ttsPlaying && !permissionPending &&
      (now - lastEvalTime) > EXPRESSION_HOLD_MS && now > nextIdleHop) {
    crabTypeAmp = 8.0f;
    crabTypeInterval = (random(2) == 0) ? 150 : 300;  // Coin flip: fast or slow burst
    crabTyping = true;
    crabTypeLastFlip = now;
    lastEvalTime = now - EXPRESSION_HOLD_MS + 2000;  // 2s of typing

    // Escalating gaps based on time since last real activity
    unsigned long idleTime = now - lastRealActivity;
    unsigned long gap;
    if (idleTime > 3600000) {       // >1 hr → stop completely
      crabTyping = false;
      nextIdleHop = 0xFFFFFFFF;     // Never
    } else if (idleTime > 900000) { // >15 min → 15 min gaps
      gap = 900000;
      nextIdleHop = now + gap;
    } else if (idleTime > 120000) { // >2 min → 5 min gaps
      gap = 300000;
      nextIdleHop = now + gap;
    } else {                        // First 2 min → 25-75s gaps
      gap = (IDLE_HOP_MIN_MS + random(IDLE_HOP_MAX_MS - IDLE_HOP_MIN_MS)) * 5;
      nextIdleHop = now + gap;
    }
  }

  // L/R flip on interval
  if (crabTyping && (now - crabTypeLastFlip) >= crabTypeInterval) {
    crabTypeLeft = !crabTypeLeft;
    crabTypeLastFlip = now;
  }

  // Set servo position: full snap L or R
  if (crabTyping) {
    servoCurrentAngle = crabTypeLeft ? -crabTypeAmp : crabTypeAmp;
  }
  // When not typing, stay wherever the last flip left us (arm down)

  // Write to servo
  int pos = (int)(SERVO_CENTER + servoCurrentAngle + chirpServoOffset);
  pos = constrain(pos, SERVO_MIN, SERVO_MAX);
  servoWriteAngle(pos);
}

// ============================================================
// Setup
// ============================================================
void setupServo() {
  // Use high LEDC channel (7) to avoid conflict with I2S internal timers
  ledcAttachChannel(SERVO_PIN, SERVO_LEDC_FREQ, SERVO_LEDC_BITS, 7);
  servoWriteAngle(SERVO_CENTER);
  Serial.print("[servo] LEDC PWM ch7 on pin D3 (GPIO");
  Serial.print((int)SERVO_PIN);
  Serial.println(")");
}

// ============================================================
// Startup wiggle
// ============================================================
void startupServoAnimation() {
  servoWriteAngle(SERVO_CENTER - 30);
  delay(300);
  servoWriteAngle(SERVO_CENTER + 30);
  delay(300);
  servoWriteAngle(SERVO_CENTER);
  delay(200);
}

// ============================================================
// Calibration
// ============================================================
void enterCalibration() {
  calibrationMode = true;
  calibrationStep = 0;
  servoVelocity = 0;
  servoOscillationAmp = 0;
  servoWriteAngle(calibrationAngles[0]);
  servoCurrentAngle = calibrationAngles[0] - SERVO_CENTER;
  servoTargetAngle = servoCurrentAngle;
  Serial.println("[cal] === CALIBRATION MODE ===");
  Serial.print("[cal] Step 0: ");
  Serial.println(calibrationLabels[0]);
}

void advanceCalibration() {
  calibrationStep++;
  if (calibrationStep >= CALIBRATION_STEPS) {
    exitCalibration();
    return;
  }
  int angle = calibrationAngles[calibrationStep];
  servoWriteAngle(angle);
  servoCurrentAngle = angle - SERVO_CENTER;
  servoTargetAngle = servoCurrentAngle;
  servoVelocity = 0;
  Serial.print("[cal] Step ");
  Serial.print(calibrationStep);
  Serial.print(": ");
  Serial.println(calibrationLabels[calibrationStep]);
}

void exitCalibration() {
  calibrationMode = false;
  calibrationStep = 0;
  servoWriteAngle(SERVO_CENTER);
  servoCurrentAngle = 0;
  servoTargetAngle = 0;
  servoVelocity = 0;
  Serial.println("[cal] === EXITED CALIBRATION ===");
}

void setServoAngleDirect(int angle) {
  angle = constrain(angle, SERVO_MIN, SERVO_MAX);
  servoWriteAngle(angle);
  servoCurrentAngle = angle - SERVO_CENTER;
  servoTargetAngle = servoCurrentAngle;
  servoVelocity = 0;
  Serial.print("[servo] Direct: ");
  Serial.print(angle);
  Serial.println(" deg");
}

void snapToCenter() {
  servoWriteAngle(SERVO_CENTER);
  servoCurrentAngle = 0;
  servoTargetAngle = 0;
  servoVelocity = 0;
  servoOscillationAmp = 0;
  crabTypeAmp = 0;
  crabTyping = false;
  ambientCurrentOffset = 0;
  ambientTargetOffset = 0;
  ambientVelocity = 0;
  ambientSpringActive = false;
  demoStep = 0;

  if (calibrationMode) {
    calibrationMode = false;
    calibrationStep = 0;
    Serial.println("[cal] Snapped to CENTER, exited calibration");
  } else {
    Serial.println("[servo] Snapped to CENTER");
  }
}

void resetAmbient() {
  ambientCurrentOffset = 0;
  ambientTargetOffset = 0;
  ambientVelocity = 0;
  ambientSpringActive = false;
}

#else

// Stubs when servo is disabled
float servoCurrentAngle = 0;
float servoTargetAngle = 0;
float servoVelocity = 0;
float servoOscillationAmp = 0;
float servoOscillationPhase = 0;
float ambientCurrentOffset = 0;
float ambientTargetOffset = 0;
float ambientVelocity = 0;
bool  ambientSpringActive = false;
bool  calibrationMode = false;
unsigned long lastEvalTime = 0;

void setupServo() {}
void startupServoAnimation() {}
void updateServo() {}
void setServoTarget(ServoTarget &target) {}
void servoWriteAngle(int angle) {}
void enterCalibration() {}
void advanceCalibration() {}
void exitCalibration() {}
void setServoAngleDirect(int angle) {}
void snapToCenter() {}
void resetAmbient() {}

#endif // ENABLE_SERVO

// ============================================================
// Demo Presets (shared — used with or without servo)
// ============================================================

const EvalScores demoPresets[] = {
  {  0.70,  0.95,  0.50,  0.90, -0.30, 'U', true },  // Impressed
  {  0.95,  0.50,  0.90,  0.60,  0.20, 'U', true },  // Excited
  {  0.10, -0.30,  0.20, -0.10,  0.50, 'U', true },  // Skeptical
  {  0.30,  0.20,  0.60,  0.10,  0.90, 'U', true },  // Nervous
  { -0.60, -0.95,  0.20, -0.80,  0.85, 'U', true },  // Disgusted
  { -0.20,  0.10, -0.80,  0.00, -0.10, 'U', true },  // Bored
};
const char* demoLabels[] = {
  "IMPRESSED", "EXCITED", "SKEPTICAL", "NERVOUS", "DISGUSTED", "BORED"
};
#define NUM_DEMO_PRESETS 6
int demoStep = 0;

// --- Dead Level State ---
// Startup chirp → servo at exact 0° for 10s → resume idle hops
bool  deadLevelActive = false;
unsigned long deadLevelStart = 0;
#define DEAD_LEVEL_DURATION_MS 10000

void triggerDemoPreset() {
  // First press after a dead level cycle (or anytime): cycle demos
  // But if dead level is active, pressing button exits it early
  if (deadLevelActive) {
    deadLevelActive = false;
    Serial.println("[demo] Dead level cancelled — playing first preset");
    // Fall through to play the preset
  }

  // Every NUM_DEMO_PRESETS+1 press = dead level (after cycling all demos)
  if (demoStep >= NUM_DEMO_PRESETS) {
    // Dead level: startup chirp → hold at center for 10s
    Serial.println("[demo] DEAD LEVEL — chirp + hold 10s");
    #if ENABLE_AUDIO
      playStartupChirp();
    #endif
    #if ENABLE_SERVO
      snapToCenter();
    #endif
    deadLevelActive = true;
    deadLevelStart = millis();
    demoStep = 0;  // Reset so next press cycles demos again
    return;
  }

  latestScores = demoPresets[demoStep];
  newEvalAvailable = true;
  Serial.print("[demo] ");
  Serial.println(demoLabels[demoStep]);
  demoStep = (demoStep + 1);
}

/// Call from loop() — holds servo at dead center during dead level period.
void updateDeadLevel() {
  if (!deadLevelActive) return;
  if ((millis() - deadLevelStart) >= DEAD_LEVEL_DURATION_MS) {
    deadLevelActive = false;
    Serial.println("[demo] Dead level ended — resuming idle");
    return;
  }
  // Force servo to exact center — override any ambient/spring physics
  #if ENABLE_SERVO
  servoTargetAngle = 0;
  servoCurrentAngle = 0;
  servoVelocity = 0;
  ambientCurrentOffset = 0;
  ambientTargetOffset = 0;
  ambientVelocity = 0;
  #endif
}
