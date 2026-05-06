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

## 🟢🟢🟢 2026-05-02 — APSTA wizard: phone-only end-to-end onboarding

**The setup story is now zero-touch from a stranger's phone.** Plug in a fresh duck, press the button, join `DuckDuckDuck-XXXX`, fill one form, type the email-2FA code, you're done. No reboot mid-flow, no `duck.local` hop, no chip-side TLS, no command line. Phone never disconnects from the duck's AP during the whole wizard. ~76 seconds button-press to logged in (validated end-to-end).

This is the architecture the user had been pointing at since iteration B was scoped (issue #42). It took a long detour through a chip-side HTTPS path that we couldn't get working against ngrok's edge — `mbedtls_ssl_handshake returned -0x7280` (`MBEDTLS_ERR_SSL_INVALID_RECORD`) reliably, against every config combination tried (IN_CONTENT_LEN bumped to 16384, DYNAMIC_BUFFER toggled, HARDWARE_AES toggled, TLS 1.2 forced). Two research agents and a lot of tokens later, the right answer turned out to be: **don't do TLS on the chip.** The chip has a working plain-WebSocket channel to the relay (via ngrok TCP tunnel); the relay has a working Python httpx client (TLS just works in CPython). Forward credentials chip→relay over the WebSocket, relay does the cloud TLS, return result over the same WebSocket.

### Architecture

- **`provision.c`**: APSTA mode from the start. AP comes up first (`DuckDuckDuck-XXXX`, captive-portal DNS hijack pops the form on iOS/Android). When user submits, the chip switches to APSTA — AP stays up, STA connects to home WiFi in parallel. A worker task waits for STA got_ip, brings up the long-lived `/ws/notify` connection, and calls `bambu_login_via_ws()`. State machine drives page rendering: `COLLECT_WIFI` → `CONNECTING_WIFI` → `LOGGING_IN` → `NEED_2FA` (if applicable) → `DONE`. Browser auto-refreshes during transient states via `<meta http-equiv="refresh">` — no JavaScript, works in every captive-portal in-app browser.
- **`agent.c`**: gained `bambu_login_via_ws(email, password, code, user_id, timeout_ms)`. Sends `{"type":"bambu_login",...}` over the existing notify WS, blocks on a binary semaphore until the relay's `{"type":"bambu_login_result",...}` message arrives. Idempotent `notify_task_start`. Plus `notify_ws_is_connected()` so callers can wait for the WS before sending.
- **`duck_proxy.py`**: `/ws/notify` endpoint dispatches chip-originated `bambu_login` text frames to a registered handler. `main.py` registers `_do_bambu_login` (extracted from the HTTP `/admin/bambu_login` endpoint) at module load. Reply travels back over the same WS as `bambu_login_result`.
- **`bambu_state.py`**: HMS code filtering — `_hms_severity()` decodes the severity nibble from each `attr` uint32 (Bambu uses bits 31-16 lower-nibble). Snapshot + notifications now only include severity ≥ 1 (FATAL / SERIOUS / WARNING). Level-0 informational codes that Bambu's cloud reports but the printer UI hides no longer reach the agent. Fixes "the agent keeps saying the printer is flagging errors when nothing is wrong."
- **Deleted**: `bambu_login.c/.h` (chip-HTTPS), `recovery.c/.h` (duck.local fallback — captive portal handles the full flow now). The mbedtls memory tuning we'd added during the chip-TLS attempts (boosted IN_CONTENT_LEN, DYNAMIC_BUFFER toggles, etc.) was reverted from `sdkconfig.defaults` (no chip TLS = no need).
- **`user_id` field** removed from captive portal form. `/preference` auto-resolves it reliably; manual override stays as relay-side env var (`BAMBU_USER_ID`) in case Bambu ever changes that endpoint.

### Validated end-to-end on real hardware

```
448162 main: entering APSTA onboarding wizard
451517 provision: APSTA up: AP=DuckDuckDuck-0259, STA idle
465635 (iOS captive portal probe → page pops up)
493322 wifi: wifi creds saved
495921 wifi: connected with Bolinha (RSSI -47)
497176 notify channel connected
497359 bambu_login sent (97 bytes)
497949 notify text: {"type":"bambu_login_result","ok":false,"code":"2fa_required",...}
512020 bambu_login sent (103 bytes)   ← retry with code from email
513793 notify text: {"type":"bambu_login_result","ok":true,...}
513883 wizard reached DONE
```

### What this unlocks

The duck is shippable to anyone who isn't the developer. Hand someone a duck + a printed sticker that says "plug in, press the button, look for `DuckDuckDuck-XXXX` on your WiFi list." That's it. They handle the rest from their phone.

### Issues impacted

- **#42** APSTA — closed by this milestone
- **#31** cloud OAuth iteration B+C — folded into #42's APSTA delivery; full chip-side onboarding flow complete
- **#30** SoftAP onboarding — fully delivered (initial landing was 2026-05-01; APSTA is the polish)

## 🟢🟢🟢 2026-05-01 evening — cloud OAuth + SoftAP onboarding + tap-to-wake all live

**The big day.** Three flagship features landed end-to-end on real hardware, plus a tap-detector polish pass and several rounds of refactor/security hardening. Closing summary below; commit-by-commit detail in `git log`.

### What can a person actually do now (vs. yesterday morning)

- **Tap the duck's shell to start a conversation** — peak+slope detector with adaptive noise floor and asymmetric EMA so music doesn't trip it. Comedic servo "shake-off" animation on tap. (#37)
- **Set up WiFi from a phone, no laptop or app** — open the duck's `DuckDuckDuck-XXXX` AP, captive portal auto-pops via DNS-hijack + 404-redirect, dropdown of nearby networks, submit, done. Cross-platform (iOS/Android/anything). Long-press to re-onboard. (#30)
- **Sign in to Bambu cloud, talk over cloud MQTT** — relay no longer needs LAN access to the printer. The morning's "192.168.0.25 unreachable" debugging adventure is now historical: cloud broker via `us.mqtt.bambulab.com:8883`, authenticated `u_<userId>/<accessToken>`, same `device/<serial>/report` topic, full notification stream. (#31 iteration A)
- **Hear announcements about real prints, in voice, in real time, with accurate state** — validated against an actual Bambu print: tap on printer screen → cloud push → relay listener fires → broadcast or inject → agent improvises an announcement that correctly references print name, bed warming state, etc.

### Architectural choices captured

- **Cloud > LAN MQTT.** LAN reachability is fundamentally fragile (band steering, AP isolation, sleep states). Cloud just works from anywhere on the internet. The relay was designed to swap broker mode at runtime; reconfigure() pivots without dropping listeners.
- **`/preference` for user_id auto-resolve.** Bambu's accessToken stopped being a parseable JWT, and the login response body doesn't include user_id either. The canonical answer (per pybambu, OpenBambuAPI/cloud-http.md): GET `/v1/design-user-service/my/preference` with the bearer token returns `{uid, ...}`. We use it. Manual override remains as a fallback.
- **Token refresh: don't bother.** Bambu's `/refreshtoken` endpoint returns 401 always (documented broken). Tokens last ~90 days; user re-runs the email-code dance when they expire. Aligned with how every community project handles this.
- **Email verification is forced on every cloud login from a "new device".** Not optional, no trusted-device bypass exists in the public reverse-engineering. We accept this and design the captive portal to collect creds without code, validate post-reboot, and surface failure via the recovery path.
- **Single-tenant relay for now.** `tokens.json` holds one entry. When multi-tenant lands (#31 follow-up), it becomes a dict keyed by `duck_id` (chip MAC). Multi-printer-per-duck (#41) ships before multi-tenant (#31) since two-printer setups are common; multi-account is rare until we actually distribute ducks.
- **Bambu has aggressive bot detection.** Login retries are kept minimal (one `asyncio.Lock` to serialize concurrent attempts, no automatic retry, 429s pass through unchanged). No backoff fancy enough to look bot-shaped.

### Hardening pass

- `tokens.json` writes are atomic (temp + `os.replace`, 0600 perms). Defensive perm-heal on load.
- Error paths redact token-shaped substrings before they can leak into logs or HTTP error details.
- MQTT `auth_failed` flag surfaces CONNACK rc=4/5/134/135 (token rejected) so a 30-day-stale install is visible, not silent.
- `/admin/bambu_status` is now auth-gated and reports `connected` + `last_message_age_ms` (distinguishes "tokens.json exists" from "actually authed and live").
- Tap detector: `TAP_PEAK_MIN` 3000 → 5000, asymmetric floor adaptation (rises α=0.1, falls α=0.005). Music + drums no longer trip false taps.
- Printer name flows through to notifications ("Work Bambu just started a print of Dragon" vs the old "your printer just started").

### Issues filed

- **#39** Tighten broad except handlers in relay (would have caught the `_send_init` signature mismatch sooner)
- **#40** Double-tap as higher-confidence wake (Hoefer secret-knock pattern; defense-in-depth for false positives)
- **#41** Multi-printer per duck (one user, multiple printers — sequences before multi-tenant #31)

### What's left to make this shippable to a person who isn't me

- **#31 iteration B** — extend captive portal to collect Bambu email/pw/(optional 2FA). Today's wizard only does WiFi; OAuth still requires `curl /admin/bambu_login`.
- **#31 iteration C** — `duck.local` recovery page over STA mode for failure cases (2FA arrived after reboot, wrong password, expired token, etc.).
- **#41 multi-printer** — relevant the moment a second printer is in the picture.

Pickup pointer: iteration B is the keystone. Smallest delta from "today's win" to "shippable to a friend." Reuses everything we just built.

## 🟢 2026-05-01 — notification UX + simplification pass

Notifications now feel like a conversation, not a script. Two improvements landed:

**1. Inject-into-active-session.** Previously a printer event arriving mid-conversation would either be lost (single-slot queue collision with active button session) or open a new session that fought the active one for chip globals. Now `fire_notification` checks for live upstream(s) and pushes a `user_message` straight into the running ElevenAgents WS — agent interrupts itself naturally and pivots in voice. No WS teardown, no audio glitch.

**2. Notice vs update phrasing.** First printer event of a session uses `Printer notice: ...`, subsequent events use `Printer update: ...`. The "update" framing nudges the LLM to weave the new event into its in-progress response rather than re-announcing from scratch. Together with (1), bursts of events feel like updates the user is being told about, not interruptions.

Other landings:
- Relay debounced briefly, then reverted to immediate fire per UX call. ElevenLabs' user_message-mid-utterance behavior already cleanly cuts the agent's turn, no debounce needed.
- Firmware notify queue: single-slot `s_pending_event` → 4-deep FreeRTOS queue (`notify_item_t`) so back-to-back events while chip is offline/reconnecting don't drop the middle one. Per-printer dedup deferred to [#31](https://github.com/ideo/Rubber-Duck/issues/31) (needs printer auth/linking first).
- WAV recording in relay gated behind `RECORD=1` env. Was always-on while debugging audio cadence; hardware moved past that. Flip back on if mic/amp wiring changes.

Refactor pass cut ~50 lines of incidental complexity:
- Firmware: dropped dead `s_notify_busy` mutex (only-taker), dropped manual `s_notify_reconnect_pending` machinery (esp_websocket_client built-in reconnect already handles it), dropped `<freertos/semphr.h>` include.
- Relay: collapsed `_printer_notice_for`/`_printer_update_for` wrappers into direct `_printer_text_for` calls, promoted `dispatch()` closure to top-level `_dispatch_event`, swapped deprecated `asyncio.get_event_loop()` → `get_running_loop()`.
- Tier 3 design rationales baked into source comments (silence pump, friendly subtask, naive JSON parser) so they stop looking like deferred TODOs.

Found and filed during the pass:
- [#39](https://github.com/ideo/Rubber-Duck/issues/39) Tighten broad `except Exception` handlers in relay (masked a `_send_init` signature mismatch for several iterations of this session).

Bug found and fixed mid-session: `_send_init` had been refactored to take `suppress_first_message: bool` but the call site still passed `first_message=...` → TypeError on every new `/ws/duck` connection, swallowed by the broad except, presenting as "follow-up conversations don't work." This is the bug #39 will prevent recurring.

## 🟢🟢 2026-04-30 morning — printer plumbing verified end-to-end

The full loop closes. User asked the duck *"what's the printer doing?"*, ElevenLabs called `get_printer_state` via the static ngrok HTTPS tunnel, relay served live mock-printer state (mid-PREPARE phase), agent translated to natural language: *"Getting ready to print a benchy — heating up right now. Nozzle's at one hundred forty, needs to get to two-twenty, give it a minute."*

Plus servo animacy (idle hops + speech-driven beak swing), end_call tool ("goodbye" closes cleanly), 512KB spk buffer for long answers, self-feedback silenced via mic-zeroing-while-agent-speaking, silence pump in proxy keeping ElevenLabs sessions alive across mute windows.

What's left for v1:
- Real Bambu MQTT (currently MOCK=1 cycling fake Benchy print)
- Hardware: drill mic port hole closer to ICS-43432 to un-muffle (acoustic, not firmware)

Future-work issues filed:
- [#29](https://github.com/ideo/Rubber-Duck/issues/29) Opus end-to-end (path C-full)
- [#30](https://github.com/ideo/Rubber-Duck/issues/30) WiFi provisioning UX (SoftAP captive portal)
- [#31](https://github.com/ideo/Rubber-Duck/issues/31) Per-user printer linking + multi-duck relay (STA+AP simultaneous)
- [#32](https://github.com/ideo/Rubber-Duck/issues/32) Off-laptop deployment (Fly.io / VPS)
- [#33](https://github.com/ideo/Rubber-Duck/issues/33) VibeVoice consideration (deferred)
- [#34](https://github.com/ideo/Rubber-Duck/issues/34) Spoken onboarding via embedded Opus phrases

Static ngrok URLs reserved (paid tier):
- HTTPS for tools: `https://duck-duck-print.ngrok.io`
- TCP for duck WS: `tcp://2.tcp.ngrok.io:20554` (TODO: also reserve a permanent TCP address)

## 🟢 2026-04-29 evening — Path C working on the ducky PCB

End-to-end conversation working: clean mic capture, agent voice through speaker,
no self-feedback transcription, long agent responses no longer drop into static,
"goodbye" cleanly ends the call. Whole arc since the OG-XIAO degraded-mic
finding, in order:

- Ported full-duplex I2S (single port shared BCLK/WS, ICS-43432 mic, MAX98357
  stereo) for the ducky PCB pinout (GPIO13/12/7/1)
- Added 8× gain + DC removal pipeline from rubber_duck_s3_ducky updateMic
- Found `dma_frame_num` mismatch (256 vs AUDIO_FRAME_SAMPLES=320) caused
  partial-read rejections → aligned + accept partials
- Diagnosed ElevenLabs ending sessions at end-of-turn because no
  `user_audio_chunk` arrived during the mute window → added **silence pump**
  to the relay (sends 80ms of zero PCM whenever real frames stop)
- Switched mic to always-on; instead of muting, **zero out mic samples while
  the agent is speaking** to keep frames flowing without self-feedback
- Made `mute_timer` track speaker-stream emptiness, not just last-audio-event
  time — fixes the case where ElevenLabs has stopped sending but spk DMA still
  has seconds of buffered audio
- Bumped spk_stream from 64KB → **512KB in PSRAM** to hold 16s of pre-buffered
  agent audio without dropping into static
- Enabled ElevenAgents **"End call" system tool** + system-prompt instruction
  → "goodbye" cleanly ends the conversation
- Voice config flows through dashboard (need to hit **Publish** for changes
  to take effect on next session)

Architecture summary:

```
[duck (ducky PCB)] ──ws://ngrok-tcp──→ [relay] ──TLS+JSON+b64──→ [ElevenAgents]
                  ◀─── raw int16 PCM ───►       │
                                                 ├─→ silence pump (every 80ms
                                                 │   if no real frame arrived)
                                                 └─→ recordings/{ts}_mic.wav,
                                                     recordings/{ts}_agent.wav
```

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
PCM before forwarding to ElevenAgents. Reverse for downstream. The
esphome/micro-opus component is already integrated for the spoken-onboarding
phrases (#34) — that's the foundation for full path C work.

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
