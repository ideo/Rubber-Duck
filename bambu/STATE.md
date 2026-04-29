# Bambu Duck — State of the Effort

Living document. Updated as the work moves. As of 2026-04-29.

## Goal

Standalone ESP32-S3 duck on the desk next to a Bambu printer. Push-to-talk
voice conversation with an ElevenAgents (formerly Convai) agent. Agent has
Server Tool webhooks pointing at our Python relay, which holds an MQTT
subscription to the printer.

## What works

- ✅ **Relay** ([bambu/relay/](relay/)) — FastAPI service with three Server
  Tool endpoints (`/tools/printer_state`, `/tools/temperatures`,
  `/tools/print_history`). Verified against `MOCK=1` walking through a fake
  Benchy print. Auth via `X-Relay-Secret` header.
- ✅ **Browser-side conversation** — ElevenAgents agent + relay via ngrok →
  duck persona "on point," dry tone, transcripts translated correctly
  (e.g. "two twenty" not "220"), tool calls fire and produce real answers.
  Verified end-to-end before any firmware existed.
- ✅ **Agent config in version control** ([bambu/agent/](agent/)) —
  `system_prompt.md`, `tools.json`, `voice.md`. Dashboard is the runtime,
  these are the audit trail.
- ✅ **Firmware boots, joins WiFi, opens WebSocket** to ElevenAgents — chip
  is XIAO Seeed ESP32-S3 (non-Sense), pinout matches `firmware/rubber_duck_s3/`
  so existing duck wiring works.
- ✅ **Mic captures real audio** — clean speech reaches the server, gets
  transcribed by ASR. Confirmed by downloading the conversation audio from
  ElevenLabs and comparing.
- ✅ **Agent first message arrives** — `[agent_response] Yeah?` log fires
  shortly after WS opens. Round-trip works at the JSON level.

## ⚠️ KEY FINDING — 2026-04-29: degraded mic on OG XIAO

After hours of firmware debugging trying to fix garbled mic audio, we did
a hardware A/B by plugging in a second XIAO ESP32-S3. The "spare" duck we
expected to be problematic turned out to have **markedly cleaner mic audio**
than the OG duck we'd been debugging on. The OG duck's ICS-43434 mic is
likely partially fried / degraded — explains why every software fix
plateaued at "garbled but transcribable."

**Implication:** the path C firmware + relay architecture may have been
*correct* the whole time. We were chasing software bugs when hardware was
the limiting factor. Will retest on a known-good PCB next.

**Lesson:** when audio quality is the symptom, A/B against known-good
hardware EARLY, not after exhausting the software-fix budget.

## What's currently broken (active debug)

- ❌ **Audio playback from agent** — the duck speaker doesn't produce the
  agent's voice. Two layered causes identified:
  1. **WS message fragmentation**: ElevenAgents 250 ms PCM events come back
     as ~10–14 KB JSON. esp_websocket_client splits these into ~1.4 KB TCP
     fragments delivered as separate `WEBSOCKET_EVENT_DATA` events. My
     handler parsed each fragment individually → "rx malformed JSON". Fix
     in code (not yet flashed): accumulate fragments using
     `payload_offset` / `payload_len`, parse only when complete.
  2. **`audio_spk_write` blocks the WS receive task** when called directly
     from the event callback. Fix in code: ring buffer (StreamBuffer) +
     dedicated `spk_task` drain.
- ❌ **"Audio duration mismatch" warning** on the ElevenLabs conversation
  page — server's complaint that mic audio arrival drifts from declared
  duration. Confirmed by downloading the audio: it's choppy/garbled even
  though the firmware sends in-order PCM. Fixes layered:
  - Decoupled `mic_task` (DMA-paced) from `ws_send_task` (slow base64+TLS)
    via 16 KB stream buffer
  - Bumped chunk aggregation to 240 ms (12 frames) to match ElevenLabs SDK
    cadence
  - Rejected partial reads in `audio_mic_read`
- ⚠️ **Brownout at 240 MHz** — bumping CPU from 160 → 240 MHz caused the
  chip to reset when the speaker fired during button-press chirp. Reverted
  to 160 MHz. Add a decoupling cap or move off USB power before retrying.

## Hardware

- **Chip**: XIAO Seeed ESP32-S3 (non-Sense). External IPEX antenna **required**
  — the WROOM-1U module has no PCB antenna. WiFi auth-without-association
  symptom = unplugged antenna.
