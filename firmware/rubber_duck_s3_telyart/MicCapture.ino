// ============================================================
// Mic Capture (ESP32 Duck)
// ============================================================
// Three modes selected by MIC_TYPE in Config.h:
//   0 = ADC analog mic via hardware timer (C3 / SPW2430)
//   1 = PDM onboard mic via IDF I2S PDM driver (S3 Sense)
//   2 = I2S external mic via IDF I2S STD driver (ICS-43434)
//
// Streams 16-bit PCM at 16kHz back to the widget over serial.
// ============================================================

#if ENABLE_MIC

// --- Output buffer ---
static int16_t micOutBuf[MIC_FRAME_SAMPLES];

// --- State ---
bool micStreaming = false;
static bool micMuted = false;

// ============================================================
// Path 1: S3 Sense PDM mic via IDF I2S PDM driver
// ============================================================
#if MIC_TYPE == 1

#include "driver/i2s_pdm.h"
#include "driver/gpio.h"

static i2s_chan_handle_t micRxHandle = NULL;

// --- DC tracking + gain for PDM path ---
static float pdmDC = 0.0f;
static float pdmGain = 16.0f;
static const float PDM_DC_ALPHA = 0.001f;


void setupMic() {
  i2s_chan_config_t chanCfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_AUTO, I2S_ROLE_MASTER);
  chanCfg.dma_desc_num = 4;
  chanCfg.dma_frame_num = MIC_FRAME_SAMPLES;

  esp_err_t err = i2s_new_channel(&chanCfg, NULL, &micRxHandle);
  if (err != ESP_OK) {
    Serial.printf("[mic] PDM channel alloc failed: %d\n", err);
    return;
  }

  i2s_pdm_rx_config_t pdmCfg = {
    .clk_cfg = I2S_PDM_RX_CLK_DEFAULT_CONFIG(MIC_SAMPLE_RATE),
    .slot_cfg = I2S_PDM_RX_SLOT_PCM_FMT_DEFAULT_CONFIG(
      I2S_DATA_BIT_WIDTH_16BIT,
      I2S_SLOT_MODE_MONO
    ),
    .gpio_cfg = {
      .clk = GPIO_NUM_42,
      .din = GPIO_NUM_41,
      .invert_flags = { .clk_inv = false },
    },
  };

  err = i2s_channel_init_pdm_rx_mode(micRxHandle, &pdmCfg);
  if (err != ESP_OK) {
    Serial.printf("[mic] PDM init failed: %d\n", err);
    i2s_del_channel(micRxHandle);
    micRxHandle = NULL;
    return;
  }

  err = i2s_channel_enable(micRxHandle);
  if (err != ESP_OK) {
    Serial.printf("[mic] PDM enable failed: %d\n", err);
    i2s_del_channel(micRxHandle);
    micRxHandle = NULL;
    return;
  }

  // Calibrate DC offset from a few frames of silence
  int16_t calBuf[MIC_FRAME_SAMPLES];
  size_t calRead = 0;
  long calSum = 0;
  int calCount = 0;
  for (int f = 0; f < 4; f++) {
    if (i2s_channel_read(micRxHandle, calBuf, sizeof(calBuf), &calRead, pdMS_TO_TICKS(100)) == ESP_OK) {
      for (int i = 0; i < MIC_FRAME_SAMPLES; i++) {
        calSum += calBuf[i];
        calCount++;
      }
    }
  }
  pdmDC = (calCount > 0) ? (float)calSum / calCount : 0.0f;

  // Estimate noise floor for auto-gain + noise gate threshold
  float noiseSum = 0;
  if (calCount > 0) {
    // Re-read for noise measurement
    if (i2s_channel_read(micRxHandle, calBuf, sizeof(calBuf), &calRead, pdMS_TO_TICKS(100)) == ESP_OK) {
      for (int i = 0; i < MIC_FRAME_SAMPLES; i++) {
        float d = (float)calBuf[i] - pdmDC;
        noiseSum += d * d;
      }
      float noiseRMS = sqrtf(noiseSum / MIC_FRAME_SAMPLES);
      // Target: speech peaks at ~50% of full range
      if (noiseRMS > 0.5f) {
        pdmGain = constrain(1600.0f / noiseRMS, 16.0f, 512.0f);
      }
      Serial.printf("[mic] PDM cal — DC: %.0f  noise: %.1f  gain: %.1f\n",
                    pdmDC, noiseRMS, pdmGain);
    }
  }

  Serial.println("[mic] PDM mic ready (S3 Sense onboard)");
}

