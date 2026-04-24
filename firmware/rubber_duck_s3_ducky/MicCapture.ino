// ============================================================
// Mic Capture — Shared Full-Duplex I2S (Ducky Custom PCB)
// ============================================================
// The ICS-43432 I2S mic shares BCLK/LRCLK with the MAX98357
// speaker amp. The I2S RX handle is allocated by setupAudio()
// in AudioStream.ino and exported as sharedMicRxHandle.
//
// This file does NOT allocate any I2S resources — it only
// performs calibration and reads from the shared RX handle.
//
// IMPORTANT: setupAudio() MUST be called before setupMic().
//
// Data path:
//   ICS-43432 → GPIO1 → I2S RX DMA → updateMic() → serial
//
// The mic outputs 24-bit data, but the shared I2S bus runs at
// 16-bit (to match the speaker). We get the 16 MSBs, which is
// plenty of resolution for voice capture.
// ============================================================

#if ENABLE_MIC

#include "driver/i2s_std.h"
#include "driver/gpio.h"
#include <math.h>

// Shared RX handle from AudioStream.ino
extern i2s_chan_handle_t sharedMicRxHandle;

// --- Output buffer ---
static int16_t micOutBuf[MIC_FRAME_SAMPLES];

// --- State ---
bool micStreaming = false;
static bool micMuted = false;
static bool micReady = false;

// --- DC tracking + gain ---
static float micDC = 0.0f;
static float micGain = 8.0f;
static const float DC_ALPHA = 0.001f;

// ============================================================
// Setup — calibrate DC offset and noise floor
// ============================================================

void setupMic() {
  if (!sharedMicRxHandle) {
    Serial.println("[mic] ERROR: shared I2S RX handle not available — setupAudio() must run first");
    return;
  }

  // The RX channel is already allocated and enabled by setupAudio().
  // We just need to calibrate the DC offset and noise floor.

  // --- Calibrate DC offset from a few frames of silence ---
  int16_t calBuf[MIC_FRAME_SAMPLES];
  size_t calRead = 0;
  long long calSum = 0;
  int calCount = 0;

  for (int f = 0; f < 4; f++) {
    if (i2s_channel_read(sharedMicRxHandle, calBuf, sizeof(calBuf), &calRead, pdMS_TO_TICKS(100)) == ESP_OK) {
      int samplesRead = calRead / sizeof(int16_t);
      for (int i = 0; i < samplesRead; i++) {
        calSum += calBuf[i];
        calCount++;
      }
    }
  }
  micDC = (calCount > 0) ? (float)(calSum / calCount) : 0.0f;

  // --- Noise floor measurement for auto-gain ---
  float noiseSum = 0;
  if (calCount > 0) {
    if (i2s_channel_read(sharedMicRxHandle, calBuf, sizeof(calBuf), &calRead, pdMS_TO_TICKS(100)) == ESP_OK) {
      int samplesRead = calRead / sizeof(int16_t);
      for (int i = 0; i < samplesRead; i++) {
        float val = (float)calBuf[i] - micDC;
        noiseSum += val * val;
      }
      float noiseRMS = sqrtf(noiseSum / samplesRead);
      // ICS-43432 in 16-bit mode — signal range is +/-32768.
      // Noise floor is typically 50-200 LSBs. Speech at 30cm is 5-20x noise.
      // Target: speech peaks at ~50% of int16 range (16384).
      if (noiseRMS > 1.0f) {
        micGain = constrain(8192.0f / (noiseRMS * 10.0f), 1.0f, 64.0f);
      } else {
        micGain = 8.0f;  // Safe default
      }
      Serial.printf("[mic] I2S cal — DC: %.0f  noise: %.1f  gain: %.2f\n",
                    micDC, noiseRMS, micGain);
    }
  }

  micReady = true;
  Serial.println("[mic] ICS-43432 ready (shared full-duplex I2S on GPIO1)");
}

// ============================================================
// Update — read mic data and stream to widget
// ============================================================

void updateMic() {
  if (!micStreaming || micMuted || !micReady || !sharedMicRxHandle) return;

  // Read 16-bit mono samples from the shared RX channel
  size_t bytesRead = 0;
  size_t bytesNeeded = MIC_FRAME_SAMPLES * sizeof(int16_t);

  esp_err_t err = i2s_channel_read(sharedMicRxHandle, micOutBuf, bytesNeeded, &bytesRead, pdMS_TO_TICKS(50));
  if (err != ESP_OK || bytesRead < bytesNeeded) return;

  // DC removal + gain
  for (int i = 0; i < MIC_FRAME_SAMPLES; i++) {
    float raw = (float)micOutBuf[i];
    micDC += DC_ALPHA * (raw - micDC);
    float sample = (raw - micDC) * micGain;
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

#else  // !ENABLE_MIC

bool micStreaming = false;
void setupMic() {}
void updateMic() {}
void micSetMuted(bool muted) { (void)muted; }

#endif
