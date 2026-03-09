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
//   chirpWave ──→ chirpFilter(bandpass) ──→ mixer(ch0) ──→ i2sOut (speaker)
//   usbIn    ─────────────────────────────→ mixer(ch1) ──╯
//
// Chirp vocabulary:
//   - Ascending sine sweep = positive sentiment (happy)
//   - Descending sine sweep = negative sentiment (sad)
//   - Sawtooth waveform = high risk (buzzy/alarmed)
//   - Frequency range maps to sentiment intensity

#if ENABLE_I2S_AUDIO

#include <Audio.h>

// --- Audio Objects ---
AudioSynthWaveform       chirpWave;     // Main chirp oscillator
AudioFilterStateVariable chirpFilter;   // Bandpass filter for quack formant
AudioOutputI2S           i2sOut;

// chirpWave → bandpass filter (output 1 = bandpass)
AudioConnection          patchToFilter(chirpWave, 0, chirpFilter, 0);

#if ENABLE_USB_AUDIO
// --- TTS Mixer: filtered chirp + USB audio → I2S speaker ---
AudioMixer4              i2sMixL;
AudioMixer4              i2sMixR;

// Filtered chirp → mixer ch0
AudioConnection          patchChirpMixL(chirpFilter, 1, i2sMixL, 0);  // output 1 = bandpass
AudioConnection          patchChirpMixR(chirpFilter, 1, i2sMixR, 0);

// USB TTS → mixer ch1 (usbIn defined in AudioBridge.ino)
AudioConnection          patchTTSMixL(usbIn, 0, i2sMixL, 1);
AudioConnection          patchTTSMixR(usbIn, 1, i2sMixR, 1);

// Mixer → I2S output
AudioConnection          patchMixOutL(i2sMixL, 0, i2sOut, 0);
AudioConnection          patchMixOutR(i2sMixR, 0, i2sOut, 1);

#else
// --- Filtered chirp → I2S (no USB) ---
AudioConnection          patchChirpL(chirpFilter, 1, i2sOut, 0);  // bandpass → left
AudioConnection          patchChirpR(chirpFilter, 1, i2sOut, 1);  // bandpass → right
#endif

// --- Chirp-Servo Coupling ---
float    chirpServoOffset = 0.0;   // Additive head kick during whistle
bool     i2sIsWhistle = false;     // Track whether current chirp is a whistle

// --- Chirp State ---
bool     i2sChirpActive = false;
unsigned long i2sChirpStart = 0;
int      i2sChirpStartFreq = 400;
int      i2sChirpEndFreq = 600;
int      i2sChirpDuration = CHIRP_DURATION;

// --- Filter envelope state ---
float    i2sFilterStartFreq = 350.0;   // "ooo" — closed, round
float    i2sFilterEndFreq = 1800.0;    // "ehhhh" — open, clear
float    i2sFilterRiseRate = 6.0;      // How fast filter opens
bool     i2sFilterTrackHarmonic = false; // true = filter tracks oscillator (whistle), false = envelope

// --- Double-chirp state (for "uh-uh" pattern) ---
bool     i2sDoubleChirp = false;
int      i2sChirp2StartFreq = 300;
int      i2sChirp2PeakFreq = 500;   // Hill peak — note 2 rises here then falls
int      i2sChirp2EndFreq = 180;
int      i2sChirp2Duration = 350;
int      i2sGapDuration = 60;  // silence between the two chirps

// ============================================================
// Helpers
// ============================================================

/// Hill envelope: 40% rise, 60% fall. t in [0,1] → [0,1]
static float hillEnvelope(float t) {
  if (t < 0.4f) return t / 0.4f;
  return 1.0f - (t - 0.4f) / 0.6f;
}

/// Common chirp activation — resets state and starts playback
static void startChirp(int startFreq, int waveform) {
  chirpWave.begin(CHIRP_AMPLITUDE, startFreq, waveform);
  chirpFilter.frequency(i2sFilterStartFreq);
  i2sChirpActive = true;
  i2sChirpStart = millis();
  chirpServoOffset = 0.0;
}

