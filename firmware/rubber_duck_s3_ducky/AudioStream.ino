// ============================================================
// Audio Stream — Full-Duplex I2S (Ducky Custom PCB)
// ============================================================
// On this board, the MAX98357 speaker amp and ICS-43432 mic
// share the same I2S bus (BCLK=GPIO13, LRCLK=GPIO12).
//
// This file allocates a SINGLE I2S port (I2S_NUM_0) in
// full-duplex mode:
//   TX → GPIO7  (speaker DIN)
//   RX → GPIO1  (mic data out)
//
// The RX handle is exported as sharedMicRxHandle so that
// MicCapture.ino can use it without allocating a second port.
//
// IMPORTANT: setupAudio() MUST be called before setupMic().
//
// Flow:
//   Widget serial → audioStreamWrite() → ring buffer
//   audioFeedI2S() → reads ring buffer → i2s_channel_write()

#if ENABLE_AUDIO

#include "driver/i2s_std.h"
#include "driver/gpio.h"
#include <math.h>

// Forward declarations — StoredAudio.ino (sorted after AudioStream.ino)
bool isStoredAudioPlaying();
void storedAudioStop();

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

// --- I2S channel handles ---
static i2s_chan_handle_t txHandle = NULL;
static uint32_t currentSampleRate = AUDIO_SAMPLE_RATE;

// Shared RX handle — exported for MicCapture.ino
i2s_chan_handle_t sharedMicRxHandle = NULL;

// ============================================================
// I2S Setup — Full-Duplex (TX + RX on same port)
// ============================================================

void setupAudio() {
  // Allocate both TX (speaker) and RX (mic) from the same I2S port.
  // They share BCLK and WS pins; only data pins differ.
  i2s_chan_config_t chanCfg = I2S_CHANNEL_DEFAULT_CONFIG(AUDIO_I2S_PORT, I2S_ROLE_MASTER);
  chanCfg.dma_desc_num = I2S_DMA_BUF_COUNT;
  chanCfg.dma_frame_num = I2S_DMA_BUF_LEN;
  chanCfg.auto_clear = true;  // Silence on underrun

  esp_err_t err = i2s_new_channel(&chanCfg, &txHandle, &sharedMicRxHandle);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S full-duplex channel alloc failed: %d\n", err);
    return;
  }

  // --- Initialize TX channel (speaker) ---
  // 16-bit stereo Philips — MAX98357 reads the slot selected by GAIN_SLOT pin.
  // We send mono expanded to stereo (L=R), so slot selection only affects gain.
  i2s_std_config_t txCfg = {
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

  err = i2s_channel_init_std_mode(txHandle, &txCfg);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S TX init failed: %d\n", err);
    i2s_del_channel(txHandle);
    i2s_del_channel(sharedMicRxHandle);
    txHandle = NULL;
    sharedMicRxHandle = NULL;
    return;
  }

  // --- Initialize RX channel (mic) ---
  // ICS-43432: 24-bit data, but we use 16-bit slots on the shared bus.
  // The mic outputs its 16 MSBs in the left slot (L/R pin = LOW).
  // Mono mode with left slot mask — DMA buffer gets only left channel samples.
  i2s_std_config_t rxCfg = {
    .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE),
    .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
    .gpio_cfg = {
      .mclk = I2S_GPIO_UNUSED,
      .bclk = (gpio_num_t)I2S_BCLK_PIN,
      .ws = (gpio_num_t)I2S_WS_PIN,
      .dout = I2S_GPIO_UNUSED,
      .din = (gpio_num_t)MIC_I2S_DIN,
      .invert_flags = {
        .mclk_inv = false,
        .bclk_inv = false,
        .ws_inv = false,
      },
    },
  };
  rxCfg.slot_cfg.slot_mask = I2S_STD_SLOT_LEFT;

  err = i2s_channel_init_std_mode(sharedMicRxHandle, &rxCfg);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S RX init failed: %d\n", err);
    // Speaker can still work without mic
    i2s_del_channel(sharedMicRxHandle);
    sharedMicRxHandle = NULL;
  }

  // --- Enable channels ---
  err = i2s_channel_enable(txHandle);
  if (err != ESP_OK) {
    Serial.printf("[audio] I2S TX enable failed: %d\n", err);
    i2s_del_channel(txHandle);
    txHandle = NULL;
  }

  if (sharedMicRxHandle) {
    err = i2s_channel_enable(sharedMicRxHandle);
    if (err != ESP_OK) {
      Serial.printf("[audio] I2S RX enable failed: %d\n", err);
      i2s_del_channel(sharedMicRxHandle);
      sharedMicRxHandle = NULL;
    }
  }

  // Leave MAX98357 GAIN_SLOT pin floating for 9dB default gain.
  // The pin has no external pull on the PCB, so INPUT mode = floating.
  pinMode(AMP_GAIN_PIN, INPUT);

  currentSampleRate = AUDIO_SAMPLE_RATE;

  Serial.printf("[audio] I2S full-duplex ready — BCLK=GPIO%d WS=GPIO%d DOUT=GPIO%d DIN=GPIO%d\n",
                I2S_BCLK_PIN, I2S_WS_PIN, I2S_DOUT_PIN, MIC_I2S_DIN);
  if (!sharedMicRxHandle) {
    Serial.println("[audio] WARNING: Mic RX channel not available");
  }
}