void updateMic() {
  if (!micStreaming || micMuted || !micRxHandle) return;

  size_t bytesRead = 0;
  size_t bytesNeeded = MIC_FRAME_SAMPLES * sizeof(int16_t);

  esp_err_t err = i2s_channel_read(micRxHandle, micOutBuf, bytesNeeded, &bytesRead, pdMS_TO_TICKS(50));
  if (err != ESP_OK || bytesRead < bytesNeeded) return;

  // DC removal + gain
  for (int i = 0; i < MIC_FRAME_SAMPLES; i++) {
    float raw = (float)micOutBuf[i];
    pdmDC += PDM_DC_ALPHA * (raw - pdmDC);
    float sample = (raw - pdmDC) * pdmGain;
    if (sample > 32767.0f) sample = 32767.0f;
    if (sample < -32767.0f) sample = -32767.0f;
    micOutBuf[i] = (int16_t)sample;
  }


  // Send frame over serial
  uint16_t byteLen = MIC_FRAME_SAMPLES * 2;
  uint8_t header[3];
  header[0] = MIC_FRAME_TAG;
  header[1] = (byteLen >> 8) & 0xFF;
  header[2] = byteLen & 0xFF;

  Serial.write(header, 3);
  Serial.write((const uint8_t *)micOutBuf, byteLen);
}

void micSetMuted(bool muted) {
  micMuted = muted;
}

// ============================================================
// Path 2: I2S external mic (ICS-43434) via IDF I2S STD driver
// ============================================================
#elif MIC_TYPE == 2

#include "driver/i2s_std.h"
#include "driver/gpio.h"

static i2s_chan_handle_t micRxHandle = NULL;

// --- DC tracking + gain for I2S path ---
static float i2sDC = 0.0f;
static float i2sGain = 1.0f;
static const float I2S_DC_ALPHA = 0.001f;

