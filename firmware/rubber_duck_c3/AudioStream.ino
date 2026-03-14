// ============================================================
// Audio Stream (ESP32 Duck)
// ============================================================
// Ring buffer sits between serial input and I2S DMA output.
// Uses the new IDF I2S STD driver (driver/i2s_std.h) so it can
// coexist with the PDM mic driver on a separate port.
//
// Flow:
//   Widget serial → audioStreamWrite() → ring buffer
//   audioFeedI2S() → reads ring buffer → i2s_channel_write()

#if ENABLE_AUDIO

#include "driver/i2s_std.h"
#include "driver/gpio.h"
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

// --- New IDF I2S channel handle ---
static i2s_chan_handle_t txHandle = NULL;
static uint32_t currentSampleRate = AUDIO_SAMPLE_RATE;

// ============================================================
// I2S Setup (new IDF driver)
// ============================================================

void setupAudio() {
  i2s_chan_config_t chanCfg = I2S_CHANNEL_DEFAULT_CONFIG(AUDIO_I2S_PORT, I2S_ROLE_MASTER);
  chanCfg.dma_desc_num = I2S_DMA_BUF_COUNT;
  chanCfg.dma_frame_num = I2S_DMA_BUF_LEN;
  chanCfg.auto_clear = true;  // Silence on underrun (replaces tx_desc_auto_clear)

  esp_err_t err = i2s_new_channel(&chanCfg, &txHandle, NULL);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S channel alloc failed: %d\n", err);
    return;
  }

  i2s_std_config_t stdCfg = {
    .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE),
    .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO),
    .gpio_cfg = {
      .mclk = I2S_GPIO_UNUSED,
      .bclk = (gpio_num_t)I2S_BCLK_PIN,
      .ws = (gpio_num_t)I2S_WS_PIN,
      .dout = (gpio_num_t)I2S_DOUT_PIN,
      .din = I2S_GPIO_UNUSED,
      .invert_flags = {
        .mclk_inv = false,
        .bclk_inv = false,
        .ws_inv = false,
      },
    },
  };

  err = i2s_channel_init_std_mode(txHandle, &stdCfg);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S STD init failed: %d\n", err);
    i2s_del_channel(txHandle);
    txHandle = NULL;
    return;
  }

  err = i2s_channel_enable(txHandle);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S enable failed: %d\n", err);
    i2s_del_channel(txHandle);
    txHandle = NULL;
    return;
  }

  currentSampleRate = AUDIO_SAMPLE_RATE;

  Serial.print("[audio] I2S ready — BCLK=GPIO");
  Serial.print((int)I2S_BCLK_PIN);
  Serial.print(" WS=GPIO");
  Serial.print((int)I2S_WS_PIN);
  Serial.print(" DOUT=GPIO");
  Serial.println((int)I2S_DOUT_PIN);
}

// Helper: change sample rate on the fly
static void audioSetSampleRate(uint32_t rate) {
  if (!txHandle || rate == currentSampleRate) return;

  i2s_channel_disable(txHandle);
  i2s_std_clk_config_t clkCfg = I2S_STD_CLK_DEFAULT_CONFIG(rate);
  i2s_channel_reconfig_std_clock(txHandle, &clkCfg);
  i2s_channel_enable(txHandle);
  currentSampleRate = rate;
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

static int16_t monoChunk[I2S_DMA_BUF_LEN];
static int16_t stereoChunk[I2S_DMA_BUF_LEN * 2];

void audioFeedI2S() {
  if (!txHandle) return;
  if (!streaming && !draining && !chirpPlaying) return;

  if (streaming && !prefilled && !chirpPlaying) return;

  uint32_t avail = ringAvailable();

  if (draining && !chirpPlaying && avail == 0) {
    draining = false;
    // auto_clear handles silence
    Serial.println("[audio] Drain complete");
    return;
  }

  if (avail == 0) {
    underrunCount++;
    return;
  }

  uint32_t toRead = min((uint32_t)I2S_DMA_BUF_LEN, avail);
  uint32_t got = ringRead(monoChunk, toRead);

  // Expand mono → stereo
  for (uint32_t i = 0; i < got; i++) {
    stereoChunk[i * 2]     = monoChunk[i];
    stereoChunk[i * 2 + 1] = monoChunk[i];
  }

  // ZERO timeout — never block
  size_t bytesWritten = 0;
  i2s_channel_write(txHandle, stereoChunk, got * 4, &bytesWritten, 0);

  uint32_t samplesWritten = bytesWritten / 4;
  if (samplesWritten < got) {
    uint32_t unwritten = got - samplesWritten;
    ringReadPos = (ringReadPos + RING_BUF_SAMPLES - unwritten) % RING_BUF_SAMPLES;
  }
}

#else

void setupAudio() {}
void audioStreamBegin(uint32_t sr, uint8_t b, uint8_t c) {}
void audioStreamEnd() {}
void audioStreamWrite(const uint8_t *d, size_t l) {}
void audioFeedI2S() {}
bool isAudioStreaming() { return false; }

#endif // ENABLE_AUDIO
