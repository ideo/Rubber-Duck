// ============================================================
// Servo Duck — Reducer + Control
// ============================================================
// The servo duck is a beak on a rotating disc.
// Expression vocabulary:
//   - Position (angle): overall approval
//   - Movement dynamics: spring physics with overshoot
//   - Oscillation/wiggle: high risk triggers jitter
//   - Easing quality: elegance → smoother motion

// --- Servo State ---
float servoCurrentAngle = 0.0;
float servoTargetAngle  = 0.0;
float servoVelocity     = 0.0;

float servoOscillationAmp   = 0.0;
float servoOscillationPhase = 0.0;

// ============================================================
// REDUCER: scores → servo target
// ============================================================
ServoTarget servoReducer(EvalScores &scores) {
  ServoTarget target;

  // Weighted approval score
  float approval =
    scores.soundness  * 0.35 +
    scores.elegance   * 0.25 +
    scores.creativity * 0.20 +
    scores.ambition   * 0.10 -
    scores.risk       * 0.10;

  // Map approval (-1..1) → angle (±SERVO_RANGE from center)
  target.angle = approval * (float)SERVO_RANGE;

  // Risk drives oscillation amplitude
  target.oscillationAmp = max(0.0f, scores.risk) * 8.0f; // degrees

  // Elegance drives easing smoothness (not yet used, placeholder)
  target.easeStrength = (scores.elegance + 1.0f) / 2.0f; // 0..1

  return target;
}

// ============================================================
// Set new target (called when eval arrives)
// ============================================================
void setServoTarget(ServoTarget &target) {
  servoTargetAngle = target.angle;
  servoOscillationAmp = target.oscillationAmp;
  servoOscillationPhase = 0;

  // Give it a kick in the right direction
  float direction = (servoTargetAngle > servoCurrentAngle) ? 1.0 : -1.0;
  servoVelocity += direction * 1.5;
}

// ============================================================
// Fixed-rate update (called every SERVO_UPDATE_MS)
// ============================================================
void updateServo() {
  // Spring physics: pull toward target
  float diff = servoTargetAngle - servoCurrentAngle;
  servoVelocity += diff * SPRING_K;
  servoVelocity *= SPRING_DAMPING;

  // Risk oscillation overlay
  if (servoOscillationAmp > 0.1) {
    servoOscillationPhase += 0.3;
    servoVelocity += sin(servoOscillationPhase) * servoOscillationAmp * 0.05;
    servoOscillationAmp *= OSCILLATION_DECAY;
  }

  servoCurrentAngle += servoVelocity;

  // Convert to absolute servo position and clamp
  int pos = (int)(SERVO_CENTER + servoCurrentAngle);
  pos = constrain(pos, SERVO_MIN, SERVO_MAX);

  servo.write(pos);
}