- **Mic**: ICS-43434 I2S MEMS, SEL→GND for left channel. 24-bit data in 32-bit slot.
- **Amp**: MAX98357A I2S DAC + amp driving a small speaker.
- **Pins** (matches `firmware/rubber_duck_s3/Config.h`):

| Pin (XIAO / GPIO) | Wired to |
|---|---|
| D0 / GPIO1 | MAX98357A LRC |
| D1 / GPIO2 | MAX98357A BCLK |
| D2 / GPIO3 | MAX98357A DIN |
| D5 / GPIO6 | Push-to-talk button → GND |
| D8 / GPIO7 | ICS-43434 SCK |
| D9 / GPIO8 | ICS-43434 SD |
| D10 / GPIO9 | ICS-43434 WS |

## Architecture

```
[INMP441/ICS-43434]──I2S0──[audio_mic_read]
                              │ (mute gate when agent speaks)
                              ▼
                        [s_mic_stream] 16KB ring
                              ▼
                        [ws_send_task]  base64 + JSON + TLS
                              ▼
                        [WebSocket TX]
                              │
                          ElevenAgents
                              │
                        [WebSocket RX] (fragmented; reassembled)
                              ▼
                        [handle_event] ─ pongs, transcripts, audio events
                              ▼ on `audio` events
                        [s_spk_stream] 32KB ring
                              ▼
                          [spk_task]
                              ▼
                        [MAX98357A]──I2S1──[speaker]
```

Mute timer task watches `s_last_audio_ms`; re-enables mic 500 ms after the
last `audio` event so the user can talk back.

## Findings log (chronological highlights)

**2026-04-28 (early)** — Set up relay + Convai agent in browser. Worked end-to-end via mock Benchy printer.

**2026-04-29** — Wiring confirmed; flash + provisioning works. Antenna **not plugged in** caused WiFi to auth but never associate. Plugging antenna fixed.

**2026-04-29** — `data_bit_width=16, slot_bit_width=32` mismatch made mic DMA stall after the first buffer (1 frame in 5 sec instead of ~250). Setting `data_bit_width=32` to match slot fixed it.

**2026-04-29** — Captured mic-as-WAV via base64-over-UART for diagnosis. Sounded "grain-sampler" garbled. Three independent agent reviews fingered UART overflow at 45 KB/s through a 11.5 KB/s default ring as the **diagnostic itself** being broken — not the actual ElevenAgents path. Removed the diagnostic. **Future diagnostics should stream over WebSocket to a Mac listener, not printf-over-UART** ([memory note](../../../.claude/projects/-Users-dderuntz-ideo-com-Documents-GitHub-Rubber-Duck/memory/feedback_diag_via_ws.md)).

**2026-04-29** — Discovered ElevenLabs's "Audio duration mismatch" warning on the conversation review page. Confirmed actual server-bound audio is also bad (downloaded conversation MP3, chaotic chopping). Pivoted to fixing real cadence issues, not just the diagnostic.

**2026-04-29** — Three-agent architecture review (existing-projects, pure-QC, missing-pieces) converged on a fix list: (1) ring buffer + spk_task, (2) mic decoupling, (3) mute timer, (4) reject partial reads, (5) bigger WS buffer, (6) protocol verification.

**2026-04-29** — Protocol verification agent: `agent_output_audio_format` and `user_input_audio_format` are **dashboard-only settings**, not WS-overridable. My `tts.*` / `.asr.*` overrides were silently ignored. Both already set correctly (`pcm_16000`) on user's agent.

**2026-04-29** — 240 MHz CPU caused brownout reset on button-press chirp. Reverted to 160 MHz.

**2026-04-29** — Watchdog firing on `mic_task` because partial-read rejection caused tight loop. Added `vTaskDelay(1)` on n=0.

**2026-04-29** — `WEBSOCKET_EVENT_DATA` events are TCP fragments, not full WS messages. Need `payload_offset`/`payload_len` reassembly. **(In code, not yet flashed.)**

## Decision: path C (relay-as-WS-proxy)

After hitting the ceiling of direct-from-S3 raw-PCM-over-TLS-WS on
ElevenAgents (audio-duration-mismatch warning still firing even after WIFI_PS_NONE,
240ms chunks, cJSON skip, etc.), the team committed to extending [bambu/relay/](relay/)
into a local WS proxy. **No new third-party — the Python service we already
have grows naturally into this role.**

### Why direct mode hit a ceiling (evidence summary)

