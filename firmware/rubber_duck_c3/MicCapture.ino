// ============================================================
// Mic Capture (ESP32 Duck)
// ============================================================
// Two modes:
//   1. S3 Sense: Built-in PDM mic via new IDF I2S PDM driver
//      GPIO42 CLK, GPIO41 DATA. Hardware PDM→PCM conversion.
//   2. C3 / external: Analog mic via ADC + hardware timer.
//
// Streams 16-bit PCM at 16kHz back to the widget over serial.
// ============================================================

#if ENABLE_MIC

#if defined(CONFIG_IDF_TARGET_ESP32S3)
  #define USE_PDM_MIC 1
#else
  #define USE_PDM_MIC 0
#endif

// --- Output buffer ---
static int16_t micOutBuf[MIC_FRAME_SAMPLES];

// --- State ---
bool micStreaming = false;
static bool micMuted = false;

// ============================================================
// Path 1: S3 Sense PDM mic via new IDF I2S PDM driver
// ============================================================
#if USE_PDM_MIC

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
// Path 2: Analog ADC mic via hardware timer (C3 / external)
// ============================================================
#else

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

#endif  // USE_PDM_MIC

#else  // !ENABLE_MIC

bool micStreaming = false;
void setupMic() {}
void updateMic() {}
void micSetMuted(bool muted) { (void)muted; }

#endif
