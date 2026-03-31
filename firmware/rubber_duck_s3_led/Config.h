#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// RUBBER DUCK S3 — Configuration
// ============================================================
// Seeed XIAO ESP32S3 Sense + TLC59711 12-channel LED driver
// + servo. TTS/mic go through USB Audio Class (UAC) — macOS
// sees the S3 as a CoreAudio device named "Duck Duck Duck".
//
// Serial protocol: text-only, newline-terminated (no binary framing).
// ============================================================

// --- Feature Toggles ---
#define ENABLE_LED_BAR     true   // 10-segment LED bar via TLC59711
#define ENABLE_SERVO       true   // LEDC PWM servo
#define ENABLE_BUTTON      true   // Mode/demo button

// --- TLC59711 Config (SPI) ---
#define TLC_DATA_PIN       D3
#define TLC_CLOCK_PIN      D4
#define TLC_NUM_DRIVERS    1
#define TLC_NUM_CHANNELS   12

// --- LED Bar Config ---
#define LED_BAR_SEGMENTS   10
#define LED_BAR_FIRST_CH   0
#define LED_ACCENT_CH_A    10
#define LED_ACCENT_CH_B    11
#define LED_MAX_BRIGHTNESS 50000
#define LED_MIN_BRIGHTNESS 0

// --- Servo Config (LEDC PWM) ---
#define SERVO_PIN          D0
#define SERVO_CENTER       90
#define SERVO_RANGE        80
#define SERVO_MIN          (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX          (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS    20

// --- Button Config ---
#define BUTTON_PIN         D2
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

// --- LED Animation ---
#define LED_LERP_SPEED     0.06f
#define LED_FLASH_MS       180
#define LED_BREATHE_MIN    0.05f
#define LED_BREATHE_MAX    0.30f
#define LED_BREATHE_PERIOD 4000

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
// Data Structures (shared with Teensy protocol)
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

// LED bar target state (output of reducer)
struct LEDBarTarget {
  int   fillCount;
  float segmentBrightness;
  float accentBrightness;
  float pulseRate;
  bool  flash;
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

// Servo state (ServoControl.ino)
extern bool  calibrationMode;
extern float servoCurrentAngle;
extern float servoTargetAngle;
extern int   demoStep;

// Permission state (rubber_duck_esp32.ino)
extern bool permissionPending;
void enterPermission();
void exitPermission();

// Servo helpers (ServoControl.ino)
void snapToCenter();
void triggerDemoPreset();
void resetAmbient();
void updateDeadLevel();
extern bool deadLevelActive;

#endif
