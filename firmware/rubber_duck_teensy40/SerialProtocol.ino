// ============================================================
// Serial Protocol Parser
// ============================================================
// Expects newline-terminated messages:
//   U,0.20,0.70,0.00,0.60,-0.30    (user evaluation)
//   C,0.20,0.70,0.00,0.60,-0.30    (claude evaluation)
//   Order: creativity, soundness, ambition, elegance, risk
//
// Also accepts test commands:
//   T   → trigger test eval (positive)
//   X   → trigger test eval (negative)
//   D   → cycle demo emotion presets (same as button press)
//   P   → ping (responds with "PONG")
//   P,1 → enter permission pending (nag loop)
//   P,0 → permission resolved (stop nagging)
//
// Servo/calibration commands:
//   S,90   → set servo to absolute angle (10-170)
//   S,C    → snap to center
//   S,?    → report current servo angle
//   CAL    → enter calibration mode
//
// Audio commands (USB Audio bridge):
//   G,0.8  → set mic gain (0.0-10.0)
//   M,1    → mute mic (1=mute, 0=unmute)
//   V      → report audio level (responds with "L,0.45")

#define SERIAL_BUFFER_SIZE 128

char serialBuffer[SERIAL_BUFFER_SIZE];
int  serialBufferPos = 0;

void readSerial() {
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      if (serialBufferPos > 0) {
        serialBuffer[serialBufferPos] = '\0';
        parseMessage(serialBuffer);
        serialBufferPos = 0;
      }
    } else if (serialBufferPos < SERIAL_BUFFER_SIZE - 1) {
      serialBuffer[serialBufferPos++] = c;
    }
  }
}

void parseMessage(char *msg) {
  char source = msg[0];

  // Ping / Permission control
  if (source == 'P') {
    if (msg[1] == ',' && msg[2] == '1') {
      // P,1 → enter permission pending
      enterPermission();
    } else if (msg[1] == ',' && msg[2] == '0') {
      // P,0 → permission resolved
      exitPermission();
    } else {
      Serial.println("PONG");
    }
    return;
  }

  // Identity
  if (source == 'I') {
    Serial.println("DUCK,TEENSY40,1.0");
    return;
  }

  if (source == 'T') {
    // Positive test eval
    latestScores = {0.5, 0.8, 0.3, 0.7, -0.5, 'U', true};
    newEvalAvailable = true;
    Serial.println("[duck] Test eval: positive");
    return;
  }

  if (source == 'X') {
    // Negative test eval
    latestScores = {0.8, -0.9, 0.9, -0.8, 0.9, 'U', true};
    newEvalAvailable = true;
    Serial.println("[duck] Test eval: negative");
    return;
  }

  if (source == 'D') {
    // Cycle demo emotion presets (same as button press)
    triggerDemoPreset();
    return;
  }

  // --- Audio commands ---
  if (source == 'G' && msg[1] == ',') {
    // Set mic gain: G,2.5
    float gain = strtof(msg + 2, NULL);
    setMicGain(gain);
    return;
  }

  if (source == 'M' && msg[1] == ',') {
    // Mute/unmute: M,1 or M,0
    bool mute = (msg[2] == '1');
    setMicMute(mute);
    return;
  }

  if (source == 'V') {
    // Report audio level
    Serial.println("L," + String(getMicLevel(), 3));
    return;
  }

  // --- Servo/calibration commands ---
  if (source == 'S') {
    if (msg[1] == ',') {
      if (msg[2] == 'C' || msg[2] == 'c') {
        // S,C → snap to center
        snapToCenter();
      } else if (msg[2] == '?') {
        // S,? → report current angle
        int pos = (int)(SERVO_CENTER + servoCurrentAngle);
        Serial.println("[servo] Current: " + String(pos) + " deg (offset " +
                       String(servoCurrentAngle, 1) + " from " + String(SERVO_CENTER) + ")");
        Serial.println("[servo] Target:  " + String((int)(SERVO_CENTER + servoTargetAngle)) + " deg");
        Serial.println("[servo] Range:   " + String(SERVO_MIN) + " - " + String(SERVO_MAX));
        Serial.println("[servo] Cal mode: " + String(calibrationMode ? "ON" : "OFF"));
      } else {
        // S,90 → set to specific angle
        int angle = (int)strtof(msg + 2, NULL);
        setServoAngleDirect(angle);
      }
    }
    return;
  }

  // --- Wake word attention ---
  // W,1 = big head cock (listening), W,0 = return to rest
  if (source == 'W') {
    #if ENABLE_SERVO_DUCK
    if (msg[1] == ',' && msg[2] == '1') {
      setServoAngleDirect(SERVO_CENTER + 45);  // Big head cock — "I'm listening"
      Serial.println("[duck] Wake: perked up");
    } else {
      snapToCenter();                           // Back to rest
      Serial.println("[duck] Wake: resting");
    }
    #endif
    return;
  }

  // CAL → enter calibration mode from serial
  if (strncmp(msg, "CAL", 3) == 0) {
    enterCalibration();
    return;
  }

  // N → advance calibration step (next)
  if (source == 'N' && calibrationMode) {
    advanceCalibration();
    return;
  }

  // Full evaluation message: U,c,s,a,e,r or C,c,s,a,e,r
  if ((source != 'U' && source != 'C') || msg[1] != ',') {
    Serial.println("[duck] Unknown message: " + String(msg));
    return;
  }

  // Parse 5 comma-separated floats starting after "X,"
  float values[5];
  char *ptr = msg + 2; // skip "U," or "C,"

  for (int i = 0; i < 5; i++) {
    char *end;
    values[i] = strtof(ptr, &end);

    if (end == ptr) {
      Serial.println("[duck] Parse error at field " + String(i));
      return;
    }

    // Clamp to [-1, 1]
    values[i] = constrain(values[i], -1.0f, 1.0f);

    ptr = end;
    if (*ptr == ',') ptr++; // skip comma
  }

  latestScores.creativity = values[0];
  latestScores.soundness  = values[1];
  latestScores.ambition   = values[2];
  latestScores.elegance   = values[3];
  latestScores.risk       = values[4];
  latestScores.source     = source;
  latestScores.isValid    = true;
  newEvalAvailable = true;
}
