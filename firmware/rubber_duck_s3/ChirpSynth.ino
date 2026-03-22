// ============================================================
// Chirp Synthesizer (ESP32-C3 Duck)
// ============================================================
// Software synth that generates the duck's quack/chirp sounds.
// Replaces the Teensy Audio library with direct sample math:
//   Sawtooth oscillator → Chamberlin SVF bandpass → I2S
// The SVF matches Teensy's AudioFilterStateVariable exactly
// (2x oversampled Chamberlin, same freq/resonance mapping).
//
// Generates samples into a scratch buffer, then writes them
// to the ring buffer (same path as TTS audio streaming).
//
// Chirp vocabulary (same as Teensy duck):
//   Expression: swept sawtooth + opening bandpass = "quack"
//   Whistle: two-note ascending + harmonic-tracking filter
//   Uh-uh: two-note descending + closing filter
//   Permission: randomized "uh-oh" two-note descending
//   Startup: simple sine 400→600 Hz

#if ENABLE_AUDIO

#include <math.h>

// ============================================================
// Chamberlin State Variable Filter (matches Teensy AudioFilterStateVariable)
// ============================================================
// 2x oversampled SVF — identical algorithm to the Teensy Audio library.
// First iteration uses average of current + previous input (interpolation),
// second iteration uses current input directly.

static float svfLow = 0.0f;       // lowpass state
static float svfBand = 0.0f;      // bandpass state
static float svfPrevInput = 0.0f; // previous input for 2x oversampling
static float svfF = 0.0f;         // frequency coefficient: sin(pi * freq / (2 * sampleRate))
static float svfDamp = 0.0f;      // damping: 1.0 / Q

static void svfReset() {
  svfLow = svfBand = svfPrevInput = 0.0f;
}

/// Set filter frequency and Q (resonance)
static void svfSetFrequency(float centerFreq, float Q, float sampleRate) {
  // Clamp frequency to safe range (same as Teensy: max = sampleRate/2.5)
  if (centerFreq < 20.0f) centerFreq = 20.0f;
  float maxFreq = sampleRate / 2.5f;
  if (centerFreq > maxFreq) centerFreq = maxFreq;

  // Clamp Q to Teensy range
  if (Q < 0.7f) Q = 0.7f;
  if (Q > 5.0f) Q = 5.0f;

  svfF = sinf(M_PI * centerFreq / (sampleRate * 2.0f));
  svfDamp = 1.0f / Q;
}

/// Process one sample through the SVF, return bandpass output
/// (2x oversampled, matching Teensy AudioFilterStateVariable)
static inline float svfProcess(float input) {
  float high;

  // Iteration 1: interpolated input (average of current + previous)
  float mid = (input + svfPrevInput) * 0.5f;
  svfLow  += svfF * svfBand;
  high     = mid - svfLow - svfDamp * svfBand;
  svfBand += svfF * high;

  // Iteration 2: current input directly
  svfLow  += svfF * svfBand;
  high     = input - svfLow - svfDamp * svfBand;
  svfBand += svfF * high;

  svfPrevInput = input;
  return svfBand;  // bandpass output
}

// ============================================================
// Sawtooth Oscillator
// ============================================================

static float sawPhase = 0.0f;

/// Generate one sawtooth sample at given frequency, range [-1, 1]
static inline float sawSample(float freq, float sampleRate) {
  sawPhase += freq / sampleRate;
  if (sawPhase >= 1.0f) sawPhase -= 1.0f;
  return 2.0f * sawPhase - 1.0f;  // [-1, 1]
}

/// Generate one sine sample
static inline float sineSample(float freq, float sampleRate) {
  sawPhase += freq / sampleRate;
  if (sawPhase >= 1.0f) sawPhase -= 1.0f;
  return sinf(2.0f * M_PI * sawPhase);
}

// ============================================================
// Chirp State Machine
// ============================================================

float chirpServoOffset = 0.0f;

static bool     chirpActive = false;
static bool     chirpIsSine = false;  // true = sine, false = sawtooth
static unsigned long chirpStartMs = 0;

