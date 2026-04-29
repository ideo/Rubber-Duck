#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <esp_err.h>

// Initialize I2S mic (in) and DAC (out) channels. Mic is started but data
// only flows when audio_mic_enable(true) is called.
esp_err_t audio_init(void);

// Read one frame (AUDIO_FRAME_SAMPLES * sizeof(int16_t)) of mic PCM.
// Blocks up to timeout_ms. Returns bytes read, 0 on timeout.
size_t audio_mic_read(int16_t *out, size_t max_samples, int timeout_ms);

// Write a chunk of PCM to the speaker. Blocks until queued (DMA buffered).
esp_err_t audio_spk_write(const int16_t *pcm, size_t num_samples);

// Gate the mic — when speaker is talking, disable to prevent self-trigger.
void audio_mic_enable(bool on);
bool audio_mic_is_enabled(void);

// Play a short tone burst (sine wave) for audible boot/state feedback.
// freq_hz typical 600–1500. duration_ms typical 80–250.
void audio_chirp(int freq_hz, int duration_ms);

// Two-tone "chirp up" — quick happy ascending pair. Use for "ready / connected".
void audio_chirp_up(void);

// Two-tone "chirp down" — sad descending pair. Use for "error / disconnect".
void audio_chirp_down(void);
