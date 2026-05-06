#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include <esp_err.h>

// Initialize I2S mic (in) and DAC (out) channels. Mic is started but data
// only flows when audio_mic_enable(true) is called.
esp_err_t audio_init(void);

// Read one frame (AUDIO_FRAME_SAMPLES * sizeof(int16_t)) of mic PCM.
// Blocks up to timeout_ms. Returns sample count, 0 on timeout.
// Applies DC removal + auto-gain (calibrated in audio_init), and respects
// the audio_mic_enable() gate — returns 0 when disabled.
size_t audio_mic_read(int16_t *out, size_t max_samples, int timeout_ms);

// Like audio_mic_read but bypasses the enable-gate AND skips the DC/gain
// transform. Returns raw int16 samples straight from I2S. Used by tap-to-
// wake's transient detector (wake.c), which wants clean amplitude without
// the auto-gain skewing the threshold.
//
// Internally serialized against audio_mic_read by a mutex, so concurrent
// callers (tap monitor + session mic_task) don't race on i2s_channel_read.
size_t audio_mic_read_raw(int16_t *out, size_t max_samples, int timeout_ms);

// Write a chunk of PCM to the speaker. Blocks until queued (DMA buffered).
// Internally extends the audio_speaker_active() window — every write keeps
// the speaker-busy gate alive for chunk_duration + AMP_DECAY_MS afterward.
esp_err_t audio_spk_write(const int16_t *pcm, size_t num_samples);

// True if the speaker amp is producing (or recently produced) audio. Driven
// off the most recent audio_spk_write — the deadline extends with each
// write, then expires AMP_DECAY_MS after the last write so the amp/cone
// ringing tail is also covered. Used by wake.c (tap-to-wake) as a single
// dumb gate that catches all chip-to-self audio (chirps, agent speech,
// session boundaries) without needing to know about each code path.
bool audio_speaker_active(void);

// Gate the mic — when speaker is talking, disable to prevent self-trigger.
void audio_mic_enable(bool on);
bool audio_mic_is_enabled(void);

// Play a short tone burst for audible boot/state feedback. Goes
// through the same sawtooth+SVF synth as chirp_up/chirp_down so the
// duck's character is consistent across all chirps. freq_hz typical
// 250–1500; duration_ms typical 80–250.
void audio_chirp(int freq_hz, int duration_ms);

// Single-note pitch bend through the chirp synth — sawtooth +
// bandpass filter, frequency sweeps linearly from start to end across
// the duration. Sounds more like a duck "wuh" than two stepped tones
// when start != end. For a bend that ascends roughly a fifth, try
// (320, 480, 200ms). For a flat note, use the same value for both.
void audio_chirp_bend(int start_hz, int end_hz, int duration_ms);

// Two-tone "chirp up" — quick happy ascending pair. Use for "ready / connected".
void audio_chirp_up(void);

// Two-tone "chirp down" — neutral descending pair. Use for normal
// session end / "letting go". NOT for errors — those have their own
// distinct voice below so the user can tell "you hung up" from "the
// duck or the printer just hit a problem."
void audio_chirp_down(void);

// "Uh-oh" — randomized two-note descending pair with a closing filter.
// Reserved for **chip-internal** error states (wifi connect failed,
// wizard failed, etc.) — anything where the duck itself hit a snag.
// The slight per-call variation makes repeated errors not feel
// mechanical.
void audio_chirp_uh_oh(void);

// "Uh-uh" — deterministic, terser two-note descending. Reserved for
// **printer-side** fault notifications (failed prints, HMS errors)
// pushed from the relay. Sounds dismissive / "nope" — distinct from
// uh-oh's concerned "something's gone wrong on my end" timbre, so a
// listener can tell at a glance whether the duck or the printer is
// the source of the problem.
void audio_chirp_uh_uh(void);

// Cycle the speaker volume forward through the preset list (Loud →
// Normal → Quiet → Whisper → Mute → wraps back to Loud). Persists
// the new step to NVS so it survives reboot. Plays an audible
// announce chirp at the new level — including on the Mute step,
// where the chirp briefly uses the Quiet level so the user hears
// "you reached mute" confirmation rather than silence-on-press.
//
// Bound to the back button's short press in main.c. Long press is
// re-onboard, double-tap is wake-for-conversation.
void audio_cycle_volume(void);
