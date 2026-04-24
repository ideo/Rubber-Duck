// ============================================================
// Serial Protocol Parser (Ducky Custom PCB)
// ============================================================
// Two modes:
//
// TEXT MODE (default):
//   Same newline-terminated protocol as the Teensy/S3 ducks.
//   U,0.20,0.70,0.00,0.60,-0.30\n   eval scores
//   P,1\n / P,0\n                    permission
//   S,90\n                           servo command
//   A,16000,16,1\n                   -> enter audio mode
//   T / X / D / V                    test commands
//
// AUDIO MODE (between A,<rate>,<bits>,<ch>\n and A,0\n):
//   Binary framing with mode byte prefix:
//     0x01 [len_hi] [len_lo] [PCM bytes...]   audio frame
//     0x02 [len_hi] [len_lo] [text bytes...]   control message

#define SERIAL_BUFFER_SIZE 128
#define BINARY_HEADER_SIZE 3

// --- Text Mode State ---
static char textBuf[SERIAL_BUFFER_SIZE];
static int  textBufPos = 0;

// --- Audio Mode State ---
static bool    audioMode = false;
static unsigned long audioModeLastRx = 0;
#define AUDIO_MODE_TIMEOUT_MS 5000
static uint8_t binHeader[BINARY_HEADER_SIZE];
static int     binHeaderPos = 0;
static uint8_t frameBuf[FRAME_MAX_BYTES];
static uint16_t frameExpectedLen = 0;
static uint16_t frameReceivedLen = 0;
static uint8_t  frameType = 0;

// ============================================================
// Main entry point
// ============================================================

void readSerial() {
  if (audioMode) {
    readSerialBinary();

    if ((millis() - audioModeLastRx) > AUDIO_MODE_TIMEOUT_MS) {
      audioStreamEnd();
      micSetMuted(false);
      audioMode = false;
      binHeaderPos = 0;
      Serial.println("[serial] Audio mode timeout — auto-exit");
    }
  } else {
    readSerialText();
  }
}

// ============================================================
// Text Mode Parser
// ============================================================

void readSerialText() {
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      if (textBufPos > 0) {
        textBuf[textBufPos] = '\0';
        parseTextMessage(textBuf);
        textBufPos = 0;
      }
    } else if (textBufPos < SERIAL_BUFFER_SIZE - 1) {
      textBuf[textBufPos++] = c;
    }
  }
}

