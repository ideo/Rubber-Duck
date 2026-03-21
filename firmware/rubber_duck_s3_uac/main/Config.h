#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// RUBBER DUCK S3 UAC — Configuration
// ============================================================
// Seeed XIAO ESP32S3 Sense + servo + built-in NeoPixel.
// TTS/mic go through USB Audio Class (UAC) — macOS sees the
// S3 as a CoreAudio device named "Duck Duck Duck".
//
// Serial protocol: text-only, newline-terminated (no binary framing).
// ============================================================

// --- XIAO ESP32S3 Pin Mapping ---
// Arduino IDE gets these from the board variant. In ESP-IDF we define them.
// XIAO ESP32S3 Sense silk → GPIO mapping:
#ifndef D0
#define D0   1
#define D1   2
#define D2   3
#define D3   4
#define D4   5
#define D5   6
#define D6   43
#define D7   44
#define D8   7
#define D9   8
#define D10  9
#endif

// --- Feature Toggles ---
#define ENABLE_STATUS_LED  true   // Built-in RGB NeoPixel (GPIO 48)
#define ENABLE_SERVO       true   // LEDC PWM servo
#define ENABLE_BUTTON      true   // Mode/demo button
#define ENABLE_UAC         true   // USB Audio Class (mic + speaker)
#define ENABLE_AUDIO       true   // I2S speaker output (MAX98357)

// --- I2S DAC Config (MAX98357) ---
#define I2S_BCLK_PIN       D2
#define I2S_WS_PIN         D3
#define I2S_DOUT_PIN       D4
#define AUDIO_I2S_PORT     I2S_NUM_0   // Try port 0
#define AUDIO_SAMPLE_RATE  16000
#define I2S_DMA_BUF_COUNT  4
#define I2S_DMA_BUF_LEN    64

// --- Status LED Config (built-in NeoPixel) ---
#define STATUS_LED_PIN     48     // XIAO ESP32S3 built-in RGB
#define STATUS_FLASH_MS    150
#define STATUS_BREATHE_MIN 0.03f
#define STATUS_BREATHE_MAX 0.25f
#define STATUS_BREATHE_PERIOD 4000

// --- Servo Config (LEDC PWM) ---
#define SERVO_PIN          D0
#define SERVO_CENTER       90
#define SERVO_RANGE        80
#define SERVO_MIN          (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX          (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS    20

// --- Button Config ---
#define BUTTON_PIN         D8      // D2 is I2S BCLK
#define LONG_PRESS_MS      2000

// --- Serial Config ---
#define SERIAL_BAUD        9600

// --- Spring Physics (servo) ---
#define SPRING_K           0.06f
#define SPRING_DAMPING     0.82f
#define OSCILLATION_DECAY  0.95f

// --- Expression Timing ---
#define EXPRESSION_HOLD_MS       5000
#define EXPRESSION_RETURN_KICK   0.5f

// --- Idle Heartbeat (servo) ---
#define IDLE_HOP_RANGE     30.0f
#define IDLE_HOP_MIN_MS    4000
#define IDLE_HOP_MAX_MS    15000
#define IDLE_HOP_KICK      0.6f

// --- Permission Nag Config ---
#define PERMISSION_NAG_BASE     6000
#define PERMISSION_NAG_JITTER   2000
#define PERMISSION_BACKOFF_AT   30000
#define PERMISSION_LAZY_BASE    15000
#define PERMISSION_LAZY_JITTER  15000
#define PERMISSION_RARE_AT      120000
#define PERMISSION_RARE_BASE    300000
#define PERMISSION_RARE_JITTER  300000

// ============================================================
// Data Structures
// ============================================================

struct EvalScores {
  float creativity;
  float soundness;
  float ambition;
  float elegance;
  float risk;
  char  source;      // 'U' = user, 'C' = claude
  bool  isValid;
};

// Servo target state (output of reducer)
struct ServoTarget {
  float angle;
  float oscillationAmp;
};

// ============================================================
// Extern declarations
// ============================================================

extern EvalScores latestScores;
extern bool       newEvalAvailable;

// Master volume (0.0–1.0) — set by widget via VOL,X.XX command.
extern float volumeScale;

// Servo state (ServoControl.cpp)
extern bool  calibrationMode;
extern float servoCurrentAngle;
extern float servoTargetAngle;
extern int   demoStep;

// Permission state (rubber_duck_s3_uac.cpp)
extern bool permissionPending;
void enterPermission();
void exitPermission();

// Servo functions (ServoControl.cpp)
void setupServo();
void startupServoAnimation();
void updateServo();
void setServoTarget(ServoTarget &target);
void servoWriteAngle(int angle);
void setServoAngleDirect(int angle);
void enterCalibration();
void advanceCalibration();
void exitCalibration();
void snapToCenter();
void triggerDemoPreset();
void resetAmbient();
ServoTarget servoReducer(EvalScores &scores);

// Status LED functions (StatusLED.cpp)
void setupStatusLED();
void startupLEDAnimation();
void setStatusColor(uint8_t r, uint8_t g, uint8_t b);
void setStatusFromEval(EvalScores &scores);
void startStatusBreathe();
void setPermissionStrobe(bool active);
void updateStatusLED();

// Serial functions (SerialProtocol.cpp)
void readSerial();
void parseMessage(char *msg);

// Easing functions (Easing.cpp)
float cubicEase(float t);
float quarticEase(float t);
float quinticEase(float t);
float lerpf(float current, float target, float factor);

// I2S Audio (AudioI2S.cpp)
void setupAudioI2S();
void audioI2SWrite(const int16_t *samples, size_t count);

// USB Audio (USBAudio.cpp)
void setupUSBAudio();

// Main functions (rubber_duck_s3_uac.cpp)
void printEval(EvalScores &scores);

#endif
