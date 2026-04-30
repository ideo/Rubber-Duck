#pragma once
#include <stdbool.h>
#include <stdint.h>

#include <esp_err.h>

// Initialize servo PWM on SERVO_PIN (LEDC 50Hz / 14-bit) and spawn a task
// that runs the animation update loop at SERVO_UPDATE_MS cadence.
esp_err_t servo_init(void);

// Tell the servo system whether the agent is currently producing speech.
// While true, the head retargets every TTS_RETARGET_MS and the beak amplitude
// follows the spk envelope (servo_feed_audio_envelope).
void servo_set_speaking(bool speaking);

// Feed a chunk of speaker PCM (mono int16). The servo task uses peak
// amplitude of recent samples to drive beak movement amount.
void servo_feed_audio_envelope(const int16_t *pcm, size_t samples);