void setupMic() {
  i2s_chan_config_t chanCfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
  chanCfg.dma_desc_num = 4;
  chanCfg.dma_frame_num = MIC_FRAME_SAMPLES;

  esp_err_t err = i2s_new_channel(&chanCfg, NULL, &micRxHandle);
  if (err != ESP_OK) {
    Serial.printf("[mic] I2S channel alloc failed: %d\n", err);
    return;
  }

  i2s_std_config_t stdCfg = {
    .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(MIC_SAMPLE_RATE),
    .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(
      I2S_DATA_BIT_WIDTH_32BIT,    // ICS-43434 sends 24-bit left-justified in 32-bit frame
      I2S_SLOT_MODE_MONO
    ),
    .gpio_cfg = {
      .mclk = I2S_GPIO_UNUSED,
      .bclk = (gpio_num_t)MIC_I2S_SCK,
      .ws   = (gpio_num_t)MIC_I2S_WS,
      .dout = I2S_GPIO_UNUSED,
      .din  = (gpio_num_t)MIC_I2S_SD,
      .invert_flags = {
        .mclk_inv = false,
        .bclk_inv = false,
        .ws_inv   = false,
      },
    },
  };
  // ICS-43434 with L/R=GND outputs on left channel
  stdCfg.slot_cfg.slot_mask = I2S_STD_SLOT_LEFT;

  err = i2s_channel_init_std_mode(micRxHandle, &stdCfg);
  if (err != ESP_OK) {
    Serial.printf("[mic] I2S STD init failed: %d\n", err);
    i2s_del_channel(micRxHandle);
    micRxHandle = NULL;
    return;
  }

  err = i2s_channel_enable(micRxHandle);
  if (err != ESP_OK) {
    Serial.printf("[mic] I2S enable failed: %d\n", err);
    i2s_del_channel(micRxHandle);
    micRxHandle = NULL;
    return;
  }

  // Calibrate DC offset + noise floor from silence
  int32_t calBuf[MIC_FRAME_SAMPLES];
  size_t calRead = 0;
  long long calSum = 0;
  int calCount = 0;
  for (int f = 0; f < 4; f++) {
    if (i2s_channel_read(micRxHandle, calBuf, sizeof(calBuf), &calRead, pdMS_TO_TICKS(100)) == ESP_OK) {
      int samplesRead = calRead / sizeof(int32_t);
      for (int i = 0; i < samplesRead; i++) {
        calSum += (calBuf[i] >> 8);  // 24-bit in top bits → shift to signed 24-bit range
        calCount++;
      }
    }
  }
  i2sDC = (calCount > 0) ? (float)(calSum / calCount) : 0.0f;

  // Noise floor measurement for auto-gain
  float noiseSum = 0;
  if (calCount > 0) {
    if (i2s_channel_read(micRxHandle, calBuf, sizeof(calBuf), &calRead, pdMS_TO_TICKS(100)) == ESP_OK) {
      int samplesRead = calRead / sizeof(int32_t);
      for (int i = 0; i < samplesRead; i++) {
        float val = (float)(calBuf[i] >> 8) - i2sDC;
        noiseSum += val * val;
      }
      float noiseRMS = sqrtf(noiseSum / samplesRead);
      // ICS-43434 is 24-bit — after >>8 shift, values are in ±~8M range.
      // Noise floor is typically ~100k RMS. Speech at 30cm ≈ 5-20x noise.
      // Target: speech peaks at ~50% of int16 range (16384).
      // Gain = 16384 / (noiseRMS * estimated_speech_multiplier)
      if (noiseRMS > 10.0f) {
        i2sGain = constrain(16384.0f / (noiseRMS * 4.0f), 0.001f, 4.0f);
      } else {
        i2sGain = 0.02f;  // Safe default for ICS-43434
      }
      Serial.printf("[mic] I2S cal — DC: %.0f  noise: %.1f  gain: %.4f\n",
                    i2sDC, noiseRMS, i2sGain);
    }
  }
  if (i2sGain < 0.0001f) i2sGain = 0.004f;

  Serial.println("[mic] I2S mic ready (ICS-43434 external)");
}

void updateMic() {
  if (!micStreaming || micMuted || !micRxHandle) return;

  // Read 32-bit samples from I2S
  int32_t rawBuf[MIC_FRAME_SAMPLES];
  size_t bytesRead = 0;
  size_t bytesNeeded = MIC_FRAME_SAMPLES * sizeof(int32_t);

  esp_err_t err = i2s_channel_read(micRxHandle, rawBuf, bytesNeeded, &bytesRead, pdMS_TO_TICKS(50));
  if (err != ESP_OK || bytesRead < bytesNeeded) return;

  // Convert 32-bit → 16-bit with DC removal + gain
  for (int i = 0; i < MIC_FRAME_SAMPLES; i++) {
    float raw = (float)(rawBuf[i] >> 8);  // 24-bit in top bits
    i2sDC += I2S_DC_ALPHA * (raw - i2sDC);
    float sample = (raw - i2sDC) * i2sGain;
    if (sample > 32767.0f) sample = 32767.0f;
    if (sample < -32767.0f) sample = -32767.0f;
    micOutBuf[i] = (int16_t)sample;
  }

  // Send frame over serial
  uint16_t byteLen = MIC_FRAME_SAMPLES * 2;
  uint8_t header[3];
  header[0] = MIC_FRAME_TAG;
  header[1] = (byteLen >> 8) & 0xFF;
  header[2] = byteLen & 0xFF;

  Serial.write(header, 3);
  Serial.write((const uint8_t *)micOutBuf, byteLen);
}

void micSetMuted(bool muted) {
  micMuted = muted;
}

