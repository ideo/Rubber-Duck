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

// ---- Hardware variant selector ----
// DUCK_VARIANT_XIAO: defined via -DDUCK_VARIANT=XIAO at build time (CMake
// reads $DUCK_VARIANT env). Default (undefined) = ducky PCB.
//
// Ducky PCB     — full-duplex I2S on a single port (shared BCLK/WS).
// Standard XIAO — split I2S: mic on port 0, speaker on port 1, separate
//                  clocks. Pin map mirrors firmware/rubber_duck_s3/Config.h
//                  with Seeed silk D-labels resolved to S3 GPIOs.

#if defined(DUCK_VARIANT_XIAO)
// ---- Standard XIAO Seeed ESP32-S3 + cobbled ICS-43434 mic + MAX98357 ----
#define AUDIO_I2S_SPLIT 1
#define I2S_PORT_MIC           0   // mic on I2S_NUM_0
#define I2S_PORT_SPK           1   // speaker on I2S_NUM_1

// Speaker (MAX98357) — XIAO labels D1/D0/D2 → GPIO 2/1/3
#define SPK_PIN_BCLK           2
#define SPK_PIN_WS             1
#define SPK_PIN_DIN            3

// Mic (ICS-43434) — XIAO labels D8/D10/D9 → GPIO 7/9/8
#define MIC_PIN_BCLK           7
#define MIC_PIN_WS             9
#define MIC_PIN_SD             8

// User button — D5 → GPIO 6. Active-low to GND with internal pull-up.
#define BUTTON_PIN             6

// No status LED on the cobbled build. Existing main.c led_* helpers are
// no-ops, so just point LED_PIN at an unused GPIO and let them compile.
#define LED_PIN                21

// Servo — D3 → GPIO 4
#define SERVO_PIN              4

#else
// ---- Ducky PCB (default) — single I2S port full-duplex ----
#define AUDIO_I2S_DUPLEX 1
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
#endif // DUCK_VARIANT_XIAO
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

// ---- Relay endpoint ----
// Duck connects to the Python relay over wss:// — TLS terminated by the
// relay host's edge (Fly.io's Let's Encrypt cert by default). The chip
// validates against the Mozilla NSS root bundle compiled in via
// CONFIG_MBEDTLS_CERTIFICATE_BUNDLE; no per-deployment cert management
// needed on the chip side.
//
// ESP-IDF v5.3+ mbedTLS 3.5+ handles Let's Encrypt's ECDSA-SHA384
// chains cleanly against Fly's edge. (We had a long-running impasse
// earlier with chip-side TLS against an ngrok+Cloudflare edge —
// MBEDTLS_ERR_SSL_INVALID_RECORD on every record-size config. Fly's
// edge is a bespoke proxy without the Cloudflare-style record-size
// quirks, so the bundle attach + default IN_CONTENT_LEN works.)
//
// Override at compile time to point at a different deployment:
//   idf.py -DRELAY_BASE_URL='\"wss://<your-fly-app>.fly.dev\"' build
#ifndef RELAY_BASE_URL
#define RELAY_BASE_URL "wss://duck-duck-print.fly.dev"
#endif

#define RELAY_DUCK_URL    RELAY_BASE_URL "/ws/duck"
#define RELAY_NOTIFY_URL  RELAY_BASE_URL "/ws/notify"

// Back-compat — older code uses RELAY_WS_URL.
#ifndef RELAY_WS_URL
#define RELAY_WS_URL RELAY_DUCK_URL
#endif
