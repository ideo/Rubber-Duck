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

  target.angle = approval * (float)SERVO_RANGE;
  target.oscillationAmp = max(0.0f, scores.risk) * 8.0f;

  return target;
}

// ============================================================
// Set target (called when eval arrives)
// ============================================================
void setServoTarget(ServoTarget &target) {
  servoTargetAngle = target.angle;
  servoOscillationAmp = target.oscillationAmp;
  servoOscillationPhase = 0;
  lastEvalTime = millis();

  float direction = (servoTargetAngle > servoCurrentAngle) ? 1.0f : -1.0f;
  servoVelocity += direction * 1.5f;
}

// ============================================================
// Fixed-rate update
// ============================================================
void updateServo() {
  unsigned long now = millis();
  bool chirpBusy = (chirpServoOffset != 0.0f);  // Chirp playing
  bool ttsPlaying = isAudioStreaming();

  // Expression decay: return to center after hold period
  if ((now - lastEvalTime) > EXPRESSION_HOLD_MS && fabs(servoTargetAngle) > 0.5f) {
    float direction = (0 > servoCurrentAngle) ? 1.0f : -1.0f;
    servoTargetAngle = 0;
    servoVelocity += direction * EXPRESSION_RETURN_KICK;
  }

  // Cluster micro-hops: tight follow-up positions (bird-like "choosing what to look at")
  if (idleClusterRemaining > 0 && now > nextClusterHop &&
      !permissionPending && !chirpBusy && !ttsPlaying) {
    float raw = ((float)random(-100, 101) / 100.0f) * IDLE_CLUSTER_DELTA;
    float delta = (raw >= 0) ? max(raw, IDLE_CLUSTER_MIN_DELTA) : min(raw, -IDLE_CLUSTER_MIN_DELTA);
    // Allow follow-ups to swing wider than initial hop range so the full delta is felt
    ambientTargetOffset = constrain(ambientTargetOffset + delta, -(IDLE_HOP_RANGE + IDLE_CLUSTER_DELTA), IDLE_HOP_RANGE + IDLE_CLUSTER_DELTA);
    ambientVelocity = 0;
    ambientSpringActive = false;
    idleClusterRemaining--;

    if (idleClusterRemaining > 0) {
      nextClusterHop = now + IDLE_CLUSTER_GAP_MIN + random(IDLE_CLUSTER_GAP_MAX - IDLE_CLUSTER_GAP_MIN);
    }
  }

  // Idle heartbeat: start a new hop cluster
  if (idleClusterRemaining == 0 && !permissionPending && !chirpBusy && !ttsPlaying &&
      (now - lastEvalTime) > EXPRESSION_HOLD_MS && now > nextIdleHop) {
    // Pick cluster size: 50% single, 40% double, 10% triple
    int roll = random(100);
    int clusterSize = (roll < 50) ? 1 : (roll < 90) ? 2 : 3;

    ambientTargetOffset = ((float)random(-100, 101) / 100.0f) * IDLE_HOP_RANGE;
    ambientVelocity = 0;
    ambientSpringActive = false;

    idleClusterRemaining = clusterSize - 1;
    if (idleClusterRemaining > 0) {
      nextClusterHop = now + IDLE_CLUSTER_GAP_MIN + random(IDLE_CLUSTER_GAP_MAX - IDLE_CLUSTER_GAP_MIN);
    }

    nextIdleHop = now + IDLE_HOP_MIN_MS + random(IDLE_HOP_MAX_MS - IDLE_HOP_MIN_MS);

  }

  // TTS talking head animation: retarget ambient while speaking
  if (ttsPlaying && (now - lastTTSRetarget) >= TTS_RETARGET_MS) {
    lastTTSRetarget = now;
    ambientTargetOffset = ((float)random(-100, 101) / 100.0f) * TTS_HOP_RANGE;
    ambientSpringActive = false;
  }

  // Spring physics: pull toward target (conscious layer)
  float diff = servoTargetAngle - servoCurrentAngle;
  servoVelocity += diff * SPRING_K;
  servoVelocity *= SPRING_DAMPING;

  // Risk oscillation overlay
  if (servoOscillationAmp > 0.1f) {
    servoOscillationPhase += 0.3f;
    servoVelocity += sin(servoOscillationPhase) * servoOscillationAmp * 0.05f;
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
    ambientCurrentOffset += (ambientTargetOffset - ambientCurrentOffset) * AMBIENT_LERP_RATE;
  }

  // Write to servo — layers: conscious + ambient + chirp servo kick
  int pos = (int)(SERVO_CENTER + servoCurrentAngle + ambientCurrentOffset + chirpServoOffset);
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