void parseTextMessage(char *msg) {
  lastSerialRx = millis();
  char source = msg[0];

  // --- Audio mode entry ---
  if (source == 'A') {
    if (msg[1] == ',' && msg[2] != '0') {
      uint32_t sr = 16000;
      uint8_t  bits = 16;
      uint8_t  ch = 1;

      char *ptr = msg + 2;
      char *end;
      sr = strtoul(ptr, &end, 10);
      if (*end == ',') { ptr = end + 1; bits = strtoul(ptr, &end, 10); }
      if (*end == ',') { ptr = end + 1; ch = strtoul(ptr, &end, 10); }

      audioStreamBegin(sr, bits, ch);
      micSetMuted(true);
      audioMode = true;
      audioModeLastRx = millis();
      binHeaderPos = 0;
      frameExpectedLen = 0;
      frameReceivedLen = 0;
    }
    return;
  }

  // --- Mic streaming control ---
  if (source == 'M') {
    if (msg[1] == ',' && msg[2] == '1') {
      micStreaming = true;
    } else if (msg[1] == ',' && msg[2] == '0') {
      micStreaming = false;
    }
    return;
  }

  // --- Volume control ---
  if (strncmp(msg, "VOL,", 4) == 0) {
    float vol = strtof(msg + 4, NULL);
    volumeScale = constrain(vol, 0.0f, 1.0f);
    float minDist = 999.0f;
    for (uint8_t i = 0; i < NUM_VOLUME_PRESETS; i++) {
      float d = fabs(vol - volumePresets[i]);
      if (d < minDist) { minDist = d; volumeStep = i; }
    }
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

  // --- Identity (handshake) ---
  if (source == 'I') {
    Serial.println("DUCK,ESP32S3,1.0,DUCKY_PCB");
    if (!widgetConnected) {
      widgetConnected = true;
      deferredConnected = true;
    }
    return;
  }

  // --- Reboot ---
  if (source == 'B') {
    Serial.println("[duck] Rebooting...");
    Serial.flush();
    delay(100);
    esp_restart();
    return;
  }

  // --- Test commands ---
  if (source == 'T') {
    if (msg[1] == 'W') {
      #if ENABLE_AUDIO
      EvalScores testScores = {0.9, 0.9, 0.8, 0.9, -0.3, 'C', true};
      ChirpTarget ct = chirpReducer(testScores);
      playChirp(ct);
      Serial.println("[duck] Test: whistle chirp");
      #endif
      return;
    }
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

  // --- Direct chirp tests ---
  if (source == 'Q') {
    #if ENABLE_AUDIO
    playPermissionChirp();
    Serial.println("[duck] Test: permission chirp");
    #endif
    return;
  }

  // --- Wake word attention ---
  if (source == 'W') {
    #if ENABLE_SERVO
    if (msg[1] == ',' && msg[2] == '1') {
      servoWriteAngle(SERVO_CENTER + 45);
      Serial.println("[duck] Wake: perked up");
    } else {
      snapToCenter();
      Serial.println("[duck] Wake: resting");
    }
    #endif
    return;
  }

  // --- Servo sweep test ---
  if (source == 'V') {
    #if ENABLE_SERVO
    Serial.println("[servo] Sweep test...");
    servoWriteAngle(SERVO_CENTER);
    delay(500);
    servoWriteAngle(SERVO_MIN);
    delay(600);
    servoWriteAngle(SERVO_MAX);
    delay(600);
    servoWriteAngle(SERVO_CENTER);
    Serial.println("[servo] Sweep done");
    #else
    Serial.println("[servo] Servo disabled");
    #endif
    return;
  }

  // --- Servo commands ---
  #if ENABLE_SERVO
  if (source == 'S') {
    if (msg[1] == ',') {
      if (msg[2] == 'C' || msg[2] == 'c') {
        snapToCenter();
      } else if (msg[2] == '?') {
        int pos = (int)(SERVO_CENTER + servoCurrentAngle);
        Serial.print("[servo] Current: ");
        Serial.print(pos);
        Serial.println(" deg");
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

  // --- Eval scores: U,c,s,a,e,r or C,c,s,a,e,r ---
  if ((source != 'U' && source != 'C') || msg[1] != ',') {
    Serial.print("[duck] Unknown: ");
    Serial.println(msg);
    return;
  }

  float values[5];
  char *ptr = msg + 2;

  for (int i = 0; i < 5; i++) {
    char *end;
    values[i] = strtof(ptr, &end);
    if (end == ptr) {
      Serial.print("[duck] Parse error at field ");
      Serial.println(i);
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

// ============================================================
// Binary (Audio) Mode Parser
// ============================================================

void readSerialBinary() {
  while (Serial.available() > 0) {

    if (binHeaderPos < BINARY_HEADER_SIZE) {
      uint8_t b = Serial.read();

      if (binHeaderPos == 0) {
        if (b != FRAME_MODE_AUDIO && b != FRAME_MODE_CONTROL) {
          continue;
        }
      }

      binHeader[binHeaderPos++] = b;

      if (binHeaderPos == BINARY_HEADER_SIZE) {
        frameType = binHeader[0];
        frameExpectedLen = ((uint16_t)binHeader[1] << 8) | binHeader[2];
        frameReceivedLen = 0;

        if (frameExpectedLen == 0 || frameExpectedLen > FRAME_MAX_BYTES) {
          if (frameExpectedLen > FRAME_MAX_BYTES) {
            Serial.print("[serial] Frame too large: ");
            Serial.println(frameExpectedLen);
          }
          binHeaderPos = 0;
          continue;
        }
      }
      continue;
    }

    uint16_t remaining = frameExpectedLen - frameReceivedLen;
    uint16_t avail = Serial.available();
    uint16_t toRead = min(remaining, avail);

    size_t got = Serial.readBytes(frameBuf + frameReceivedLen, toRead);
    frameReceivedLen += got;

    if (frameReceivedLen >= frameExpectedLen) {
      audioModeLastRx = millis();
      lastSerialRx = audioModeLastRx;

      if (frameType == FRAME_MODE_AUDIO) {
        audioStreamWrite(frameBuf, frameExpectedLen);
      }
      else if (frameType == FRAME_MODE_CONTROL) {
        if (frameExpectedLen < FRAME_MAX_BYTES) {
          frameBuf[frameExpectedLen] = '\0';
          if (frameExpectedLen > 0 && frameBuf[frameExpectedLen - 1] == '\n') {
            frameBuf[frameExpectedLen - 1] = '\0';
          }
          if (frameBuf[0] == 'A' && frameBuf[1] == ',' && frameBuf[2] == '0') {
            audioStreamEnd();
            micSetMuted(false);
            audioMode = false;
          } else {
            parseTextMessage((char *)frameBuf);
          }
        }
      }
      else {
        Serial.print("[serial] Unknown frame type: 0x");
        Serial.println(frameType, HEX);
      }

      binHeaderPos = 0;
      frameExpectedLen = 0;
      frameReceivedLen = 0;
    }
  }
}
