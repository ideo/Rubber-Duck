#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// RUBBER DUCK — Configuration
// ============================================================
// One Teensy can drive both ducks simultaneously.
// Toggle each on/off depending on what's wired up.

#define ENABLE_SERVO_DUCK  true
#define ENABLE_LED_DUCK    false  // No matching LED hardware yet
#define ENABLE_I2S_AUDIO   true   // MAX98357 I2S DAC on default pins (BCLK=21, LRCLK=20, DIN=7)
#define ENABLE_USB_AUDIO   true   // Teensy appears as USB mic — requires USB Type: "Serial + MIDI + Audio"

// --- Pin Assignments (matching metro_0.1 layout) ---
#define SERVO_PIN        3    // PWM servo output
#define LED_PIN          6    // NeoPixel data line
#define PIEZO_PIN        9    // Piezo speaker
#define MIC_PIN          A0   // Electret mic analog input

// --- Servo Config ---
#define SERVO_CENTER     90   // Neutral position (degrees)
#define SERVO_RANGE      80   // ±80 degrees from center
#define SERVO_MIN        (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX        (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS  20   // Fixed-rate servo update interval

// --- LED Bar Config ---
#define NUM_LEDS         10   // 10-segment LED bar graph
#define LED_BRIGHTNESS   80   // Global brightness (0-255)

// --- Serial Config ---
#define SERIAL_BAUD      9600

// --- Spring Physics (servo) ---
#define SPRING_K         0.06f
#define SPRING_DAMPING   0.82f
#define OSCILLATION_DECAY 0.95f

// --- LED Animation ---
#define LED_LERP_SPEED   0.08f
#define LED_FLASH_MS     200

// --- Chirp Config ---
#define CHIRP_BASE_FREQ  400
#define CHIRP_DURATION   250   // ms
#define CHIRP_AMPLITUDE  0.6f  // 0.0-1.0 volume for I2S output

// --- USB Audio Config ---
#define MIC_DEFAULT_GAIN 2.0f  // Pre-amp gain for mic signal

// ============================================================
// Data Structures
// ============================================================

// Raw evaluation scores from Claude API
struct EvalScores {
  float creativity;
  float soundness;
  float ambition;
  float elegance;
  float risk;
  char  source;      // 'U' = user, 'C' = claude
  bool  isValid;
};

// Servo duck target state (output of reducer)
struct ServoTarget {
  float angle;            // target angle in degrees
  float oscillationAmp;   // wiggle amplitude (from risk)
  float easeStrength;     // 0=linear, 1=quintic (from elegance)
};

// LED duck target state (output of reducer)
struct LEDTarget {
  int   fillCount;        // 0-10 segments to light
  float brightness;       // 0.0-1.0
  int   chirpFreq;        // Hz for piezo start tone
  int   chirpEndFreq;     // Hz for piezo end tone (ascending=good, descending=bad)
  bool  chirpBuzzy;       // sawtooth-like via fast toggling
};

// Chirp target state (standalone, for I2S or piezo)
struct ChirpTarget {
  int   startFreq;        // Hz start tone
  int   endFreq;          // Hz end tone (ascending=good, descending=bad)
  bool  buzzy;            // sawtooth waveform instead of sine
  float sentiment;        // -1..1 for waveform shaping
};

// ============================================================
// Extern declarations
// ============================================================

extern EvalScores latestScores;
extern bool       newEvalAvailable;

#endif