// ============================================================
// Path 3: Analog ADC mic via hardware timer (C3 / external)
// ============================================================
#elif MIC_TYPE == 0

// --- Raw ADC double buffer (ISR writes raw 12-bit values) ---
static volatile uint16_t rawBufA[MIC_FRAME_SAMPLES];
static volatile uint16_t rawBufB[MIC_FRAME_SAMPLES];
static volatile uint16_t *rawWriteBuf = rawBufA;
static volatile uint16_t *rawSendBuf  = rawBufB;
static volatile int rawWritePos = 0;
static volatile bool micFrameReady = false;

// --- DC tracking + gain (main loop only) ---
static float micDC = 2048.0f;
static float micGain = 16.0f;
static const float DC_ALPHA = 0.001f;

// --- Hardware timer ---
static hw_timer_t *micTimer = NULL;

void IRAM_ATTR micTimerISR() {
  if (!micStreaming || micMuted) return;

  rawWriteBuf[rawWritePos++] = (uint16_t)analogRead(MIC_PIN);

  if (rawWritePos >= MIC_FRAME_SAMPLES) {
    volatile uint16_t *tmp = rawWriteBuf;
    rawWriteBuf = rawSendBuf;
    rawSendBuf = tmp;
    rawWritePos = 0;
    micFrameReady = true;
  }
}

void setupMic() {
  analogReadResolution(12);
  analogSetPinAttenuation(MIC_PIN, ADC_ATTENDB_MAX);
  pinMode(MIC_PIN, INPUT);

  for (int i = 0; i < 10; i++) analogRead(MIC_PIN);

  long sum = 0;
  long sumSq = 0;
  const int CAL_SAMPLES = 1024;

  for (int i = 0; i < CAL_SAMPLES; i++) {
    int raw = analogRead(MIC_PIN);
    sum += raw;
    sumSq += (long)raw * raw;
    delayMicroseconds(1000000UL / MIC_SAMPLE_RATE);
  }

  micDC = (float)sum / CAL_SAMPLES;
  float meanSq = (float)sumSq / CAL_SAMPLES;
  float noiseRMS = sqrtf(meanSq - micDC * micDC);

  if (noiseRMS > 0.5f) {
    micGain = constrain(200.0f / noiseRMS, 4.0f, 64.0f);
  } else {
    micGain = 16.0f;
  }

  Serial.print("[mic] ADC — DC: ");
  Serial.print(micDC, 1);
  Serial.print("  noise: ");
  Serial.print(noiseRMS, 1);
  Serial.print("  gain: ");
  Serial.println(micGain, 1);

  micTimer = timerBegin(1000000);
  timerAttachInterrupt(micTimer, &micTimerISR);
  timerAlarm(micTimer, 1000000 / MIC_SAMPLE_RATE, true, 0);

  Serial.println("[mic] Hardware timer started at 16kHz");
}

void updateMic() {
  if (!micFrameReady) return;
  micFrameReady = false;

  for (int i = 0; i < MIC_FRAME_SAMPLES; i++) {
    float raw = (float)rawSendBuf[i];
    micDC += DC_ALPHA * (raw - micDC);
    float sample = (raw - micDC) * micGain;
    if (sample > 32767.0f) sample = 32767.0f;
    if (sample < -32767.0f) sample = -32767.0f;
    micOutBuf[i] = (int16_t)sample;
  }

  uint16_t byteLen = MIC_FRAME_SAMPLES * 2;
  uint8_t header[3];
  header[0] = MIC_FRAME_TAG;
  header[1] = (byteLen >> 8) & 0xFF;
  header[2] = byteLen & 0xFF;

  Serial.write(header, 3);
  Serial.write((const uint8_t *)micOutBuf, byteLen);
}

void micSetMuted(bool muted) {
  micMuted = muted;
  if (muted) {
    rawWritePos = 0;
    micFrameReady = false;
  }
}

#endif  // MIC_TYPE

#else  // !ENABLE_MIC

bool micStreaming = false;
void setupMic() {}
void updateMic() {}
void micSetMuted(bool muted) { (void)muted; }

#endif
