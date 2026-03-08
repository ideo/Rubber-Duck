// ============================================================
// I2S Audio — Chirp synthesis + TTS playback via MAX98357 DAC
// ============================================================
// Generates expressive chirps through I2S audio output.
// When USB Audio is enabled, also mixes in TTS audio from the Mac
// (received via AudioInputUSB defined in AudioBridge.ino).
//
// MAX98357 on Teensy 4.0 default I2S pins:
//   BCLK = 21, LRCLK = 20, DIN = 7
//
// Audio graph:
//   chirpWave ──→ mixer(ch0) ──→ i2sOut (speaker)
//   usbIn    ──→ mixer(ch1) ──╯
//
// Chirp vocabulary:
//   - Ascending sine sweep = positive sentiment (happy)
//   - Descending sine sweep = negative sentiment (sad)
//   - Sawtooth waveform = high risk (buzzy/alarmed)
//   - Frequency range maps to sentiment intensity

#if ENABLE_I2S_AUDIO

#include <Audio.h>

// --- Audio Objects ---
AudioSynthWaveform       chirpWave;
AudioOutputI2S           i2sOut;

#if ENABLE_USB_AUDIO
// --- TTS Mixer: chirps + USB audio from Mac → I2S speaker ---
AudioMixer4              i2sMixL;
AudioMixer4              i2sMixR;

// Chirp → mixer
AudioConnection          patchChirpMixL(chirpWave, 0, i2sMixL, 0);
AudioConnection          patchChirpMixR(chirpWave, 0, i2sMixR, 0);

// USB TTS → mixer (usbIn defined in AudioBridge.ino)
AudioConnection          patchTTSMixL(usbIn, 0, i2sMixL, 1);
AudioConnection          patchTTSMixR(usbIn, 1, i2sMixR, 1);

// Mixer → I2S output
AudioConnection          patchMixOutL(i2sMixL, 0, i2sOut, 0);
AudioConnection          patchMixOutR(i2sMixR, 0, i2sOut, 1);

#else
// --- Direct chirp → I2S (no USB mixing) ---
AudioConnection          patchChirpL(chirpWave, 0, i2sOut, 0);  // Left
AudioConnection          patchChirpR(chirpWave, 0, i2sOut, 1);  // Right (mono → stereo)
#endif

// --- Chirp State ---
bool     i2sChirpActive = false;
unsigned long i2sChirpStart = 0;
int      i2sChirpStartFreq = 400;
int      i2sChirpEndFreq = 600;
int      i2sChirpDuration = CHIRP_DURATION;

// ============================================================
// Setup (called from main setup())
// ============================================================
void setupI2SAudio() {
  // AudioMemory called in main setup() to avoid double-init with USB Audio

  chirpWave.begin(0.0, 440, WAVEFORM_SINE);
  chirpWave.amplitude(0.0);  // Silent until chirp

  #if ENABLE_USB_AUDIO
    // Mixer gains: chirps (ch0) + TTS from USB (ch1)
    // TTS boosted — USB audio arrives quiet; 4.5x is the sweet spot
    i2sMixL.gain(0, 1.0);   // chirps at full volume
    i2sMixL.gain(1, 4.5);   // TTS loud but clean
    i2sMixR.gain(0, 1.0);
    i2sMixR.gain(1, 4.5);
    Serial.println("[audio] I2S audio enabled (MAX98357) + USB TTS mixer (TTS gain 4.5x)");
  #else
    Serial.println("[audio] I2S audio enabled (MAX98357)");
  #endif
}

// ============================================================
// REDUCER: scores → chirp target (standalone)
// ============================================================
ChirpTarget chirpReducer(EvalScores &scores) {
  ChirpTarget target;

  float sentiment = (scores.soundness + scores.elegance + scores.creativity) / 3.0f;
  target.sentiment = sentiment;

  target.startFreq = CHIRP_BASE_FREQ + (int)(sentiment * 200);

  if (sentiment > 0) {
    target.endFreq = target.startFreq * 1.4;
  } else {
    target.endFreq = target.startFreq * 0.6;
  }

  target.buzzy = (scores.risk > 0.3);

  return target;
}

// ============================================================
// Play a chirp (called when eval arrives)
// ============================================================
void playI2SChirp(ChirpTarget &target) {
  i2sChirpActive = true;
  i2sChirpStart = millis();
  i2sChirpStartFreq = target.startFreq;
  i2sChirpEndFreq = target.endFreq;
  i2sChirpDuration = CHIRP_DURATION;

  // Select waveform: sawtooth for buzzy/risky, sine for clean
  chirpWave.begin(CHIRP_AMPLITUDE, target.startFreq,
                  target.buzzy ? WAVEFORM_SAWTOOTH : WAVEFORM_SINE);
}

// ============================================================
// Startup chirp — happy ascending tone
// ============================================================
void playStartupChirp() {
  chirpWave.begin(CHIRP_AMPLITUDE * 0.5, 400, WAVEFORM_SINE);
  delay(120);
  chirpWave.frequency(600);
  delay(120);
  chirpWave.amplitude(0.0);
}

// ============================================================
// Fixed-rate update (called from main loop)
// ============================================================
void updateI2SAudio() {
  if (!i2sChirpActive) return;

  unsigned long elapsed = millis() - i2sChirpStart;

  if (elapsed < (unsigned long)i2sChirpDuration) {
    // Sweep frequency from start to end over duration
    float t = (float)elapsed / (float)i2sChirpDuration;
    int freq = i2sChirpStartFreq + (int)((i2sChirpEndFreq - i2sChirpStartFreq) * t);
    chirpWave.frequency(freq);
  } else {
    // Chirp done — silence
    chirpWave.amplitude(0.0);
    i2sChirpActive = false;
  }
}

#else

// Stubs when I2S Audio is disabled
void setupI2SAudio() {}
ChirpTarget chirpReducer(EvalScores &scores) { return {400, 600, false, 0.0}; }
void playI2SChirp(ChirpTarget &target) {}
void playStartupChirp() {}
void updateI2SAudio() {}

#endif
