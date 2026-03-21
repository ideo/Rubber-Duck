// ============================================================
// Audio Stream (ESP32 Duck — C3 variant)
// ============================================================
// Ring buffer sits between serial input and I2S output.
// Uses pschatzmann/arduino-audio-tools I2SStream which handles
// C3 clock configuration better than raw IDF driver.
//
// Flow:
//   Widget serial → audioStreamWrite() → ring buffer
//   audioFeedI2S() → reads ring buffer → I2SStream.write()

#if ENABLE_AUDIO

#include "AudioTools.h"
#include <math.h>

// ============================================================
// Ring Buffer
// ============================================================

static int16_t  ringBuf[RING_BUF_SAMPLES];
static volatile uint32_t ringWritePos = 0;
static volatile uint32_t ringReadPos  = 0;

static inline uint32_t ringAvailable() {
  uint32_t w = ringWritePos;
  uint32_t r = ringReadPos;
  return (w >= r) ? (w - r) : (RING_BUF_SAMPLES - r + w);
}

static inline uint32_t ringFree() {
  return RING_BUF_SAMPLES - 1 - ringAvailable();
}

static uint32_t ringWrite(const int16_t *samples, uint32_t count) {
  uint32_t free = ringFree();
  if (count > free) count = free;

  for (uint32_t i = 0; i < count; i++) {
    ringBuf[ringWritePos] = samples[i];
    ringWritePos = (ringWritePos + 1) % RING_BUF_SAMPLES;
  }
  return count;
}

static uint32_t ringRead(int16_t *out, uint32_t count) {
  uint32_t avail = ringAvailable();
  if (count > avail) count = avail;

  for (uint32_t i = 0; i < count; i++) {
    out[i] = ringBuf[ringReadPos];
    ringReadPos = (ringReadPos + 1) % RING_BUF_SAMPLES;
  }
  return count;
}

static void ringClear() {
  ringWritePos = 0;
  ringReadPos = 0;
}

// ============================================================
// Audio Stream State
// ============================================================

static bool     streaming = false;
static bool     prefilled = false;
static bool     draining  = false;
static bool     chirpPlaying = false;
static uint32_t totalSamplesReceived = 0;
static uint32_t underrunCount = 0;

// --- pschatzmann I2S output ---
static I2SStream i2sOut;
static bool i2sReady = false;
static uint32_t currentSampleRate = AUDIO_SAMPLE_RATE;

// ============================================================
// I2S Setup (pschatzmann arduino-audio-tools)
// ============================================================

// I2S output rate — 16kHz matches widget input, cleanest on C3
#define I2S_OUTPUT_RATE 16000

void setupAudio() {
  auto cfg = i2sOut.defaultConfig(TX_MODE);
  cfg.sample_rate = I2S_OUTPUT_RATE;
  cfg.bits_per_sample = 16;
  cfg.channels = 2;  // Stereo frames for MAX98357
  cfg.pin_bck = I2S_BCLK_PIN;
  cfg.pin_ws = I2S_WS_PIN;
  cfg.pin_data = I2S_DOUT_PIN;
  cfg.buffer_count = I2S_DMA_BUF_COUNT;
  cfg.buffer_size = I2S_DMA_BUF_LEN * 4;  // bytes (stereo 16-bit = 4 bytes/frame)
  cfg.i2s_format = I2S_STD_FORMAT;

  i2sReady = i2sOut.begin(cfg);

  if (i2sReady) {
    currentSampleRate = AUDIO_SAMPLE_RATE;
    Serial.print("[audio] I2S ready (audio-tools) — BCLK=GPIO");
    Serial.print((int)I2S_BCLK_PIN);
    Serial.print(" WS=GPIO");
    Serial.print((int)I2S_WS_PIN);
    Serial.print(" DOUT=GPIO");
    Serial.println((int)I2S_DOUT_PIN);
  } else {
    Serial.println("[audio] I2S init FAILED");
  }
}

