// Bambu Duck — pinout and runtime config.
// XIAO Seeed ESP32-S3 (non-Sense). External I2S mic + I2S amp wired to D0-D5.
#pragma once

// ---- Audio format (locked by ElevenAgents protocol) ----
#define AUDIO_SAMPLE_RATE_HZ   16000
#define AUDIO_CHANNELS         1
#define AUDIO_BITS_PER_SAMPLE  16

// Frame size: 20ms @ 16kHz = 320 samples = 640 bytes. Tradeoff between
// WebSocket overhead (smaller = more frames) and first-byte latency
// (larger = stutter). 20ms is the documented sweet spot.
#define AUDIO_FRAME_SAMPLES    320

// Pin assignments match the main rubber_duck_s3 firmware so existing wiring
// works without re-soldering. ICS-43434 mic, MAX98357A amp.

// ---- I2S microphone (ICS-43434) on I2S_NUM_0 ----
// XIAO pins: D8=GPIO7 (SCK), D9=GPIO8 (SD), D10=GPIO9 (WS).
// Wire L/R→GND (left channel), VDD→3V3, GND→GND.
#define MIC_I2S_PORT           0
#define MIC_PIN_SCK            7   // D8 — bit clock
#define MIC_PIN_SD             8   // D9 — serial data in
#define MIC_PIN_WS             9   // D10 — word select / LRCL

// ---- I2S amplifier (MAX98357A) on I2S_NUM_1 ----
// XIAO pins: D0=GPIO1 (WS/LRC), D1=GPIO2 (BCLK), D2=GPIO3 (DIN).
// Wire GAIN→float (12dB default), SD→3V3, VIN→5V (USB), GND→GND.
#define SPK_I2S_PORT           1
#define SPK_PIN_LRC            1   // D0 — LRC / WS
#define SPK_PIN_BCLK           2   // D1 — bit clock
#define SPK_PIN_DIN            3   // D2 — DIN / DOUT

// ---- Push-to-talk button ----
// Wire button between D5 (GPIO6) and GND. Internal pull-up enabled.
// Hold to talk; release ends user turn (sends end-of-speech to agent).
#define BUTTON_PIN             6   // D5

// ---- Status LED ----
// XIAO ESP32-S3 has a user-controllable LED on GPIO21 (active low).
#define LED_PIN                21

// ---- ElevenAgents ----
// Set BAMBU_DUCK_AGENT_ID at build time:
//   idf.py build -DBAMBU_DUCK_AGENT_ID=\"agent_xxxxx\"
// API key is loaded from NVS at runtime, not compiled in. See README.
#ifndef BAMBU_DUCK_AGENT_ID
#define BAMBU_DUCK_AGENT_ID    "REPLACE_ME"
#endif

#define ELEVENLABS_API_HOST    "api.elevenlabs.io"
#define SIGNED_URL_PATH_FMT    "/v1/convai/conversation/get-signed-url?agent_id=%s"