- 256 kbps raw PCM over TLS WS from ESP32-S3 @ 160 MHz: ~60ms/chunk behind
  realtime even after every documented optimization
- ElevenLabs's "audio duration mismatch" warning fires whenever cumulative
  arrival time drifts from declared audio duration — a chip's TLS jitter is
  enough to trigger it
- Every battle-tested ESP32 → realtime-audio-API project surveyed
  (ElatoAI, openai_demo, wheatley-ai) uses either: edge proxy, Opus
  encoding, or WebRTC. None ship raw PCM directly from chip to public WS

### C-light (chosen for v1)

Duck speaks plain WebSocket to our local relay over LAN. **No TLS, no JSON,
no base64 on the chip — just raw int16 PCM bytes.** Relay holds the slow
ElevenAgents WS upstream and does all the JSON+base64+TLS work in Python.

```
[duck] ──ws://lan-relay:8088/ws──→ [relay]
       ◀──── raw int16 PCM ─────►        │
                                          │ ElevenAgents WS+JSON+b64+TLS
                                          ▼
                                    [ElevenAgents]
```

Wire protocol (duck ↔ relay), simple binary frames:
- **Duck → relay**: WS binary frames, raw int16 LE PCM @ 16kHz mono. No
  framing — every binary message is N samples of audio.
- **Relay → duck**: WS binary frames, same format (decoded ElevenAgents
  audio). Plus optional JSON text frames for control (`{"type":"interruption"}`,
  etc.).

Firmware changes:
- Drop cJSON, base64, mbedtls TLS — all moot
- Replace `send_audio_chunk` with `esp_websocket_client_send_bin(pcm, bytes)`
- Replace `play_audio_event` JSON parsing with: binary frame → push to ring buffer
- Drop fragment reassembly (LAN binary frames don't fragment meaningfully)
- Keep: I2S mic + spk pipeline, ring buffers, mute timer, button gate

Relay changes (~150 lines):
- New FastAPI WebSocket endpoint `/ws/duck`
- On duck connect: fetch ElevenAgents signed URL, open upstream WS
- Receive binary from duck → base64 + JSON wrap → forward to ElevenAgents
- Receive JSON+audio from ElevenAgents → base64 decode → binary frame to duck
- Pong handling, error handling, agent-id config

Estimated effort: 1 evening. Eliminates 90% of the firmware bugs we've
been chasing.

### C-full (deferred, post-v1)

Same architecture as C-light but with **Opus encoding/decoding on the chip**.
Duck encodes mic audio as 12 kbps Opus before sending; relay decodes Opus →
PCM before forwarding to ElevenAgents. Reverse for downstream. URAM already
has Opus dependency working on this chip class.

When to bother:
- LAN bandwidth becomes a real constraint (multiple ducks, mesh, etc.)
- We want to support battery-powered ducks (Opus is far cheaper to
  transmit than raw PCM)
- We're building proper compression for storage / replay anyway

For one duck on USB power, C-light is sufficient. C-full is a worthwhile
optimization once architecture is settled.

### What we keep from this exhausting debug session

- ✅ `bambu/relay/` Python service (will grow the proxy endpoint)
- ✅ `bambu/agent/` Convai agent config (unchanged)
- ✅ Firmware: I2S mic + spk pipeline, ring buffers, mute timer, button
  gate, WiFi+NVS provisioning
- ✅ Hardware wiring (matches `firmware/rubber_duck_s3/` so future ducks
  drop in)
- ✅ Memory note: no UART for high-rate diagnostics — use WS to a Mac
- ❌ Direct-mode ElevenAgents JSON+base64+fragment-reassembly path —
  remove once C-light proves out

## Other open questions

- Will fragment reassembly + cadence fixes (already in code, not yet
  flashed) be enough to skip the proxy and just iterate? Worth one more
  test before adopting (C).
- Echo / barge-in: current naive mic-mute-during-speech is fine for v0.
  Real AEC (esp_afe_sr) is post-MVP.
- Brownout mitigation: USB power decoupling cap, or move off USB?

## Tracking

- Branch: `bambu`
- Issues: filtered by `bambu` label — [#22–#28](https://github.com/ideo/Rubber-Duck/labels/bambu)
- Persona/system_prompt + tool schemas: [bambu/agent/](agent/)
- Relay: [bambu/relay/](relay/) — `MOCK=1` works end-to-end without a real printer
- Firmware: [bambu/firmware/](firmware/) — ESP-IDF v5.3.4, XIAO ESP32-S3
- ngrok URL is ephemeral; restart per session
