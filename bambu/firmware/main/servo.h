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

// Mark the duck as having just had user interaction (double-tap, short
// press, long press). Used to drive the idle-hop taper: shortly after
// interaction the duck is "alert" (frequent ambient hops); long after
// it goes "drowsy" then "quiet" with progressively wider hop intervals.
// Doesn't fire any motion itself — just resets the taper clock so the
// next scheduled hop window is full-alertness again. Call from main.c
// at user-wake points; printer-event notifications deliberately skip
// this so the duck doesn't perk up just because something automatic
// happened on the printer.
void servo_note_interaction(void);

// Movement modes — captive-portal-selectable, NVS-persisted.
//   ALWAYS              — alert all day. Quiet 9pm–6am local time
//                         when SNTP + TZ are known; otherwise alert
//                         around the clock.
//   TAPER               — alert (0–2min) → settling (2–10min) →
//                         drowsy (10min–1hr) → dormant (1hr+). Default.
//   INTERACTION_ONLY    — alert for 2min after a wake; dormant
//                         otherwise. For the "duck shouldn't move
//                         unless I'm looking at it" preference.
typedef enum {
    SERVO_MOVE_ALWAYS = 0,
    SERVO_MOVE_TAPER  = 1,
    SERVO_MOVE_INTERACTION_ONLY = 2,
} servo_move_mode_t;

void servo_set_move_mode(servo_move_mode_t mode);
servo_move_mode_t servo_get_move_mode(void);

// TZ offset (minutes east of UTC, e.g. -300 for US Eastern Standard,
// -240 for US Eastern Daylight) used by SERVO_MOVE_ALWAYS for quiet-
// hours detection. Captive portal exposes a small dropdown of common
// zones; default 0 (UTC) means quiet hours fire on UTC clock until set.
void servo_set_tz_offset_min(int16_t off_min);
int16_t servo_get_tz_offset_min(void);
