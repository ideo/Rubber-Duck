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

// Pin assignments match firmware/rubber_duck_s3_ducky/Config.h — the custom
// "ducky" PCB with WROOM-1 (built-in PCB antenna), ICS-43432 mic, MAX98357
// amp, WS2812B status LED. Mic and speaker share a single I2S bus in
// full-duplex mode (BCLK + WS shared, only data pins differ).

// ---- Single I2S port for both mic + speaker (full-duplex) ----
#define I2S_PORT               0

// Shared clock + word-select pins
#define I2S_PIN_BCLK           13  // GPIO13 — shared bit clock
#define I2S_PIN_WS             12  // GPIO12 — shared word select / LRCLK

// Speaker data out (TX) — to MAX98357 DIN
#define SPK_PIN_DIN            7   // GPIO7

// Mic data in (RX) — from ICS-43432 SD
#define MIC_PIN_SD             1   // GPIO1

// ---- Push-to-talk button ----
// User button labeled S3 on the PCB silk. Active-low to GND; internal pull-up.
#define BUTTON_PIN             2   // GPIO2

// ---- Status LED ----
// PCB has a WS2812B NeoPixel on GPIO38 (via BSS138 level shifter). Driving
// it requires the RMT or SPI peripheral; not yet wired in this firmware.
// LED_PIN is kept as a no-op so existing main.c led_init/on/off compile.
#define LED_PIN                38

// ---- Servo (head/beak) ----
// LEDC PWM at 50Hz, 14-bit. Pulse range ~500µs–2400µs maps to 0°–180°.
// Constants match firmware/rubber_duck_s3_ducky/Config.h verbatim so the
// "feel" of the head animation is identical to the existing ducks.
#define SERVO_PIN              3
#define SERVO_CENTER           90
#define SERVO_RANGE            80
#define SERVO_MIN              (SERVO_CENTER - SERVO_RANGE)
#define SERVO_MAX              (SERVO_CENTER + SERVO_RANGE)
#define SERVO_UPDATE_MS        20

#define SPRING_K               0.06f
#define SPRING_DAMPING         0.82f

#define IDLE_HOP_RANGE         30.0f
#define IDLE_HOP_MIN_MS        4000
#define IDLE_HOP_MAX_MS        15000
#define IDLE_CLUSTER_DELTA     30.0f
#define IDLE_CLUSTER_MIN_DELTA 10.0f
#define IDLE_CLUSTER_GAP_MIN   500
#define IDLE_CLUSTER_GAP_MAX   1500

#define AMBIENT_SPRING_K       0.03f
#define AMBIENT_SPRING_DAMPING 0.88f
#define AMBIENT_LERP_RATE      0.25f

#define TTS_RETARGET_MS        300
#define TTS_HOP_RANGE          8.0f

// Speech-driven beak amplitude — drives a sine oscillation during agent
// speech, modulated by audio envelope. RANGE = max degrees of movement at
// full envelope. (Original duck had no beak swing — this is bambu-specific.)
#define BEAK_RANGE             20.0f
#define BEAK_ATTACK            0.45f
#define BEAK_RELEASE           0.10f

// ---- Local relay (path C-light) ----
// Duck connects to our Python relay over plain TCP via ngrok TCP tunnel,
// raw binary PCM. Relay handles ElevenAgents JSON+base64+TLS upstream.
// (ngrok's HTTPS edge speaks HTTP/2 which esp_websocket_client doesn't, so
// we use a TCP tunnel for plain-byte forwarding. See bambu/STATE.md.)
#ifndef RELAY_BASE_URL
#define RELAY_BASE_URL "ws://2.tcp.ngrok.io:20554"
#endif

#define RELAY_DUCK_URL    RELAY_BASE_URL "/ws/duck"
#define RELAY_NOTIFY_URL  RELAY_BASE_URL "/ws/notify"

// Back-compat — older code uses RELAY_WS_URL.
#ifndef RELAY_WS_URL
#define RELAY_WS_URL RELAY_DUCK_URL
#endif
