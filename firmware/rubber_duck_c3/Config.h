#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// RUBBER DUCK C3 — Configuration
// ============================================================
// Seeed XIAO ESP32-C3 (or S3) + MAX98357 I2S DAC + servo.
// Receives eval scores via text serial protocol AND streamed
// TTS audio from the widget over the same USB CDC serial link.
//
// This is the audio duck. No LEDs — just speaker + servo.
// ============================================================

// --- Feature Toggles ---
#define ENABLE_SERVO       true   // LEDC PWM servo
#define ENABLE_BUTTON      true   // Mode/demo button
#define ENABLE_AUDIO       true   // I2S speaker output + serial audio streaming
#define ENABLE_MIC         true   // ADC mic capture + serial streaming to widget

// --- Mic Type ---
// MIC_TYPE selects the capture path:
//   0 = ADC analog mic (C3 / SPW2430)
//   1 = PDM onboard mic (S3 Sense — GPIO42 CLK, GPIO41 DATA)
//   2 = I2S external mic (ICS-43434 or similar)
#if defined(CONFIG_IDF_TARGET_ESP32S3)
  #define MIC_TYPE           2       // I2S external mic (ICS-43434)
#else
  #define MIC_TYPE           0       // ADC analog mic (C3)
#endif

// --- Mic Config (shared) ---
#define MIC_SAMPLE_RATE    16000   // Hz — matches STT expectations
#define MIC_FRAME_SAMPLES  256     // Samples per serial frame (16ms at 16kHz)
#define MIC_FRAME_TAG      0x04    // Serial frame type for mic audio

// --- ADC Mic Config (MIC_TYPE 0) ---
// SPW2430 analog MEMS mic. DC output biased at ~VDD/2 (1.65V).
// S3: D5=GPIO6=A5. C3: move button to D5, use D1=GPIO3=ADC1_CH3.
#define MIC_PIN            D5      // Analog input pin
#define MIC_DC_OFFSET      2048    // 12-bit ADC midpoint (VDD/2)

// --- I2S Mic Config (MIC_TYPE 2) ---
// Adafruit ICS-43434 I2S MEMS mic. 24-bit, wired to free XIAO pins.
// L/R pin tied to GND = left channel.
#define MIC_I2S_SCK        D9      // GPIO8 — bit clock
#define MIC_I2S_WS         D10     // GPIO9 — word select
#define MIC_I2S_SD         D1      // GPIO2 — serial data in

// --- I2S Port Assignment ---
// S3 has 2 I2S ports. I2S/PDM mic takes I2S_NUM_0, speaker goes on I2S_NUM_1.
// C3 has 1 I2S port. Speaker uses I2S_NUM_0, mic uses ADC timer (no I2S).
#if defined(CONFIG_IDF_TARGET_ESP32S3)
  #define AUDIO_I2S_PORT   I2S_NUM_1
#else
  #define AUDIO_I2S_PORT   I2S_NUM_0
#endif

// --- I2S Pin Config ---
// Board macros D2/D3/D4 resolve correctly on both C3 and S3.
//   S3 Sense: D2=GPIO3, D3=GPIO4, D4=GPIO5
//   C3:       D2=GPIO4, D3=GPIO5, D4=GPIO6
#define I2S_BCLK_PIN       D2
#define I2S_WS_PIN         D3
#define I2S_DOUT_PIN       D4

// --- Audio Config ---
#define AUDIO_SAMPLE_RATE  16000   // Hz — matches widget AVSpeechSynthesizer output
#define AUDIO_BITS         16      // bits per sample
#define AUDIO_CHANNELS     1       // mono (MAX98357 picks L or R based on SD pin)

// I2S DMA buffers — these feed the MAX98357 continuously.
// 4 buffers × 256 samples = 64ms of DMA runway.
#define I2S_DMA_BUF_COUNT  8       // More DMA buffers = more runway before underrun
#define I2S_DMA_BUF_LEN    256     // samples per DMA buffer

// --- Ring Buffer Config ---
// Sits between serial input and I2S DMA output.
// Must be large enough to absorb serial jitter without underrun.
// 8192 samples × 2 bytes = 16KB = 512ms at 16kHz / 371ms at 22050Hz.
// ESP32-C3 has 400KB SRAM — 16KB is fine.
#define RING_BUF_SAMPLES   8192

