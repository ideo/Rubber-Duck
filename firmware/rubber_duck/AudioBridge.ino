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
AudioAnalyzePeak     audioPeak;              // For level monitoring

// --- Mic → USB (patchcords) ---
AudioConnection      patchCord1(audioIn, 0, audioGain, 0);
AudioConnection      patchCord2(audioGain, 0, audioOut, 0);   // Left channel
AudioConnection      patchCord3(audioGain, 0, audioOut, 1);   // Right channel (mono→stereo)
AudioConnection      patchCord4(audioGain, 0, audioPeak, 0);  // Level monitor
// usbIn → I2S mixer connections are in I2SAudio.ino

// --- Audio State ---
float    audioCurrentGain = MIC_DEFAULT_GAIN;
bool     audioMuted = false;
float    audioLevel = 0.0;
unsigned long lastLevelReport = 0;

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
  // Read audio level for monitoring
  if (audioPeak.available()) {
    audioLevel = audioPeak.read();
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

// ============================================================
// VU Meter mode (optional — shows audio level on LED bar when idle)
// ============================================================
void showVUMeter() {
  // Requires LED hardware — no-op without it
  #if !ENABLE_LED_DUCK
    return;
  #endif
}

#else

// Stubs when USB Audio is disabled
void setupAudioBridge() {}
void updateAudioBridge() {}
void setMicGain(float gain) {}
void setMicMute(bool mute) {}
float getMicLevel() { return 0.0; }
void showVUMeter() {}

#endif
