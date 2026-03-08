// ============================================================
// Audio Bridge — USB Audio from onboard mic
// ============================================================
// Makes the Teensy appear as a USB microphone to the host Mac.
// Requires USB Type set to "Serial + MIDI + Audio" in Arduino IDE.
//
// Audio pipeline:
//   AudioInputAnalog(A0) → gain → AudioOutputUSB
//
// The Mac sees "Teensy" as an audio input device.
// speech.py auto-detects it and uses it for wake word + STT.
// ============================================================

#if ENABLE_USB_AUDIO

#include <Audio.h>

// --- Audio Objects ---
AudioInputAnalog     audioIn(MIC_PIN);       // Analog mic on A0
AudioAmplifier       audioGain;              // Adjustable gain stage
AudioOutputUSB       audioOut;               // USB Audio output to Mac
AudioAnalyzePeak     audioPeak;              // For level monitoring

// --- Audio Connections (patchcords) ---
AudioConnection      patchCord1(audioIn, 0, audioGain, 0);
AudioConnection      patchCord2(audioGain, 0, audioOut, 0);   // Left channel
AudioConnection      patchCord3(audioGain, 0, audioOut, 1);   // Right channel (mono→stereo)
AudioConnection      patchCord4(audioGain, 0, audioPeak, 0);  // Level monitor

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
