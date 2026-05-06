#pragma once
#include <stdbool.h>
#include <stdint.h>

// Spoken onboarding phrases (#34). Pre-recorded Opus blobs embedded
// in flash, decoded on-chip via micro-opus, written to the same I2S
// TX path as agent voice + chirps. One phrase plays at a time;
// concurrent calls block via internal mutex.
//
// Phrase texts live as plaintext side-files in main/phrases/ for grep-
// friendly review (welcome.txt etc.). Re-generate the .opus blobs
// from those texts with bambu/firmware/scripts/gen_phrases.sh.

typedef enum {
    PHRASE_TAP_TO_START = 0,   // boot, no WiFi creds
    PHRASE_WIFI_UP,            // wizard's AP is live, captive portal ready
    PHRASE_WIFI_CONNECTED,     // existing-creds path, STA reconnected
    PHRASE_COUNT,              // sentinel
} phrase_id_t;

// PHRASES_ENABLED is set by CMakeLists when all .opus blobs are
// present (HAS_PHRASES). Until the operator runs scripts/gen_phrases.py
// the .opus files don't exist; the macro stays unset and these
// functions become no-op stubs so callers can invoke them
// unconditionally — boot/wizard code stays clean either way.
#ifdef PHRASES_ENABLED

// Block-and-play: decode the phrase, push PCM into I2S TX, return
// when the audio has been queued (not necessarily fully played out).
// Returns true if a clip was found + decode succeeded; false if the
// id is unknown or the decoder errored. Safe to call from any task.
//
// Static embedded phrases only. Dynamic / runtime-Opus playback was
// briefly tried for the post-onboarding "I'm listening for X and Y"
// confirmation; that announcement now rides the existing notify
// pipeline and gets spoken by the agent itself, so no second runtime
// decoder path is needed on chip.
bool phrase_play(phrase_id_t id);

// True if a phrase is currently mid-decode/playback. Lets callers
// (e.g. the wizard's polling loop) avoid stomping on a long phrase
// with chirps or other audio. Cheap read.
bool phrase_active(void);

#else  // PHRASES_ENABLED

#include <stdbool.h>
static inline bool phrase_play(phrase_id_t id) { (void)id; return false; }
static inline bool phrase_active(void) { return false; }

#endif  // PHRASES_ENABLED