// Note 1
static int      chirpStartFreq = 400;
static int      chirpEndFreq = 600;
static int      chirpDuration = CHIRP_DURATION;

// Filter envelope
static float    filterStartFreq = 300.0f;
static float    filterEndFreq = 2200.0f;
static float    filterRiseRate = 5.0f;
static bool     filterTrackHarmonic = false;

// Double chirp (note 2)
static bool     doubleChirp = false;
static int      chirp2StartFreq = 300;
static int      chirp2PeakFreq = 500;
static int      chirp2EndFreq = 180;
static int      chirp2Duration = 350;
static int      gapDuration = 60;

// Whistle
static bool     isWhistle = false;

// Sample generation tracking
static unsigned long lastChirpGenMs = 0;
static uint32_t chirpSamplesGenerated = 0;

// Scratch buffer for generated samples
#define CHIRP_CHUNK_SAMPLES 64
static int16_t chirpScratch[CHIRP_CHUNK_SAMPLES];

// ============================================================
// Helpers
// ============================================================

/// Hill envelope: 40% rise, 60% fall. t in [0,1] → [0,1]
static float hillEnvelope(float t) {
  if (t < 0.4f) return t / 0.4f;
  return 1.0f - (t - 0.4f) / 0.6f;
}

/// Start chirp playback — resets oscillator and filter state
static void startChirpInternal(int startFreq, bool useSine) {
  audioChirpBegin();  // Enable ring buffer → I2S path for chirp
  sawPhase = 0.0f;
  svfReset();
  svfSetFrequency(filterStartFreq, 5.0f, CHIRP_SAMPLE_RATE);
  chirpActive = true;
  chirpIsSine = useSine;
  chirpStartMs = millis();
  chirpSamplesGenerated = 0;
  chirpServoOffset = 0.0f;
  lastChirpGenMs = millis();
}

// ============================================================
// Reducer: scores → chirp target
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

  target.buzzy = true;  // sawtooth — filter needs harmonics
  target.doubleChirp = (sentiment < -0.4f) || (sentiment > 0.75f);

  return target;
}

// ============================================================
// Play expression chirp
// ============================================================

void playChirp(ChirpTarget &target) {
  chirpStartFreq = target.startFreq;
  chirpEndFreq = target.endFreq;

  // Note 1 duration
  if (target.doubleChirp && target.sentiment > 0) {
    chirpDuration = 500;    // Whistle: longer lead-in
  } else if (target.doubleChirp) {
    chirpDuration = 200;    // Uh-uh: snappy
  } else {
    chirpDuration = CHIRP_DURATION;
  }

  // Double chirp setup
  doubleChirp = target.doubleChirp;
  if (target.doubleChirp) {
    if (target.sentiment > 0) {
      chirpEndFreq = target.startFreq * 1.68;
      chirp2StartFreq = target.startFreq;
      chirp2PeakFreq = target.startFreq * 1.68;
      chirp2EndFreq = target.startFreq;
      chirp2Duration = 1200;
      gapDuration = 120;
    } else {
      chirpEndFreq = target.startFreq * 1.5;
      chirp2StartFreq = target.startFreq * 0.9;
      chirp2PeakFreq = target.startFreq * 1.4;
      chirp2EndFreq = target.startFreq * 0.45;
      chirp2Duration = 400;
      gapDuration = 50;
    }
  }

  // Whistle servo coupling
  isWhistle = target.doubleChirp && (target.sentiment > 0);
  if (isWhistle) {
    float norm = servoTargetAngle / (float)SERVO_RANGE;
    servoTargetAngle = 10.0f + norm * 35.0f;
  }

  // Filter envelope
  if (target.sentiment > 0) {
    filterStartFreq = 300.0f;
    filterEndFreq = 2200.0f;
    filterRiseRate = 5.0f;
  } else {
    filterStartFreq = 250.0f;
    filterEndFreq = 1200.0f;
    filterRiseRate = 8.0f;
  }
  filterTrackHarmonic = isWhistle;

  // Reset eval timer so expression decay doesn't fight servo target
  lastEvalTime = millis();

  startChirpInternal(target.startFreq, false);
}