// Helper: change sample rate on the fly
// Note: on C3 we always output at I2S_OUTPUT_RATE and decimate if needed
static void audioSetSampleRate(uint32_t rate) {
  currentSampleRate = rate;
  // I2S hardware stays at I2S_OUTPUT_RATE — decimation happens in audioFeedI2S
}

// ============================================================
// Stream Control
// ============================================================

void audioStreamBegin(uint32_t sampleRate, uint8_t bits, uint8_t channels) {
  ringClear();
  streaming = true;
  prefilled = false;
  draining = false;
  totalSamplesReceived = 0;
  underrunCount = 0;

  audioSetSampleRate(sampleRate);

  Serial.print("[audio] Stream begin — ");
  Serial.print(sampleRate);
  Serial.print("Hz ");
  Serial.print(bits);
  Serial.print("bit ");
  Serial.print(channels);
  Serial.println("ch");
}

void audioStreamEnd() {
  if (!streaming) return;

  streaming = false;
  draining = true;

  Serial.print("[audio] Stream end — received ");
  Serial.print(totalSamplesReceived);
  Serial.print(" samples, ");
  Serial.print(underrunCount);
  Serial.println(" underruns");
}

bool isAudioStreaming() {
  return streaming || draining;
}

void audioChirpBegin() {
  if (!streaming && !draining) {
    ringClear();
    audioSetSampleRate(CHIRP_SAMPLE_RATE);
  }
  chirpPlaying = true;
}

void audioChirpEnd() {
  chirpPlaying = false;
}

// ============================================================
// Serial → Ring Buffer
// ============================================================

void audioStreamWrite(const uint8_t *data, size_t len) {
  if (!streaming && !chirpPlaying) return;

  uint32_t sampleCount = len / 2;
  const int16_t *samples = (const int16_t *)data;

  uint32_t written = ringWrite(samples, sampleCount);
  totalSamplesReceived += written;

  if (written < sampleCount) {
    Serial.print("[audio] OVERRUN dropped ");
    Serial.println(sampleCount - written);
  }

  if (!prefilled && ringAvailable() >= RING_BUF_PREFILL) {
    prefilled = true;
    Serial.println("[audio] Prefill reached, starting playback");
  }
}

// ============================================================
// Ring Buffer → I2S DMA
// ============================================================

static int16_t monoChunk[I2S_DMA_BUF_LEN * 2];  // Extra room for pre-decimation read
static int16_t stereoChunk[I2S_DMA_BUF_LEN * 2];

void audioFeedI2S() {
  if (!i2sReady) return;
  if (!streaming && !draining && !chirpPlaying) return;

  if (streaming && !prefilled && !chirpPlaying) return;

  uint32_t avail = ringAvailable();

  if (draining && !chirpPlaying && avail == 0) {
    draining = false;
    Serial.println("[audio] Drain complete");
    return;
  }

  if (avail == 0) {
    underrunCount++;
    return;
  }

  // No decimation — feed samples straight through
  // If I2S rate != input rate, playback speed will shift but we're testing clock quality
  uint32_t toRead = min((uint32_t)I2S_DMA_BUF_LEN, avail);
  uint32_t got = ringRead(monoChunk, toRead);

  // Expand mono → stereo
  for (uint32_t i = 0; i < got; i++) {
    stereoChunk[i * 2]     = monoChunk[i];
    stereoChunk[i * 2 + 1] = monoChunk[i];
  }

  // Write via pschatzmann I2SStream
  i2sOut.write((uint8_t *)stereoChunk, got * 4);
}

#else

void setupAudio() {}
void audioStreamBegin(uint32_t sr, uint8_t b, uint8_t c) {}
void audioStreamEnd() {}
void audioStreamWrite(const uint8_t *d, size_t l) {}
void audioFeedI2S() {}
bool isAudioStreaming() { return false; }
void audioChirpBegin() {}
void audioChirpEnd() {}

#endif // ENABLE_AUDIO
