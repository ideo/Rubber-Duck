#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// RUBBER DUCK S3 DUCKY — Configuration
// ============================================================
// Custom Ducky PCB with ESP32-S3-WROOM-1-N8R8 module.
// On-board: MAX98357 I2S DAC, ICS-43432 I2S mic, WS2812B
// NeoPixel (via BSS138 level shifter), servo header.
//
// CRITICAL: The speaker amp and mic share the same I2S bus
// (BCLK=GPIO13, LRCLK=GPIO12). This firmware uses full-duplex
// I2S on a single port — setupAudio() MUST run before setupMic().
//
// Pin mapping uses raw GPIO numbers (no Dx board macros).
// ============================================================

// --- Feature Toggles ---
#define ENABLE_SERVO       true   // LEDC PWM servo
#define ENABLE_BUTTON      true   // User button (S3 on PCB)
#define ENABLE_AUDIO       true   // I2S speaker output + serial audio streaming
#define ENABLE_MIC         true   // I2S mic capture + serial streaming to widget
#define ENABLE_NEOPIXEL    true   // WS2812B status LED

// --- Mic Type ---
// This board has an ICS-43432 I2S MEMS mic on the shared I2S bus.
// MIC_TYPE 3 = shared full-duplex I2S (RX handle provided by AudioStream).
#define MIC_TYPE           3       // Shared full-duplex I2S mic

// --- Mic Config (shared) ---
#define MIC_SAMPLE_RATE    16000   // Hz — matches STT expectations
#define MIC_FRAME_SAMPLES  256     // Samples per serial frame (16ms at 16kHz)
#define MIC_FRAME_TAG      0x04    // Serial frame type for mic audio

// --- ADC Mic Config (unused on this board, kept for compatibility) ---
#define MIC_PIN            1       // Unused placeholder
#define MIC_DC_OFFSET      2048    // 12-bit ADC midpoint

// --- I2S Mic Config ---
// ICS-43432 shares BCLK/LRCLK with the MAX98357 speaker amp.
// The RX handle is allocated by setupAudio() in full-duplex mode.
// L/R pin pulled LOW via R8 (10K) = left channel output.
#define MIC_I2S_DIN        1       // GPIO1 — mic serial data (MIC_OUT net)

// --- I2S Port Assignment ---
// Single I2S port in full-duplex mode: TX for speaker, RX for mic.
// Both share BCLK (GPIO13) and LRCLK (GPIO12).
#define AUDIO_I2S_PORT     I2S_NUM_0

// --- I2S Pin Config (shared bus) ---
// Speaker amp (MAX98357) and mic (ICS-43432) share clock lines.
//   GPIO13 → BCLK  (to MAX98357 BCLK + ICS-43432 SCK)
//   GPIO12 → LRCLK (to MAX98357 LRCLK + ICS-43432 WS)
//   GPIO7  → DIN   (to MAX98357 DIN — speaker data out)
//   GPIO1  → SD    (from ICS-43432 SD — mic data in)
#define I2S_BCLK_PIN       13      // GPIO13 — shared bit clock
#define I2S_WS_PIN         12      // GPIO12 — shared word select / LRC
#define I2S_DOUT_PIN       7       // GPIO7  — speaker data to MAX98357

// --- MAX98357 GAIN/SLOT Pin ---
// Controls gain and L/R channel selection on the MAX98357.
// Directly connected to ESP32 GPIO8 (no external pull).
//   HIGH  = 15dB gain, left channel
//   LOW   = 12dB gain, right channel
//   Float = 9dB gain, (L+R)/2 mono (default)
#define AMP_GAIN_PIN       8       // GPIO8 — MAX98357 GAIN_SLOT

// --- Audio Config ---
#define AUDIO_SAMPLE_RATE  16000   // Hz — matches widget AVSpeechSynthesizer output
#define AUDIO_BITS         16      // bits per sample
#define AUDIO_CHANNELS     1       // mono (MAX98357 picks L or R based on GAIN pin)

// I2S DMA buffers — these feed the MAX98357 continuously.
#define I2S_DMA_BUF_COUNT  8       // More DMA buffers = more runway before underrun
#define I2S_DMA_BUF_LEN    256     // samples per DMA buffer

// --- Ring Buffer Config ---
#define RING_BUF_SAMPLES   8192
#define RING_BUF_PREFILL   2048

// --- Serial Config ---
#define SERIAL_BAUD        921600

// --- Serial Audio Framing ---
#define FRAME_MODE_AUDIO   0x01
#define FRAME_MODE_CONTROL 0x02
#define FRAME_MAX_BYTES    1200

