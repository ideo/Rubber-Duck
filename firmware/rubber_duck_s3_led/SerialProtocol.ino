// ============================================================
// Serial Protocol Parser (ESP32-S3 Duck)
// ============================================================
// Text-only serial protocol — no binary framing (TTS goes via UAC).
//
// Eval messages:
//   U,0.20,0.70,0.00,0.60,-0.30    (user evaluation)
//   C,0.20,0.70,0.00,0.60,-0.30    (claude evaluation)
//   Order: creativity, soundness, ambition, elegance, risk
//
// Control commands:
//   I       → identity response: DUCK,ESP32S3,1.0
//   VOL,0.80 → set master volume (0.0–1.0)
//   P       → ping (responds with "PONG")
//   P,1     → enter permission pending
//   P,0     → permission resolved
//   T       → test eval (positive)
//   X       → test eval (negative)
//   D       → cycle demo presets
//   V       → servo sweep test
//   S,90    → set servo to absolute angle
//   S,C     → snap to center
//   S,?     → report current servo angle
//   CAL     → enter calibration mode

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

  // --- Identity ---
  if (source == 'I') {
    Serial.println("DUCK,ESP32S3,1.0");
    return;
  }

  // --- Volume control ---
  // VOL,0.80 = set master volume (0.0–1.0)
  if (strncmp(msg, "VOL,", 4) == 0) {
    float vol = strtof(msg + 4, NULL);
    volumeScale = constrain(vol, 0.0f, 1.0f);
    Serial.print("[duck] Volume: ");
    Serial.println(volumeScale, 2);
    return;
  }

  // --- Ping / Permission ---
  if (source == 'P') {
    if (msg[1] == ',' && msg[2] == '1') {
      enterPermission();
    } else if (msg[1] == ',' && msg[2] == '0') {
      exitPermission();
    } else {
      Serial.println("PONG");
    }
    return;
  }

  if (source == 'T') {
    latestScores = {0.5, 0.8, 0.3, 0.7, -0.5, 'U', true};
    newEvalAvailable = true;
    Serial.println("[duck] Test eval: positive");
    return;
  }

  if (source == 'X') {
    latestScores = {0.8, -0.9, 0.9, -0.8, 0.9, 'U', true};
    newEvalAvailable = true;
    Serial.println("[duck] Test eval: negative");
    return;
  }

  if (source == 'D') {
    triggerDemoPreset();
    return;
  }

  // Raw servo sweep test
  if (source == 'V') {
    #if ENABLE_SERVO
    Serial.println("[servo] Sweep test...");
    servoWriteAngle(SERVO_CENTER);
    delay(500);
    servoWriteAngle(SERVO_MIN);
    Serial.println("[servo] → MIN (" + String(SERVO_MIN) + ")");
    delay(600);
    servoWriteAngle(SERVO_MAX);
    Serial.println("[servo] → MAX (" + String(SERVO_MAX) + ")");
    delay(600);
    servoWriteAngle(SERVO_CENTER);
    Serial.println("[servo] → CENTER (" + String(SERVO_CENTER) + ")");
    #else
    Serial.println("[servo] Servo disabled");
    #endif
    return;
  }

  // Servo commands
  #if ENABLE_SERVO
  if (source == 'S') {
    if (msg[1] == ',') {
      if (msg[2] == 'C' || msg[2] == 'c') {
        snapToCenter();
      } else if (msg[2] == '?') {
        int pos = (int)(SERVO_CENTER + servoCurrentAngle);
        Serial.println("[servo] Current: " + String(pos) + " deg");
        Serial.println("[servo] Target:  " + String((int)(SERVO_CENTER + servoTargetAngle)) + " deg");
      } else {
        int angle = (int)strtof(msg + 2, NULL);
        setServoAngleDirect(angle);
      }
    }
    return;
  }

  if (strncmp(msg, "CAL", 3) == 0) {
    enterCalibration();
    return;
  }

  if (source == 'N' && calibrationMode) {
    advanceCalibration();
    return;
  }
  #endif

  // Full evaluation message: U,c,s,a,e,r or C,c,s,a,e,r
  if ((source != 'U' && source != 'C') || msg[1] != ',') {
    Serial.println("[duck] Unknown: " + String(msg));
    return;
  }

  float values[5];
  char *ptr = msg + 2;

  for (int i = 0; i < 5; i++) {
    char *end;
    values[i] = strtof(ptr, &end);

    if (end == ptr) {
      Serial.println("[duck] Parse error at field " + String(i));
      return;
    }

    values[i] = constrain(values[i], -1.0f, 1.0f);

    ptr = end;
    if (*ptr == ',') ptr++;
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
