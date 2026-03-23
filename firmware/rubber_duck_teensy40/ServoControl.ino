// ============================================================
// Servo Duck — Reducer + Control + Calibration
// ============================================================
// The servo duck is a beak on a rotating disc.
// Expression vocabulary:
//   - Position (angle): overall approval
//   - Movement dynamics: spring physics with overshoot
//   - Oscillation/wiggle: high risk triggers jitter
//   - Easing quality: elegance → smoother motion
//
// Calibration mode (button on pin 2):
//   Short press cycles: CENTER → MIN → MAX → CENTER → exit
//   Long press (2s): instant snap to CENTER from anywhere
//   Serial "S,90": set arbitrary angle (10-170)

// --- Servo State ---
float servoCurrentAngle = 0.0;
float servoTargetAngle  = 0.0;
float servoVelocity     = 0.0;

float servoOscillationAmp   = 0.0;
float servoOscillationPhase = 0.0;

unsigned long lastEvalTime = 0;  // For expression decay back to rest

// --- Idle Heartbeat State ---
unsigned long nextIdleHop = 0;       // When to pick a new idle target
int   idleClusterRemaining = 0;      // Micro-hops left in current cluster
unsigned long nextClusterHop = 0;    // When to fire next micro-hop

// --- Ambient (subconscious) Layer ---
// Additive offset on top of conscious position. Owns idle drift,
// permission nag positions, and (future) speaking wobble.
float ambientCurrentOffset = 0.0;
float ambientTargetOffset  = 0.0;
float ambientVelocity      = 0.0;
bool  ambientSpringActive  = false;  // true = spring chases target (nags), false = direct position

// --- Calibration State ---
bool  calibrationMode = false;
int   calibrationStep = 0;  // 0=center, 1=min, 2=max, 3=center (then exit)
const int calibrationAngles[] = { SERVO_CENTER, SERVO_MIN, SERVO_MAX, SERVO_CENTER };
const char* calibrationLabels[] = { "CENTER (90)", "MIN (10)", "MAX (170)", "CENTER (90)" };
#define CALIBRATION_STEPS 4

// --- Demo Emotion Presets ---
// Each fires through the existing eval pipeline (servo + chirp reducers)
//                                     cre   snd   amb   elg   risk
const EvalScores demoPresets[] = {
  {  0.70,  0.95,  0.50,  0.90, -0.30, 'U', true },  // 0: Impressed
  {  0.95,  0.50,  0.90,  0.60,  0.20, 'U', true },  // 1: Excited
  {  0.10, -0.30,  0.20, -0.10,  0.50, 'U', true },  // 2: Skeptical
  {  0.30,  0.20,  0.60,  0.10,  0.90, 'U', true },  // 3: Nervous
  { -0.60, -0.95,  0.20, -0.80,  0.85, 'U', true },  // 4: Disgusted
  { -0.20,  0.10, -0.80,  0.00, -0.10, 'U', true },  // 5: Bored
};
const char* demoLabels[] = {
  "IMPRESSED", "EXCITED", "SKEPTICAL", "NERVOUS", "DISGUSTED", "BORED"
};
#define NUM_DEMO_PRESETS 6
int demoStep = 0;

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
  lastEvalTime = millis();  // Reset decay timer

  // Give it a kick in the right direction
  float direction = (servoTargetAngle > servoCurrentAngle) ? 1.0 : -1.0;
  servoVelocity += direction * 1.5;
}

// ============================================================
// Fixed-rate update (called every SERVO_UPDATE_MS)
// ============================================================
void updateServo() {
  unsigned long now = millis();

  // Return to rest: after hold period, spring back to center (gentler kick)
  if ((now - lastEvalTime) > EXPRESSION_HOLD_MS && abs(servoTargetAngle) > 0.5) {
    float direction = (0 > servoCurrentAngle) ? 1.0 : -1.0;
    servoTargetAngle = 0;
    servoVelocity += direction * EXPRESSION_RETURN_KICK;
  }

  // Cluster micro-hops: tight follow-up positions (bird-like "choosing what to look at")
  if (idleClusterRemaining > 0 && now > nextClusterHop &&
      !permissionPending && !i2sChirpActive && !ttsActive) {
    float raw = ((float)random(-100, 101) / 100.0f) * IDLE_CLUSTER_DELTA;
    float delta = (raw >= 0) ? max(raw, IDLE_CLUSTER_MIN_DELTA) : min(raw, -IDLE_CLUSTER_MIN_DELTA);
    ambientTargetOffset = constrain(ambientTargetOffset + delta, -IDLE_HOP_RANGE, IDLE_HOP_RANGE);
    ambientVelocity = 0;
    ambientSpringActive = false;
    idleClusterRemaining--;
    if (idleClusterRemaining > 0) {
      nextClusterHop = now + IDLE_CLUSTER_GAP_MIN + random(IDLE_CLUSTER_GAP_MAX - IDLE_CLUSTER_GAP_MIN);
    }
  }

  // Idle heartbeat: start a new hop cluster
  if (idleClusterRemaining == 0 && !permissionPending && !i2sChirpActive && !ttsActive &&
      (now - lastEvalTime) > EXPRESSION_HOLD_MS && now > nextIdleHop) {
    // Pick cluster size: 50% single, 40% double, 10% triple
    int roll = random(100);
    int clusterSize = (roll < 50) ? 1 : (roll < 90) ? 2 : 3;

    // First position
    ambientTargetOffset = ((float)random(-100, 101) / 100.0f) * IDLE_HOP_RANGE;
    ambientVelocity = 0;
    ambientSpringActive = false;

    // Schedule remaining cluster micro-hops
    idleClusterRemaining = clusterSize - 1;
    if (idleClusterRemaining > 0) {
      nextClusterHop = now + IDLE_CLUSTER_GAP_MIN + random(IDLE_CLUSTER_GAP_MAX - IDLE_CLUSTER_GAP_MIN);
    }

    nextIdleHop = now + IDLE_HOP_MIN_MS + random(IDLE_HOP_MAX_MS - IDLE_HOP_MIN_MS);
  }

  // Spring physics: pull toward target (conscious layer)
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

  // Ambient layer: spring (nag kicks) or simple ease (idle hops)
  if (ambientSpringActive) {
    float ambientDiff = ambientTargetOffset - ambientCurrentOffset;
    ambientVelocity += ambientDiff * AMBIENT_SPRING_K;
    ambientVelocity *= AMBIENT_SPRING_DAMPING;
    ambientCurrentOffset += ambientVelocity;
  } else {
    // Exponential ease-out: fast start, gentle arrival
    ambientCurrentOffset += (ambientTargetOffset - ambientCurrentOffset) * AMBIENT_LERP_RATE;
  }

  // Convert to absolute servo position and clamp
  // Layers: conscious + ambient + chirp servo kick
  int pos = (int)(SERVO_CENTER + servoCurrentAngle + ambientCurrentOffset + chirpServoOffset);
  pos = constrain(pos, SERVO_MIN, SERVO_MAX);

  servo.write(pos);
}