// --- NeoPixel Config ---
// WS2812B driven through BSS138 MOSFET level shifter on GPIO38.
// BSS138 gate = VCC_3V3, source = GPIO38 + 10K pull-up to 3V3,
// drain = WS2812B DIN + 10K pull-up to 5V.
#define NEOPIXEL_PIN       38      // GPIO38 — WS2812B data (via level shifter)

// --- Servo Config (LEDC PWM) ---
// 3-pin header JP1: GPIO3 = signal, 5V = power, GND
#define SERVO_PIN          3       // GPIO3 — servo signal
#define SERVO_CENTER       90      // Neutral position (degrees)
#define SERVO_RANGE        80      // +/-degrees from center
#define SERVO_MIN          (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX          (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS    20      // Fixed-rate update interval

// --- Button Config ---
// User button S3 on GPIO2 (with debounce cap C7).
// Boot button S1 on GPIO0 is handled by the ROM bootloader.
// Reset button S2 on EN is hardware reset.
#define BUTTON_PIN         2       // GPIO2 — user button (S3 on PCB)
#define LONG_PRESS_MS      2000    // Hold 2s for snap-to-center

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

// --- Idle Cluster (bird-like micro-adjustments) ---
#define IDLE_CLUSTER_DELTA     30.0f
#define IDLE_CLUSTER_MIN_DELTA 10.0f
#define IDLE_CLUSTER_GAP_MIN   500
#define IDLE_CLUSTER_GAP_MAX   1500

// --- Ambient Spring Physics (nag kicks) ---
#define AMBIENT_SPRING_K       0.03f
#define AMBIENT_SPRING_DAMPING 0.88f

// --- Ambient Lerp (idle hops) ---
#define AMBIENT_LERP_RATE      0.25f

// --- TTS Talking Head Animation ---
#define TTS_RETARGET_MS        300
#define TTS_HOP_RANGE          8.0f

// --- Chirp Synthesis ---
#define CHIRP_BASE_FREQ      280
#define CHIRP_DURATION       250
#define CHIRP_AMPLITUDE      0.5f
#define CHIRP_SAMPLE_RATE    16000
#define WHISTLE_SERVO_KICK   15.0f

// --- Permission Nag Servo ---
#define PERMISSION_NAG_MIN     10.0f
#define PERMISSION_NAG_MAX     30.0f
#define PERMISSION_NAG_KICK    1.2f

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

struct ServoTarget {
  float angle;
  float oscillationAmp;
};

struct ChirpTarget {
  int   startFreq;
  int   endFreq;
  bool  buzzy;
  float sentiment;
  bool  doubleChirp;
};

// ============================================================
// Extern declarations
// ============================================================

extern EvalScores latestScores;
extern bool       newEvalAvailable;

extern float volumeScale;

// Servo state (ServoControl.ino)
extern bool  calibrationMode;
extern float servoCurrentAngle;
extern float servoTargetAngle;
extern float servoVelocity;
extern float servoOscillationAmp;
extern float servoOscillationPhase;
extern float ambientCurrentOffset;
extern float ambientTargetOffset;
extern float ambientVelocity;
extern bool  ambientSpringActive;
extern unsigned long lastEvalTime;
extern int   demoStep;

// Permission state
extern bool permissionPending;
void enterPermission();
void exitPermission();

// Servo helpers (ServoControl.ino)
void snapToCenter();
void triggerDemoPreset();
void resetAmbient();
void updateDeadLevel();
extern bool deadLevelActive;

// Audio helpers (AudioStream.ino)
void setupAudio();
void audioStreamBegin(uint32_t sampleRate, uint8_t bits, uint8_t channels);
void audioStreamEnd();
void audioStreamWrite(const uint8_t *data, size_t len);
void audioFeedI2S();
bool isAudioStreaming();
void audioChirpBegin();
void audioChirpEnd();

// Chirp helpers (ChirpSynth.ino)
ChirpTarget chirpReducer(EvalScores &scores);
void playChirp(ChirpTarget &target);
void playStartupChirp();
void playPermissionChirp();
void updateChirp();
extern float chirpServoOffset;

// Mic capture (MicCapture.ino)
void setupMic();
void updateMic();
void micSetMuted(bool muted);
extern bool micStreaming;

// NeoPixel status (NeoPixelStatus.ino)
void setupNeoPixel();
void updateNeoPixel();
void neoPixelFlash(uint8_t r, uint8_t g, uint8_t b);

#endif
