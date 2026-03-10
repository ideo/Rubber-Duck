#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// RUBBER DUCK ESP32 — Configuration
// ============================================================
// Seeed XIAO ESP32S3 Sense + TLC59711 12-channel PWM LED driver
// Receives the same serial protocol as the Teensy duck but
// expresses through LED brightness patterns instead of servo+audio.
//
// This is a SEPARATE duck. The Teensy firmware is untouched.

// --- Feature Toggles ---
#define ENABLE_LED_BAR     true   // 10-segment LED bar via TLC59711
#define ENABLE_SERVO       true   // LEDC PWM (ESP32Servo library hung, replaced with raw LEDC)
#define ENABLE_BUTTON      true   // Mode/demo button

// --- TLC59711 Config (SPI) ---
// The TLC59711 uses a simplified SPI: data + clock only (no CS/latch).
// On XIAO ESP32S3: any two GPIOs work (bit-banged by Adafruit library).
#define TLC_DATA_PIN       D3   // Use board macro — guaranteed to match the silk
#define TLC_CLOCK_PIN      D4   // Use board macro — guaranteed to match the silk
#define TLC_NUM_DRIVERS    1    // Number of daisy-chained TLC59711 boards
#define TLC_NUM_CHANNELS   12   // 12 channels per TLC59711

// --- LED Bar Config ---
// 10-segment bar graph driven by TLC59711 channels 0-9.
// Channels 10-11 are spare (accent, status, etc.)
#define LED_BAR_SEGMENTS   10
#define LED_BAR_FIRST_CH   0    // First TLC channel for bar segment 0
#define LED_ACCENT_CH_A    10   // Spare channel A
#define LED_ACCENT_CH_B    11   // Spare channel B

// Brightness scaling (TLC59711 is 16-bit: 0-65535)
#define LED_MAX_BRIGHTNESS 50000  // Global cap (reduce if too bright)
#define LED_MIN_BRIGHTNESS 0

// --- Servo Config (LEDC PWM) ---
#define SERVO_PIN          D0   // D0 on XIAO (D1 had no LEDC output)
#define SERVO_CENTER       90   // Neutral position (degrees)
#define SERVO_RANGE        80   // ±degrees from center
#define SERVO_MIN          (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX          (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS    20   // Fixed-rate update interval

// --- Button Config ---
#define BUTTON_PIN         D2   // D2 on XIAO (internal pullup)
#define LONG_PRESS_MS      2000 // Hold 2s for snap-to-center

// --- Serial Config ---
#define SERIAL_BAUD        9600

// --- Spring Physics (servo) ---
#define SPRING_K           0.06f
#define SPRING_DAMPING     0.82f
#define OSCILLATION_DECAY  0.95f

// --- Expression Timing ---
#define EXPRESSION_HOLD_MS       5000   // Hold pose before returning to center
#define EXPRESSION_RETURN_KICK   0.5f   // Velocity kick for return animation

// --- LED Animation ---
#define LED_LERP_SPEED     0.06f  // Per-frame interpolation (slower = smoother with 16-bit)
#define LED_FLASH_MS       180    // Brief all-on burst on new eval
#define LED_BREATHE_MIN    0.05f  // Idle breathe minimum (fraction of max)
#define LED_BREATHE_MAX    0.30f  // Idle breathe maximum
#define LED_BREATHE_PERIOD 4000   // Breathe cycle in ms

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
  int   fillCount;           // 0-10 segments to light
  float segmentBrightness;   // 0.0-1.0 for lit segments
  float accentBrightness;    // 0.0-1.0 for accent channels
  float pulseRate;           // Hz — 0 = no pulse overlay
  bool  flash;               // Trigger a brief all-on burst
};

// Servo target state (output of reducer)
struct ServoTarget {
  float angle;               // Target angle in degrees (offset from center)
  float oscillationAmp;      // Wiggle amplitude (from risk)
};

// ============================================================
// Extern declarations
// ============================================================

extern EvalScores latestScores;
extern bool       newEvalAvailable;

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

#endif