// ============================================================
// CALIBRATION MODE
// ============================================================
// Bypasses spring physics — writes angles directly to servo.
// Used during assembly to verify face orientation.

void enterCalibration() {
  calibrationMode = true;
  calibrationStep = 0;
  servoVelocity = 0;
  servoOscillationAmp = 0;

  servo.write(calibrationAngles[0]);
  servoCurrentAngle = calibrationAngles[0] - SERVO_CENTER;
  servoTargetAngle = servoCurrentAngle;

  Serial.println("[cal] === CALIBRATION MODE ===");
  Serial.println("[cal] Step 0: " + String(calibrationLabels[0]) + " -> " + String(calibrationAngles[0]) + " deg");
  Serial.println("[cal] Press button to advance, or send S,<angle>");
}

void advanceCalibration() {
  calibrationStep++;

  if (calibrationStep >= CALIBRATION_STEPS) {
    exitCalibration();
    return;
  }

  int angle = calibrationAngles[calibrationStep];
  servo.write(angle);
  servoCurrentAngle = angle - SERVO_CENTER;
  servoTargetAngle = servoCurrentAngle;
  servoVelocity = 0;

  Serial.println("[cal] Step " + String(calibrationStep) + ": " +
                 String(calibrationLabels[calibrationStep]) + " -> " +
                 String(angle) + " deg");

  if (calibrationStep == CALIBRATION_STEPS - 1) {
    Serial.println("[cal] (next press exits calibration)");
  }
}

void exitCalibration() {
  calibrationMode = false;
  calibrationStep = 0;
  servoVelocity = 0;
  servoOscillationAmp = 0;

  // Settle at center
  servo.write(SERVO_CENTER);
  servoCurrentAngle = 0;
  servoTargetAngle = 0;

  Serial.println("[cal] === EXITED CALIBRATION — back to normal ===");
}

void setServoAngleDirect(int angle) {
  angle = constrain(angle, SERVO_MIN, SERVO_MAX);
  servo.write(angle);
  servoCurrentAngle = angle - SERVO_CENTER;
  servoTargetAngle = servoCurrentAngle;
  servoVelocity = 0;
  servoOscillationAmp = 0;

  Serial.println("[servo] Direct set: " + String(angle) + " deg (offset " +
                 String(servoCurrentAngle, 1) + " from center)");
}

// ============================================================
// AMBIENT LAYER — kick to a random position
// ============================================================
// Called by idle hops, permission nags, and (future) speaking wobble.

void kickAmbient(float range, float kick) {
  ambientTargetOffset = ((float)random(-100, 101) / 100.0f) * range;
  float direction = (ambientTargetOffset > ambientCurrentOffset) ? 1.0f : -1.0f;
  ambientVelocity += direction * kick;
}

void resetAmbient() {
  ambientCurrentOffset = 0;
  ambientTargetOffset = 0;
  ambientVelocity = 0;
}

void snapToCenter() {
  servo.write(SERVO_CENTER);
  servoCurrentAngle = 0;
  servoTargetAngle = 0;
  servoVelocity = 0;
  servoOscillationAmp = 0;
  resetAmbient();
  demoStep = 0;  // Reset demo cycle

  if (calibrationMode) {
    calibrationMode = false;
    calibrationStep = 0;
    Serial.println("[cal] Long press — snapped to CENTER, exited calibration");
  } else {
    Serial.println("[servo] Snapped to CENTER (" + String(SERVO_CENTER) + " deg)");
  }
}

// ============================================================
// DEMO PRESETS — cycle through canned emotions
// ============================================================
// Fires preset scores through the normal eval pipeline.
// Button short-press or serial 'D' command.

void triggerDemoPreset() {
  latestScores = demoPresets[demoStep];
  newEvalAvailable = true;

  Serial.println("[demo] Preset " + String(demoStep) + ": " + String(demoLabels[demoStep]));
  printEval(latestScores);

  demoStep = (demoStep + 1) % NUM_DEMO_PRESETS;
}