// ============================================================
// Setup (called from main setup())
// ============================================================
void setupI2SAudio() {
  // AudioMemory called in main setup() to avoid double-init with USB Audio

  chirpWave.begin(0.0, 440, WAVEFORM_SINE);
  chirpWave.amplitude(0.0);  // Silent until chirp

  // Bandpass filter: quack formant — resonance gives nasal character
  chirpFilter.frequency(1800);  // Will be modulated by envelope
  chirpFilter.resonance(5.0);   // Moderate Q for nasal peak (0.7-5.0)

  #if ENABLE_USB_AUDIO
    // Mixer gains: chirp (ch0) + TTS (ch1)
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

  target.buzzy = true;  // All sawtooth for now — filter needs harmonics to shape
  target.doubleChirp = (sentiment < -0.4) || (sentiment > 0.75);  // two-note: uh-uh or whistle (rare)

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
  // Note 1 duration: whistle gets a longer lead-in, uh-uh stays snappy
  if (target.doubleChirp && target.sentiment > 0) {
    i2sChirpDuration = 500;   // Whistle: half speed test (was 250)
  } else if (target.doubleChirp) {
    i2sChirpDuration = 200;   // Uh-uh: quick
  } else {
    i2sChirpDuration = CHIRP_DURATION;
  }

  // Double-chirp setup — same structure, different freq profiles
  //   Positive (whistle): "wh-WHEWWW!" — bright, soaring
  //   Negative (uh-uh):   "uh, uh-UH-hh" — grumbly, drops low
  i2sDoubleChirp = target.doubleChirp;
  if (target.doubleChirp) {
    if (target.sentiment > 0) {
      // Whistle note 1: G4→C5
      i2sChirpEndFreq = target.startFreq * 1.68;
    } else {
      // Uh-uh note 1: moderate rise
      i2sChirpEndFreq = target.startFreq * 1.5;
    }

    if (target.sentiment > 0) {
      // Whistle: G4→E5→G4 hill
      i2sChirp2StartFreq = target.startFreq * 1.0;     // G4
      i2sChirp2PeakFreq = target.startFreq * 1.68;     // E5
      i2sChirp2EndFreq = target.startFreq * 1.0;        // G4
      i2sChirp2Duration = 1200;  // Half speed test (was 600)
      i2sGapDuration = 120;     // Half speed test (was 40) — servo needs time to dip
    } else {
      // Uh-uh: grumbly, drops well below
      i2sChirp2StartFreq = target.startFreq * 0.9;    // Start near original
      i2sChirp2PeakFreq = target.startFreq * 1.4;     // Rise higher than note 1
      i2sChirp2EndFreq = target.startFreq * 0.45;     // Drop well below start
      i2sChirp2Duration = 400;
      i2sGapDuration = 50;
    }
  }

  // Whistle servo coupling: time-based kick on top of expression angle
  // Servo stays at expression target — offset adds head-tilt boost during whistle
  i2sIsWhistle = target.doubleChirp && (target.sentiment > 0);
  if (i2sIsWhistle) {
    // Redistribute expression into 10-45° range so kick has room
    float norm = servoTargetAngle / (float)SERVO_RANGE;  // 0..1
    servoTargetAngle = 10.0f + norm * 35.0f;             // 10..45
  }

  // Filter envelope: "ooo" → "ehhhh" (closed → open)
  // Positive chirps: opens wider and brighter
  // Negative chirps: stays more closed/grumbly
  if (target.sentiment > 0) {
    i2sFilterStartFreq = 300.0;    // Round start
    i2sFilterEndFreq = 2200.0;     // Opens bright
    i2sFilterRiseRate = 5.0;       // Leisurely open
  } else {
    i2sFilterStartFreq = 250.0;    // Darker start
    i2sFilterEndFreq = 1200.0;     // Doesn't open as much
    i2sFilterRiseRate = 8.0;       // Faster — snappier quack
  }

  // Note 2 filter: whistle tracks harmonics, everything else uses envelope
  i2sFilterTrackHarmonic = i2sIsWhistle;

  startChirp(target.startFreq, WAVEFORM_SAWTOOTH);
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

  // Filter envelope: opens from "ooo" to "ehhhh"
  float elapsedSec = (float)elapsed / 1000.0;
  float filterEnv = 1.0 - exp(-elapsedSec * i2sFilterRiseRate);  // 0→1 rising
  float filterFreq = i2sFilterStartFreq + (i2sFilterEndFreq - i2sFilterStartFreq) * filterEnv;
  chirpFilter.frequency(filterFreq);

  if (elapsed < (unsigned long)i2sChirpDuration) {
    // First chirp (or only chirp): linear sweep
    float t = (float)elapsed / (float)i2sChirpDuration;
    int freq = i2sChirpStartFreq + (int)((i2sChirpEndFreq - i2sChirpStartFreq) * t);
    chirpWave.frequency(freq);

    // Whistle servo: note 1 — up then down within the note
    if (i2sIsWhistle) {
      chirpServoOffset = hillEnvelope(t) * WHISTLE_SERVO_KICK;
    }

  }
  else if (i2sDoubleChirp) {
    unsigned long phase2Start = i2sChirpDuration + i2sGapDuration;
    unsigned long phase2End = phase2Start + i2sChirp2Duration;

    if (elapsed < (unsigned long)phase2Start) {
      // Gap — silence between chirps, servo rests
      chirpWave.amplitude(0.0);
    }
    else if (elapsed < (unsigned long)phase2End) {
      // Second chirp: hill shape — rise to peak then fall
      chirpWave.amplitude(CHIRP_AMPLITUDE);

      // Compute pitch hill: 40% rise, 60% fall
      float t = (float)(elapsed - phase2Start) / (float)i2sChirp2Duration;
      float h = hillEnvelope(t);
      int freq;
      if (t < 0.4) {
        freq = i2sChirp2StartFreq + (int)((i2sChirp2PeakFreq - i2sChirp2StartFreq) * h);
      } else {
        float tFall = (t - 0.4) / 0.6;
        freq = i2sChirp2PeakFreq + (int)((i2sChirp2EndFreq - i2sChirp2PeakFreq) * tFall);
      }
      chirpWave.frequency(freq);

      // Whistle servo: second kick — hill up then down
      if (i2sIsWhistle) {
        chirpServoOffset = h * WHISTLE_SERVO_KICK;
      }

      // Filter envelope for note 2
      if (i2sFilterTrackHarmonic) {
        // Whistle: filter tracks 3rd harmonic — stays locked to pitch
        chirpFilter.frequency((float)freq * 3.0);
      } else {
        // Uh-uh / permission: monotonic envelope (ooo → ehhhh)
        float note2FilterStart = (i2sChirp2StartFreq > i2sFilterStartFreq)
          ? (float)i2sChirp2StartFreq * 0.9
          : i2sFilterStartFreq;
        float note2Sec = (float)(elapsed - phase2Start) / 1000.0;
        float fEnv2 = 1.0 - exp(-note2Sec * i2sFilterRiseRate);
        chirpFilter.frequency(note2FilterStart + (i2sFilterEndFreq - note2FilterStart) * fEnv2);
      }
    }
    else {
      // Done
      chirpWave.amplitude(0.0);
      chirpServoOffset = 0.0;
      i2sChirpActive = false;
      i2sDoubleChirp = false;
      i2sIsWhistle = false;
    }
  }
  else {
    // Single chirp done — silence
    chirpWave.amplitude(0.0);
    chirpServoOffset = 0.0;
    i2sChirpActive = false;
  }
}

