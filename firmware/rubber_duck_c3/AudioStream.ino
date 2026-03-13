// ============================================================
// Audio Stream (ESP32-C3 Duck)
// ============================================================
// Ring buffer sits between serial input and I2S DMA output.
// The widget streams TTS audio as binary PCM frames over serial.
// This module buffers those frames and feeds I2S continuously.
//
// Flow:
//   Widget serial → audioStreamWrite() → ring buffer
//   audioFeedI2S() → reads ring buffer → i2s_write()
//
// Call audioFeedI2S() from loop(). It uses a SHORT timeout on
// i2s_write so it doesn't block the serial reader for long.

#if ENABLE_AUDIO

#include <driver/i2s.h>
#include <math.h>

// ============================================================
// Ring Buffer
// ============================================================
// Lock-free single-producer single-consumer ring buffer.
// Producer: readSerial() → audioStreamWrite()
// Consumer: audioFeedI2S() in main loop

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
static bool     chirpPlaying = false;  // Chirp synth is writing to ring buffer
static uint32_t totalSamplesReceived = 0;
static uint32_t underrunCount = 0;

// ============================================================
// I2S Setup
// ============================================================

void setupAudio() {
  i2s_config_t i2s_config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
    .sample_rate = AUDIO_SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = I2S_DMA_BUF_COUNT,
    .dma_buf_len = I2S_DMA_BUF_LEN,
    .use_apll = false,
    .tx_desc_auto_clear = true,
  };

  i2s_pin_config_t pin_config = {
    .bck_io_num = I2S_BCLK_PIN,
    .ws_io_num = I2S_WS_PIN,
    .data_out_num = I2S_DOUT_PIN,
    .data_in_num = I2S_PIN_NO_CHANGE,
  };

  esp_err_t err = i2s_driver_install(I2S_NUM_0, &i2s_config, 0, NULL);
  if (err != ESP_OK) {
    Serial.print("[audio] I2S driver install FAILED: ");
    Serial.println(err);
    return;
  }

  err = i2s_set_pin(I2S_NUM_0, &pin_config);
  if (err != ESP_OK) {
    Serial.print("[audio] I2S set pin FAILED: ");
    Serial.println(err);
    return;
  }

  i2s_zero_dma_buffer(I2S_NUM_0);

  Serial.print("[audio] I2S ready — BCLK=GPIO");
  Serial.print((int)I2S_BCLK_PIN);
  Serial.print(" WS=GPIO");
  Serial.print((int)I2S_WS_PIN);
  Serial.print(" DOUT=GPIO");
  Serial.println((int)I2S_DOUT_PIN);
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

  if (sampleRate != AUDIO_SAMPLE_RATE) {
    i2s_set_sample_rates(I2S_NUM_0, sampleRate);
  }

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
  // If TTS streaming, don't interrupt — chirp will mix in
  if (!streaming && !draining) {
    ringClear();
    // Reset I2S sample rate to chirp rate (TTS may have changed it)
    i2s_set_sample_rates(I2S_NUM_0, CHIRP_SAMPLE_RATE);
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
// Called from loop(). Pushes available samples to I2S.
//
// Key design: use a SHORT timeout (5ms) on i2s_write so we
// don't block the serial reader. If DMA buffers are full,
// we return and let loop() run readSerial() to get more data.
// The I2S DMA auto-clear plays silence on underrun so we
// don't need to manually write silence.

// Scratch buffers
static int16_t monoChunk[I2S_DMA_BUF_LEN];
static int16_t stereoChunk[I2S_DMA_BUF_LEN * 2];

void audioFeedI2S() {
  if (!streaming && !draining && !chirpPlaying) return;

  // Wait for prefill before starting playback (not for chirps — they play immediately)
  if (streaming && !prefilled && !chirpPlaying) return;

  uint32_t avail = ringAvailable();

  // Draining: if buffer empty, we're done
  if (draining && !chirpPlaying && avail == 0) {
    draining = false;
    i2s_zero_dma_buffer(I2S_NUM_0);
    Serial.println("[audio] Drain complete");
    return;
  }

  if (avail == 0) {
    // Underrun while streaming — I2S auto-clear handles silence
    underrunCount++;
    return;
  }

  // Read whatever we have, up to DMA buffer size
  uint32_t toRead = min((uint32_t)I2S_DMA_BUF_LEN, avail);
  uint32_t got = ringRead(monoChunk, toRead);

  // Expand mono → stereo
  for (uint32_t i = 0; i < got; i++) {
    stereoChunk[i * 2]     = monoChunk[i];
    stereoChunk[i * 2 + 1] = monoChunk[i];
  }

  // ZERO timeout — never block. If DMA buffers are full, drop this
  // chunk and try again next loop(). Blocking here starves the serial
  // reader, causing CDC buffer overflow and byte loss = desync.
  // With 8 DMA buffers × 256 samples = 93ms runway at 22050Hz,
  // we'll almost always have a free buffer.
  size_t bytesWritten;
  i2s_write(I2S_NUM_0, stereoChunk, got * 4, &bytesWritten, 0);

  // If DMA rejected some data, put unwritten samples back
  uint32_t samplesWritten = bytesWritten / 4;  // stereo bytes → mono samples
  if (samplesWritten < got) {
    // Rewind ring buffer read position for unwritten samples
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
