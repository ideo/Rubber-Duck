# Bambu Duck Firmware

ESP-IDF firmware for **XIAO Seeed ESP32-S3** (non-Sense). Push-to-talk client
that streams mic audio to an ElevenAgents conversational agent over WebSocket
and plays the response back through an I2S amplifier.

This is a **scaffold** — code compiles and follows the documented protocol but
will need bench tuning for I2S timing, INMP441 gain, button debounce, and echo
control once hardware is on a desk.

## Architecture

```
[INMP441 mic] ──I2S0──▶ [audio.c] ──PCM──▶ [agent.c]
                                              ↓ base64 + JSON
                                          [WebSocket]
                                              ↓
                                       [ElevenAgents]
                                       (calls Server Tools = relay)
                                              ↑
                                          [WebSocket]
                                              ↓ base64 audio events
                                          [agent.c]
                                              ↓ PCM
[MAX98357A amp + speaker] ◀──I2S1── [audio.c]
```

Note: tool calls happen entirely on ElevenLabs's side via the Server Tool
webhooks pointing at the relay. Firmware never sees `client_tool_call` and
doesn't need to. It's a dumb audio pipe.

## Hardware

| Pin (XIAO label / GPIO) | Wire to |
|---|---|
| **D0 / GPIO1** | INMP441 WS |
| **D1 / GPIO2** | INMP441 SCK |
| **D2 / GPIO3** | INMP441 SD |
| **D3 / GPIO4** | MAX98357A LRC |
| **D4 / GPIO5** | MAX98357A BCLK |
| **D5 / GPIO6** | MAX98357A DIN |
| **D9 / GPIO9** | Push-to-talk button → GND |
| 3V3 | INMP441 VDD, MAX98357A SD (shutdown high = enabled) |
| 5V (USB) | MAX98357A VIN |
| GND | INMP441 GND + L/R, MAX98357A GND |

INMP441 L/R pin → GND selects left channel; we read `I2S_STD_SLOT_LEFT`.

## One-time setup

Same ESP-IDF v5.3.x tooling as `firmware/rubber_duck_s3_uac/`. If that's already
working, skip to "Build & flash."

```bash
. ~/esp/esp-idf/export.sh
cd bambu/firmware
idf.py set-target esp32s3
```

## Provisioning credentials (NVS)

Three values live in NVS namespace `duck`:

| Key | What |
|---|---|
| `wifi_ssid` | WiFi SSID |
| `wifi_pass` | WiFi password |
| `el_api_key` | ElevenLabs API key (for signed-URL fetch) |

Easiest one-time write via the IDF's NVS partition generator. Create
`provision.csv`:

```csv
key,type,encoding,value
duck,namespace,,
wifi_ssid,data,string,YourSSID
wifi_pass,data,string,YourPassword
el_api_key,data,string,sk_xxxxxxxxxxxxxxxx
```

Generate + flash to the NVS partition (offset from `partitions.csv`):

```bash
python $IDF_PATH/components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py \
    generate provision.csv provision.bin 0x6000
esptool.py --chip esp32s3 --port /dev/cu.usbmodem* write_flash 0x9000 provision.bin
```

(0x9000 = nvs partition offset; 0x6000 = nvs partition size — both from `partitions.csv`.)

## Build & flash

The agent ID is baked at compile time so the binary knows which agent to
connect to:

```bash
idf.py -DBAMBU_DUCK_AGENT_ID=\"agent_xxxxx\" build
idf.py -p /dev/cu.usbmodem* flash monitor
```

Find your agent ID in the ElevenAgents dashboard URL when the agent is open.

## Using

1. Power on; watch the monitor — you should see `wifi: got ip:...` then `press the button to start a conversation`.
2. Hold the push-to-talk button; speak. Mic is enabled when the WebSocket session is open *and* the agent isn't currently speaking.
3. Release ends the session naturally on idle (~30s) or you can power-cycle.

## Known scaffolding gaps

These are real and tracked — work the issues, not the README:

- **Wake word.** Currently button-gated. microWakeWord integration is a separate piece. See [#27](https://github.com/ideo/Rubber-Duck/issues/27).
- **Echo / barge-in.** Mic is muted while agent is talking (`s_agent_speaking`). Crude — user can't interrupt mid-sentence. Software AEC or duplex VAD would fix.
- **Button release behavior.** Currently button-press starts a session that runs until idle/close. Press-to-start, release-to-end-turn would feel snappier.
- **OTA / config UX.** Captive-portal WiFi provisioning + cloud OTA aren't here; v0 assumes a developer with esptool.
- **TLS cert pinning.** Using IDF's CA bundle (covers ElevenLabs). If they switch CA, rebuild with the new bundle.
- **INMP441 gain.** The 24-bit-in-32-bit shift may be too quiet; bench-tune the shift amount in `audio.c:audio_mic_read`.
