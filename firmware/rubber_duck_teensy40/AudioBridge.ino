// ============================================================
// Audio Bridge — Bidirectional USB Audio
// ============================================================
// Makes the Teensy appear as a USB audio device to the host Mac:
//   OUT (mic):  AudioInputAnalog(A0) → gain → AudioOutputUSB
//   IN  (TTS):  AudioInputUSB → mixed with chirps → I2S speaker
//
// Requires USB Type "Serial + MIDI + Audio" in Arduino IDE.
// The AudioInputUSB (usbIn) is wired to the I2S mixer in I2SAudio.ino.
// ============================================================

#if ENABLE_USB_AUDIO

#include <Audio.h>

// --- USB Audio Objects ---
AudioInputAnalog     audioIn(MIC_PIN);       // Analog mic on A0
AudioAmplifier       audioGain;              // Adjustable gain stage
AudioOutputUSB       audioOut;               // Mic → Mac (USB output)
AudioInputUSB        usbIn;                  // Mac → Teensy (USB input, for TTS)
AudioAnalyzePeak     audioPeak;              // Mic level monitoring
AudioAnalyzePeak     usbPeak;               // USB TTS level monitoring (for talking animation)

// --- Mic → USB (patchcords) ---
AudioConnection      patchCord1(audioIn, 0, audioGain, 0);
AudioConnection      patchCord2(audioGain, 0, audioOut, 0);   // Left channel
AudioConnection      patchCord3(audioGain, 0, audioOut, 1);   // Right channel (mono→stereo)
AudioConnection      patchCord4(audioGain, 0, audioPeak, 0);  // Mic level monitor
AudioConnection      patchCord5(usbIn, 0, usbPeak, 0);       // USB TTS level monitor
// usbIn → I2S mixer connections are in I2SAudio.ino

// --- Audio State ---
float    audioCurrentGain = MIC_DEFAULT_GAIN;
bool     audioMuted = false;
float    audioLevel = 0.0;
unsigned long lastLevelReport = 0;

// --- TTS Detection State ---
bool     ttsActive = false;           // True while USB audio (TTS) is playing
float    usbAudioLevel = 0.0;        // Current USB audio peak level
unsigned long ttsLastAbove = 0;       // Last time USB level exceeded threshold
unsigned long ttsLastRetarget = 0;    // Last time we retargeted ambient for talking

// ============================================================
// Setup (called from main setup())
// ============================================================
void setupAudioBridge() {
  // AudioMemory called in main setup() to avoid double-init with I2S Audio

  audioGain.gain(audioCurrentGain);
  Serial.println("[audio] USB Audio bridge enabled (mic on A" + String(MIC_PIN - A0) + ")");
  Serial.println("[audio] Gain: " + String(audioCurrentGain));
}

// ============================================================
// Update (called from main loop())
// ============================================================
void updateAudioBridge() {
  // Read mic audio level for monitoring
  if (audioPeak.available()) {
    audioLevel = audioPeak.read();
  }

  // Read USB audio level for TTS detection
  if (usbPeak.available()) {
    usbAudioLevel = usbPeak.read();
  }

  unsigned long now = millis();

  // TTS detection with hysteresis: quick on, slow off
  if (usbAudioLevel > TTS_DETECT_THRESHOLD) {
    ttsLastAbove = now;
    if (!ttsActive) {
      ttsActive = true;
    }
  } else if (ttsActive && (now - ttsLastAbove) > TTS_SILENCE_TIMEOUT) {
    ttsActive = false;
  }

  // Talking head animation: retarget ambient at rapid intervals while speaking
  if (ttsActive && !i2sChirpActive && (now - ttsLastRetarget) > TTS_RETARGET_MS) {
    ambientTargetOffset = ((float)random(-100, 101) / 100.0f) * TTS_HOP_RANGE;
    ambientVelocity = 0;
    ambientSpringActive = false;  // Use lerp for smooth talking motion
    ttsLastRetarget = now;
  }
}

// ============================================================
// Controls (called from serial commands)
// ============================================================
void setMicGain(float gain) {
  audioCurrentGain = constrain(gain, 0.0, 10.0);
  audioGain.gain(audioMuted ? 0.0 : audioCurrentGain);
  Serial.println("[audio] Gain set to " + String(audioCurrentGain));
}

void setMicMute(bool mute) {
  audioMuted = mute;
  audioGain.gain(audioMuted ? 0.0 : audioCurrentGain);
  Serial.println(audioMuted ? "[audio] Muted" : "[audio] Unmuted");
}

float getMicLevel() {
  return audioLevel;
}

#else

// Stubs when USB Audio is disabled
bool  ttsActive = false;
float usbAudioLevel = 0.0;
void setupAudioBridge() {}
void updateAudioBridge() {}
void setMicGain(float gain) {}
void setMicMute(bool mute) {}
float getMicLevel() { return 0.0; }

#endif
