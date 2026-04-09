// ============================================================
// Stored Audio Playback (ESP32 Duck)
// ============================================================
// Plays pre-rendered phrases from flash memory through the I2S
// ring buffer. Uses the same audio path as serial streaming.
//
// Phrases are stored as 16kHz 16-bit signed mono PCM in
// StoredPhrases.h (PROGMEM const arrays).
//
// Usage:
//   storedAudioPlay(PHRASE_AWAKE, PHRASE_AWAKE_LEN);
//   storedAudioPlayQuip();  // random button quip

#if ENABLE_AUDIO

#include "StoredPhrases.h"

// Defined in ServoControl.ino — tracks which demo preset was last triggered
extern int demoStep;

// ============================================================
// Playback State
// ============================================================

static const int16_t* storedPtr     = NULL;
static uint32_t       storedLen     = 0;
static uint32_t       storedPos     = 0;
static bool           storedPlaying = false;
static unsigned long  storedStartAt = 0;    // millis() when playback was requested
static bool           storedWaiting = false; // waiting for post-chirp gap

// ============================================================
// Public API
// ============================================================

/// Start playing a stored phrase. Interrupts any current playback.
/// Does NOT play if serial audio streaming is active.
void storedAudioPlay(const int16_t* phrase, uint32_t sampleCount) {
  // Don't stomp on serial TTS or active chirps
  if (streaming || draining || chirpPlaying) {
    Serial.printf("[stored] Skipped — busy (stream=%d drain=%d chirp=%d)\n", streaming, draining, chirpPlaying);
    return;
  }

  storedPtr = phrase;
  storedLen = sampleCount;
  storedPos = 0;
  storedPlaying = true;
  storedWaiting = true;
  storedStartAt = millis();

  // Make sure I2S is at 16kHz (phrase sample rate)
  audioSetSampleRate(16000);
  Serial.printf("[stored] Playing %lu samples (%.1fs)\n", (unsigned long)sampleCount, sampleCount / 16000.0f);
}

/// Stop current stored phrase playback.
void storedAudioStop() {
  storedPlaying = false;
  storedPtr = NULL;
  storedLen = 0;
  storedPos = 0;
}

/// Play the quip matching the current demo step.
/// Called after triggerDemoPreset() — demoStep has already advanced.
void storedAudioPlayQuip() {
  // demoStep was incremented by triggerDemoPreset before we get here,
  // so the quip for preset N is at index demoStep-1.
  // On dead level (demoStep wrapped to 0), don't play.
  int idx = demoStep - 1;
  if (idx < 0 || idx >= PHRASE_COUNT_QUIPS) return;
  Serial.printf("[stored] Quip #%d for demo %d\n", idx, demoStep);
  storedAudioPlay(QUIP_TABLE[idx], QUIP_LEN_TABLE[idx]);
}

/// Returns true if a stored phrase is currently playing.
bool isStoredAudioPlaying() {
  return storedPlaying;
}

// ============================================================
// Feed Loop — call from main loop alongside audioFeedI2S()
// ============================================================
// Pushes stored PCM samples into the ring buffer in chunks.
// The existing audioFeedI2S() handles ring buffer → I2S DMA.

void storedAudioFeed() {
  if (!storedPlaying || !storedPtr) return;

  // Wait 500ms after play request (gap after chirp)
  if (storedWaiting) {
    if ((millis() - storedStartAt) < 500) return;
    storedWaiting = false;
    ringClear();  // Clear any leftover chirp data
  }

  // Don't feed if serial streaming or chirp took over
  if (streaming || chirpPlaying) {
    storedAudioStop();
    return;
  }

  // Feed as much as possible per call — keep ring buffer full
  uint32_t remaining = storedLen - storedPos;
  if (remaining == 0) {
    // Don't stop immediately — let ring buffer drain first
    if (ringAvailable() == 0) {
      storedAudioStop();
      Serial.println("[stored] Playback complete");
    }
    return;
  }

  uint32_t free = ringFree();
  if (free == 0) return;

  uint32_t toWrite = min(remaining, free);
  // Cap per call to avoid starving loop() — but generous (2048 not 256)
  toWrite = min(toWrite, (uint32_t)2048);

  // Read from PROGMEM and write to ring buffer
  int16_t chunk[2048];
  for (uint32_t i = 0; i < toWrite; i++) {
    chunk[i] = pgm_read_word(&storedPtr[storedPos + i]);
  }

  uint32_t written = ringWrite(chunk, toWrite);
  storedPos += written;

  // Keep I2S draining while we feed
  if (!prefilled && ringAvailable() >= 512) {
    prefilled = true;
  }
}

#else

// Stubs when audio is disabled
void storedAudioPlay(const int16_t*, uint32_t) {}
void storedAudioStop() {}
void storedAudioPlayQuip() {}
bool isStoredAudioPlaying() { return false; }
void storedAudioFeed() {}

#endif