// ============================================================
// Startup chirp — ascending sine 400→600 Hz
// ============================================================

void playStartupChirp() {
  chirpStartFreq = 400;
  chirpEndFreq = 400;  // constant for note 1
  chirpDuration = 120;

  doubleChirp = true;
  chirp2StartFreq = 600;
  chirp2PeakFreq = 600;
  chirp2EndFreq = 600;
  chirp2Duration = 120;
  gapDuration = 30;

  isWhistle = false;
  filterStartFreq = 800.0f;
  filterEndFreq = 3000.0f;
  filterRiseRate = 10.0f;
  filterTrackHarmonic = false;

  startChirpInternal(400, true);  // sine for startup
}

// ============================================================
// Permission chirp — "uh-oh" two-note descending
// ============================================================

void playPermissionChirp() {
  int root = 220 + random(60);
  int lower = (int)(root * 0.70f);

  chirpStartFreq = root;
  chirpEndFreq = root;
  chirpDuration = 120;

  doubleChirp = true;
  chirp2StartFreq = lower;
  chirp2PeakFreq = lower;
  chirp2EndFreq = lower;
  chirp2Duration = 150 + random(80);
  gapDuration = 40 + random(100);

  // Filter: starts open, closes back
  filterStartFreq = 1400.0f;
  filterEndFreq = 300.0f;
  filterRiseRate = 6.0f;
  filterTrackHarmonic = false;
  isWhistle = false;

  startChirpInternal(root, false);  // sawtooth

  // Servo nag kick — snap to random offset with spring overshoot (matches Teensy)
  float nagOffset = PERMISSION_NAG_MIN +
    ((float)random(0, 101) / 100.0f) * (PERMISSION_NAG_MAX - PERMISSION_NAG_MIN);
  if (random(2) == 0) nagOffset = -nagOffset;
  ambientTargetOffset = nagOffset;
  ambientSpringActive = true;  // Nag kicks use spring for overshoot
  float nagDir = (nagOffset > ambientCurrentOffset) ? 1.0f : -1.0f;
  ambientVelocity += nagDir * PERMISSION_NAG_KICK;
  servoOscillationAmp = 4.0f;
  servoOscillationPhase = 0.0f;

}

// ============================================================
// Generate chirp samples and push to ring buffer
// ============================================================
// Called from loop(). Generates a chunk of samples based on
// elapsed time, runs them through the biquad, and writes to
// the ring buffer. audioFeedI2S() then plays them out.