// ============================================================
// Permission chirp — "uh-oh" two-note descending quack
// ============================================================
// Same quacky sawtooth + bandpass as expressions, but with
// a distinct two-note descending pattern. Uses the normal
// "ooo→ehhhh" filter envelope — it IS the duck's voice.

void playPermissionChirp() {
  // Randomize root note: 220-280Hz range, note 2 is ~70% of note 1
  int root = 220 + random(60);           // 220-280Hz
  int lower = (int)(root * 0.70);        // ~154-196Hz

  // Note 1: higher quack (the "uh") — snappy, open filter
  i2sChirpStartFreq = root;
  i2sChirpEndFreq = root;
  i2sChirpDuration = 120;     // Quick

  // Note 2: lower quack (the "oh") — closes filter back down
  i2sDoubleChirp = true;
  i2sChirp2StartFreq = lower;
  i2sChirp2PeakFreq = lower;
  i2sChirp2EndFreq = lower;
  i2sChirp2Duration = 150 + random(80);   // 150-230ms — varies each nag
  i2sGapDuration = 40 + random(100);     // 40-140ms — tight "uhoh" to drawn out "uh... oh"

  // Filter: starts open (ehhhh), note 2 envelope closes it back (envelope, not harmonic)
  i2sFilterStartFreq = 1400.0;
  i2sFilterEndFreq = 300.0;
  i2sFilterRiseRate = 6.0;
  i2sFilterTrackHarmonic = false;
  i2sIsWhistle = false;

  startChirp(root, WAVEFORM_SAWTOOTH);

  // Snap to a random non-center position: ±[NAG_MIN..NAG_MAX] degrees
  float nagOffset = PERMISSION_NAG_MIN +
    ((float)random(0, 101) / 100.0f) * (PERMISSION_NAG_MAX - PERMISSION_NAG_MIN);
  if (random(2) == 0) nagOffset = -nagOffset;
  ambientTargetOffset = nagOffset;
  ambientSpringActive = true;  // Nag kicks use spring for overshoot
  float nagDir = (nagOffset > ambientCurrentOffset) ? 1.0f : -1.0f;
  ambientVelocity += nagDir * PERMISSION_NAG_KICK;
  servoOscillationAmp = 4.0;
  servoOscillationPhase = 0.0;

  Serial.println("[perm] uh-oh chirp");
}

#else

// Stubs when I2S Audio is disabled
float chirpServoOffset = 0.0;
void setupI2SAudio() {}
ChirpTarget chirpReducer(EvalScores &scores) { return {400, 600, false, 0.0, false}; }
void playI2SChirp(ChirpTarget &target) {}
void playStartupChirp() {}
void updateI2SAudio() {}
void playPermissionChirp() {}

#endif