// Buffer this many samples before starting I2S playback.
// Larger prefill = more latency but fewer underruns.
// 2048 = 128ms at 16kHz / 93ms at 22050Hz.
#define RING_BUF_PREFILL   2048

// --- Serial Config ---
// USB CDC doesn't have a real baud rate — this is nominal.
// Set high to signal fast link to serial monitors.
#define SERIAL_BAUD        921600

// --- Serial Audio Framing ---
// During audio mode (between A,16000,16,1\n and A,0\n):
//   0x01 [len_hi] [len_lo] [PCM bytes...]   — audio frame
//   0x02 [len bytes of text ending in \n]    — control message
// Outside audio mode: plain text, newline-terminated (same as Teensy).
#define FRAME_MODE_AUDIO   0x01
#define FRAME_MODE_CONTROL 0x02
#define FRAME_MAX_BYTES    1200    // Max single frame payload (keep under CDC buffer)

// --- Servo Config (LEDC PWM) ---
#define SERVO_PIN          D0      // D0 on XIAO
#define SERVO_CENTER       90      // Neutral position (degrees)
#define SERVO_RANGE        80      // ±degrees from center
#define SERVO_MIN          (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX          (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS    20      // Fixed-rate update interval

// --- Button Config ---
#define BUTTON_PIN         D8      // D8 on XIAO S3 (GPIO7). D1 reserved for future use.
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

// --- Idle Cluster (bird-like micro-adjustments — matches Teensy) ---
#define IDLE_CLUSTER_DELTA     30.0f   // ±degrees max for follow-up micro-hops
#define IDLE_CLUSTER_MIN_DELTA 10.0f   // Minimum degrees per micro-hop (below is invisible)
#define IDLE_CLUSTER_GAP_MIN   500     // Min ms between cluster positions
#define IDLE_CLUSTER_GAP_MAX   1500    // Max ms between cluster positions

// --- Ambient Spring Physics (nag kicks — matches Teensy) ---
#define AMBIENT_SPRING_K       0.03f   // Half stiffness of conscious spring
#define AMBIENT_SPRING_DAMPING 0.88f   // More damped = dreamier motion

// --- Ambient Lerp (idle hops — matches Teensy) ---
#define AMBIENT_LERP_RATE      0.25f   // Fraction per frame

// --- TTS Talking Head Animation ---
#define TTS_RETARGET_MS        300     // ms between ambient retargets while speaking
#define TTS_HOP_RANGE          8.0f    // ±degrees for talking head wobble

// --- Chirp Synthesis ---
#define CHIRP_BASE_FREQ      280     // Hz — center of sentiment range
#define CHIRP_DURATION       250     // ms — single chirp
#define CHIRP_AMPLITUDE      0.5f    // 0.0-1.0 volume for oscillator
#define CHIRP_SAMPLE_RATE    16000   // Hz — chirp synth runs at this rate
#define WHISTLE_SERVO_KICK   15.0f   // Degrees of head kick during whistle

// --- Permission Nag Servo (matches Teensy) ---
#define PERMISSION_NAG_MIN     10.0f   // Min offset from center
#define PERMISSION_NAG_MAX     30.0f   // Max offset from center
#define PERMISSION_NAG_KICK    1.2f    // Velocity kick for snap

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
  float angle;               // Target angle (offset from center)
  float oscillationAmp;      // Wiggle amplitude (from risk)
};

struct ChirpTarget {
  int   startFreq;
  int   endFreq;
  bool  buzzy;           // true = sawtooth, false = sine
  float sentiment;
  bool  doubleChirp;     // two-note pattern
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
extern float servoVelocity;
extern float servoOscillationAmp;
extern float servoOscillationPhase;
extern float ambientCurrentOffset;
extern float ambientTargetOffset;
extern float ambientVelocity;
extern bool  ambientSpringActive;
extern unsigned long lastEvalTime;
extern int   demoStep;

// Permission state (rubber_duck_c3.ino)
extern bool permissionPending;
void enterPermission();
void exitPermission();

// Servo helpers (ServoControl.ino)
void snapToCenter();
void triggerDemoPreset();
void resetAmbient();

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
void micSetMuted(bool muted);  // Gate: mute during TTS playback
extern bool micStreaming;       // true when widget has requested mic data

#endif