void updateChirp() {
  if (!chirpActive) return;

  unsigned long now = millis();
  unsigned long elapsed = now - chirpStartMs;

  // Calculate total chirp duration
  unsigned long totalDuration = chirpDuration;
  if (doubleChirp) {
    totalDuration = chirpDuration + gapDuration + chirp2Duration;
  }

  // Done?
  if (elapsed > totalDuration + 50) {  // +50ms safety
    chirpActive = false;
    chirpServoOffset = 0.0f;
    isWhistle = false;
    doubleChirp = false;
    audioChirpEnd();
    Serial.println("K");  // Machine-readable chirp-complete signal for widget
    return;
  }

  // Generate all samples needed to stay caught up with real-time.
  // Loop in chunks — single 64-sample pass can't keep up if loop() > 4ms.
  while (true) {
  uint32_t targetSamples = (uint32_t)((float)elapsed / 1000.0f * CHIRP_SAMPLE_RATE);
  uint32_t toGenerate = 0;
  if (targetSamples > chirpSamplesGenerated) {
    toGenerate = targetSamples - chirpSamplesGenerated;
  }
  if (toGenerate == 0) break;
  if (toGenerate > CHIRP_CHUNK_SAMPLES) toGenerate = CHIRP_CHUNK_SAMPLES;

  // Generate samples
  for (uint32_t i = 0; i < toGenerate; i++) {
    uint32_t sampleIdx = chirpSamplesGenerated + i;
    float sampleTimeMs = (float)sampleIdx / CHIRP_SAMPLE_RATE * 1000.0f;

    float sample = 0.0f;
    float freq = 0.0f;
    bool silent = false;

    if (sampleTimeMs < chirpDuration) {
      // Note 1: linear sweep
      float t = sampleTimeMs / (float)chirpDuration;
      freq = chirpStartFreq + (chirpEndFreq - chirpStartFreq) * t;

      // Whistle servo
      if (isWhistle) {
        chirpServoOffset = hillEnvelope(t) * WHISTLE_SERVO_KICK;
      }
    }
    else if (doubleChirp) {
      float phase2Start = chirpDuration + gapDuration;
      float phase2End = phase2Start + chirp2Duration;

      if (sampleTimeMs < phase2Start) {
        // Gap — silence
        silent = true;
      }
      else if (sampleTimeMs < phase2End) {
        // Note 2: hill shape
        float t = (sampleTimeMs - phase2Start) / (float)chirp2Duration;
        float h = hillEnvelope(t);

        if (t < 0.4f) {
          freq = chirp2StartFreq + (chirp2PeakFreq - chirp2StartFreq) * h;
        } else {
          float tFall = (t - 0.4f) / 0.6f;
          freq = chirp2PeakFreq + (chirp2EndFreq - chirp2PeakFreq) * tFall;
        }

        // Whistle servo note 2
        if (isWhistle) {
          chirpServoOffset = h * WHISTLE_SERVO_KICK;
        }

        // Filter for note 2
        if (filterTrackHarmonic) {
          svfSetFrequency(freq * 3.0f, 5.0f, CHIRP_SAMPLE_RATE);
        } else {
          float note2Sec = (sampleTimeMs - phase2Start) / 1000.0f;
          float fEnv2 = 1.0f - expf(-note2Sec * filterRiseRate);
          float note2FilterStart = (chirp2StartFreq > filterStartFreq)
            ? (float)chirp2StartFreq * 0.9f
            : filterStartFreq;
          svfSetFrequency(
            note2FilterStart + (filterEndFreq - note2FilterStart) * fEnv2,
            5.0f, CHIRP_SAMPLE_RATE
          );
        }
      } else {
        silent = true;
      }
    } else {
      silent = true;
    }

    if (silent || freq < 20.0f) {
      chirpScratch[i] = 0;
    } else {
      // Update filter envelope (note 1 uses global envelope)
      if (sampleTimeMs < chirpDuration) {
        float elSec = sampleTimeMs / 1000.0f;
        float fEnv = 1.0f - expf(-elSec * filterRiseRate);
        float fFreq = filterStartFreq + (filterEndFreq - filterStartFreq) * fEnv;
        svfSetFrequency(fFreq, 5.0f, CHIRP_SAMPLE_RATE);
      }

      // Generate oscillator sample
      if (chirpIsSine) {
        sample = sineSample(freq, CHIRP_SAMPLE_RATE);
      } else {
        sample = sawSample(freq, CHIRP_SAMPLE_RATE);
      }

      // Run through bandpass filter
      sample = svfProcess(sample);

      // Scale to 16-bit — sine (startup) at half, all sawtooth chirps 2x
      // volumeScale (0.0–1.0) from widget VOL command
      float amp = chirpIsSine ? (CHIRP_AMPLITUDE * 0.5f) : (CHIRP_AMPLITUDE * 2.0f);
      sample *= amp * volumeScale * 32767.0f;
      if (sample > 32767.0f) sample = 32767.0f;
      if (sample < -32767.0f) sample = -32767.0f;

      chirpScratch[i] = (int16_t)sample;
    }
  }

  chirpSamplesGenerated += toGenerate;

  // Write to ring buffer (same as TTS audio path)
  audioStreamWrite((const uint8_t *)chirpScratch, toGenerate * 2);

  } // end while(true) — loop until caught up with real-time
}

#else

// Stubs
float chirpServoOffset = 0.0f;
ChirpTarget chirpReducer(EvalScores &scores) { return {400, 600, false, 0.0f, false}; }
void playChirp(ChirpTarget &target) {}
void playStartupChirp() {}
void playPermissionChirp() {}
void updateChirp() {}

#endif // ENABLE_AUDIO
