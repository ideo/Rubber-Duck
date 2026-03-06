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
//   P   → ping (responds with "PONG")

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

  // Test commands
  if (source == 'P') {
    Serial.println("PONG");
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