// Helper: change sample rate on the fly.
// Affects BOTH TX and RX since they share the same clock.
static void audioSetSampleRate(uint32_t rate) {
  if (!txHandle || rate == currentSampleRate) return;

  i2s_channel_disable(txHandle);
  if (sharedMicRxHandle) i2s_channel_disable(sharedMicRxHandle);

  i2s_std_clk_config_t clkCfg = I2S_STD_CLK_DEFAULT_CONFIG(rate);
  i2s_channel_reconfig_std_clock(txHandle, &clkCfg);

  i2s_channel_enable(txHandle);
  if (sharedMicRxHandle) i2s_channel_enable(sharedMicRxHandle);

  currentSampleRate = rate;
}

// ============================================================
// Stream Control
// ============================================================

void audioStreamBegin(uint32_t sampleRate, uint8_t bits, uint8_t channels) {
  storedAudioStop();
  ringClear();
  streaming = true;
  prefilled = false;
  draining = false;
  totalSamplesReceived = 0;
  underrunCount = 0;

  audioSetSampleRate(sampleRate);
}

void audioStreamEnd() {
  if (!streaming) return;

  streaming = false;
  draining = true;
}

bool isAudioStreaming() {
  return streaming || draining;
}

bool isAudioBusy() {
  return streaming || draining || chirpPlaying;
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
// Serial -> Ring Buffer
// ============================================================

void audioStreamWrite(const uint8_t *data, size_t len) {
  if (!streaming && !chirpPlaying) return;

  uint32_t sampleCount = len / 2;
  const int16_t *samples = (const int16_t *)data;

  uint32_t written = ringWrite(samples, sampleCount);
  totalSamplesReceived += written;

  if (!prefilled && ringAvailable() >= RING_BUF_PREFILL) {
    prefilled = true;
  }
}

// ============================================================
// Ring Buffer -> I2S DMA
// ============================================================

static int16_t monoChunk[I2S_DMA_BUF_LEN];
static int16_t stereoChunk[I2S_DMA_BUF_LEN * 2];

void audioFeedI2S() {
  if (!txHandle) return;
  if (!streaming && !draining && !chirpPlaying && !isStoredAudioPlaying()) return;

  if (streaming && !prefilled && !chirpPlaying) return;

  uint32_t avail = ringAvailable();

  if (draining && !chirpPlaying && !isStoredAudioPlaying() && avail == 0) {
    draining = false;
    return;
  }

  if (avail == 0) {
    underrunCount++;
    return;
  }

  uint32_t toRead = min((uint32_t)I2S_DMA_BUF_LEN, avail);
  uint32_t got = ringRead(monoChunk, toRead);

  // Expand mono -> stereo (MAX98357 expects stereo I2S frames)
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
void audioChirpBegin() {}
void audioChirpEnd() {}

// Still need to provide the shared handle symbol even when audio is disabled
i2s_chan_handle_t sharedMicRxHandle = NULL;

#endif // ENABLE_AUDIO
