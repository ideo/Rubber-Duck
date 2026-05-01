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

// Comedic "shake-off" animation. Used on tap-to-wake (#37): the duck
// reacts to being tapped with a 50° kick, counter-swing to -30°, small
// settle to +15°, return to center. Total ~200ms. Blocks the calling
// task for the duration; spawn it in its own task if you don't want to
// block. Suppresses idle-hop scheduling for the duration so background
// jitter doesn't fight the choreography.
void servo_shake_off(void);
