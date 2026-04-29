# Bambu Duck — API Survey (v1)

Foundational research for a standalone Bambu-printer-companion duck. Scope: what the printer exposes locally, and which events are worth a voice reaction. **Not** a firmware design.

## 1. Local MQTT — connection

Bambu printers (X1, X1C, P1P, P1S, A1, A1 mini) expose an MQTT broker on the printer itself once **LAN Only Mode** + **Developer Mode** are enabled in the printer settings. Cloud-bound printers can also be reached via `us.mqtt.bambulab.com:8883` with an OAuth token, but the duck should target local for latency, privacy, and offline use.

| Field | Value |
|---|---|
| Host | `{PRINTER_IP}:8883` |
| Transport | TLS (self-signed cert — most clients disable verification or pin Bambu's cert) |
| Username | `bblp` |
| Password | Printer's **Access Code** (printed on screen under Settings → WLAN) |
| Client ID | Any unique string |
| Report topic (sub) | `device/{DEVICE_SERIAL}/report` |
| Request topic (pub) | `device/{DEVICE_SERIAL}/request` |

**Firmware minimums for Developer Mode**: A1 series ≥ `01.05.00.00`, P1 series ≥ `01.08.02.00`. X1 has had it longer.

**Quirks:**
- **P1/A1 send deltas only** — only changed fields appear in `push_status`. Client must publish `{"pushing":{"command":"pushall"}}` on connect to get a full snapshot, then patch deltas locally.
- **X1 sends full snapshots** every push.
- TLS cert is self-signed; ESP-IDF mbedTLS clients typically use `skip_cert_common_name_check` or load Bambu's CA from `OpenBambuAPI/tls.md`.
- Heartbeat: standard MQTT keepalive (60s works). No app-level ping required.
- Reconnect: printer drops the session if a second client connects with the same client ID — pick a stable unique ID per duck.

Sources: [Doridian/OpenBambuAPI mqtt.md](https://github.com/Doridian/OpenBambuAPI/blob/main/mqtt.md), [Bambu Wiki: Enable Developer Mode](https://wiki.bambulab.com/en/knowledge-sharing/enable-developer-mode), [Bambu Wiki: Third-party Integration](https://wiki.bambulab.com/en/software/third-party-integration).

## 2. `push_status` payload — fields the duck cares about

Wrapped under `print` in the JSON. Field names are stable across the community ecosystem (Home Assistant integration, OctoEverywhere, etc.).

**Print lifecycle**
- `gcode_state` — one of `IDLE`, `PREPARE`, `RUNNING`, `PAUSE`, `FINISH`, `FAILED`, `SLICING`, `OFFLINE`. **Primary state machine input.**
- `mc_print_stage` / `stg_cur` — numeric sub-stage code (~78 values). Maps to things like `auto_bed_leveling`, `heatbed_preheating`, `cleaning_nozzle_tip`, `paused_filament_runout`, `filament_unloading`, `m400_pause`, etc. (See `CURRENT_STAGE_IDS` in greghesp/ha-bambulab.)
- `mc_percent` — 0–100 progress.
- `mc_remaining_time` — minutes (yes, minutes, despite the name).
- `layer_num` / `total_layer_num`.
- `print_error` — non-zero ⇒ error code (decode via Bambu HMS wiki).
- `fail_reason` — string, when present.

**Temperatures**
- `nozzle_temper`, `nozzle_target_temper`
- `bed_temper`, `bed_target_temper`
- `chamber_temper` (X1 only)

**Hardware messages (the gold mine)**
- `hms` — array of `{attr, code}` pairs. Attr's high nibble identifies the **module** (`0x05` mainboard, `0x07` AMS, `0x08` toolhead, `0x0C` xcam, `0x03` mc). Code's first byte is **severity** (`1` fatal, `2` serious, `3` common, `4` info). Example: `HMS_0300_0100_0001_0001` = filament runout. Empty array ⇒ all-clear.

**AMS / filament**
- `ams.ams[]` — per-AMS-unit array with `tray[]` (4 slots): `tray_color`, `tray_type` (PLA/PETG/...), `remain` (% est).
- `ams_status` — bitfield; non-zero generally means AMS is busy/loading/erroring.
- Filament runout surfaces as both an HMS code **and** a `stg_cur` of "filament runout pause".

**Other**
- `wifi_signal` (dBm string), `sdcard` status, `spd_lvl` (1 silent → 4 ludicrous), `chamber_light`, `cooling_fan_speed`, fan triplet `big_fan1/2_speed`/`heatbreak_fan_speed`.

Sources: [Doridian mqtt.md](https://github.com/Doridian/OpenBambuAPI/blob/main/mqtt.md), [greghesp/ha-bambulab const.py](https://github.com/greghesp/ha-bambulab/blob/main/custom_components/bambu_lab/pybambu/const.py), [hannasdev/n8n-nodes-bambulab](https://github.com/hannasdev/n8n-nodes-bambulab).

## 3. Event → phrase mapping (duck reactions)

Trigger logic is "edge on the source field", not "every push". 10 events for v1:

| # | Trigger (field edge) | Phrase (≤8 words) | Default | Why |
|---|---|---|---|---|
| 1 | `gcode_state`: `PREPARE`/`RUNNING` enters | "Here we go." | always | Print-start is the canonical moment |
| 2 | `gcode_state` → `FINISH` | "Look at this beautiful print." | always | The payoff |
| 3 | `gcode_state` → `FAILED` *or* `print_error≠0` | "Oh no. We have a problem." | always | Must-tell |
| 4 | `gcode_state` → `PAUSE` (any cause) | "We are paused." | always | Disambiguated by sub-events below |
| 5 | HMS code matches filament-runout family | "Out of filament. Feed me." | always | Most common pause cause |
| 6 | Any new HMS with severity ≤ 2 | "Something is wrong with the printer." | always | Fatal/serious — speak first, detail later |
| 7 | `mc_percent` crosses 25 / 50 / 75 | "Quarter / Halfway / Three quarters there." | configurable | Casual progress; mute by default for short prints |
| 8 | `bed_temper` reaches `bed_target_temper` first time after PREPARE | "Bed's hot. Showtime soon." | configurable | Nice texture, can be noisy on multi-color |
| 9 | `stg_cur` enters `auto_bed_leveling` | "Calibrating. Don't bump the table." | configurable | Useful for heavy-footed humans |
| 10 | `gcode_state` → `IDLE` after `FINISH` and `bed_temper < 40°C` | "Cool enough to grab. Go." | configurable | Replaces watching the temp panel |

**Skip / noisy:**
- `mc_remaining_time` updates (changes constantly)
- Per-layer notifications (use percentage thresholds instead)
- Fan speed / chamber light / wifi_signal (telemetry only)
- AMS slot color changes (cosmetic)
- HMS severity 4 ("info") unless explicitly opted in

**Cooldown rule for all triggers:** debounce identical events for ≥ 30s, and never speak two phrases within 5s — let the duck breathe.

## 4. Cloud MQTT path (for users who keep Bambu Handy)

For users who don't want to flip LAN Only Mode (loses Bambu Handy remote, cloud printing, auto firmware updates), the duck can subscribe to Bambu's **cloud MQTT relay** instead of the printer's local broker. Same topic vocabulary, same payload, same reactions — just an extra auth step at startup.

### Auth flow

One-time setup (then the duck remembers across reboots):

1. **User provides credentials** via a captive-portal on the duck (or one-time entry over USB serial). Persisted to NVS:
   - Bambu account email + password, OR
   - Refresh token if we want a no-password setup later
2. **Login**: `POST https://api.bambulab.com/v1/user-service/user/login`
   - Body: `{"account": "<email>", "password": "<password>"}`
   - Response: `{"accessToken": "...", "refreshToken": "...", "expiresIn": 86400}`
3. **Region detection**: the login response includes the user's home region. Pick `us.mqtt.bambulab.com` or `cn.mqtt.bambulab.com` accordingly.
4. **Refresh loop**: access tokens expire ~24h. Duck refreshes silently with `POST /v1/user-service/user/refreshtoken` whenever it has < 1h left or whenever a reconnect attempt fails with auth.

### MQTT connection

| Field | Value |
|---|---|
| Host | `us.mqtt.bambulab.com:8883` (or `cn.` for CN accounts) |
| Transport | TLS (properly CA-signed — easier than the local self-signed mess) |
| Username | `u_{user_id}` — the numeric Bambu user ID from the login response |
| Password | the current access token |
| Client ID | unique per duck (UUID generated once, stored in NVS) |
| Subscribe | `device/{SERIAL}/report` |
| Publish | `device/{SERIAL}/request` |

The `pushall` snapshot semantics for P1/A1 still apply over cloud — duck publishes `{"pushing":{"command":"pushall"}}` on every reconnect to get a full state, then patches deltas.

### Extra complexity vs local

| Concern | Local | Cloud |
|---|---|---|
| HTTPS client | not needed | needed for login + refresh |
| JSON parsing for auth | n/a | needed (small) |
| NVS storage | optional | required (refresh token, region) |
| Token refresh timer | n/a | needed |
| Region detection | n/a | needed |
| Cert handling | self-signed mess | trivial (public CA) |
| Latency | LAN-fast (~1–10ms) | round-trip to Bambu (~50–200ms) |
| Stability | rock-solid | Bambu can change the cloud API any time |

### Reference implementations

These have all solved cloud auth — worth cribbing from rather than reinventing:
- [`greghesp/ha-bambulab`](https://github.com/greghesp/ha-bambulab) — Home Assistant integration, full Python; their `pybambu/bambu_cloud.py` is the auth + region + refresh playbook
- [`hannasdev/n8n-nodes-bambulab`](https://github.com/hannasdev/n8n-nodes-bambulab) — Node.js port of the same flow
- [`Doridian/OpenBambuAPI`](https://github.com/Doridian/OpenBambuAPI) — protocol-level docs covering both local and cloud paths

### Cloud-specific risks

- **Bambu's cloud API is undocumented.** All known integrations are reverse-engineered. Bambu has changed auth twice in the last two years; expect to update the duck firmware when they do.
- **Rate limits.** Unknown but real — don't poll, stay subscribed. The duck's reaction model is already push-only, so this is fine.
- **Account credentials on a small device.** Refresh tokens stored on an ESP32 NVS without flash encryption are extractable by a determined attacker with physical access. Recommend documenting this clearly and offering "reset duck" to wipe credentials.
- **Region drift.** If a user moves regions (e.g. travels, account migrates), the cached endpoint will start failing. Detect and re-resolve.

## 5. Standalone duck — the full architecture

Once printer data is in our hands (sections 1–4), the duck becomes a self-contained device on its own WiFi. Two voice modes share the same hardware:

| Layer | When it speaks | Latency | Offline | Cost |
|---|---|---|---|---|
| **Proactive** (pre-baked Opus phrases) | Reacting to printer events from MQTT | < 50ms | ✅ yes | none |
| **Conversational** (ElevenLabs Convai) | After "ducky" wake word from the user | ~500ms first audio | ❌ no | per-minute |

The proactive layer is v1. The conversational layer is the unlock — the duck stops being a notifier and becomes a printer-savvy companion you can chat with about settings, status, history.

### 5.1 Proactive voice — Opus pipeline (cribbed from URAM)

URAM (sibling project on the same chip class — ESP32-S3) ships ~5.4 MB of Opus voice + SFX assets baked into firmware. Adopt their pipeline verbatim:

- **Codec**: Opus at 24 kbps mono 16 kHz, voip-optimized (`-application voip -vbr on`)
- **Transcode**: `ffmpeg -i source.{wav,mp3} -c:a libopus -b:a 24k -ar 16000 -ac 1 -application voip -vbr on -compression_level 10 out.opus`
- **Embed**: ESP-IDF `EMBED_FILES` directive in `main/CMakeLists.txt` — each `.opus` becomes a `.rodata.embedded` symbol that the decoder reads directly from flash
- **Decoder**: [`esphome__micro-opus`](https://github.com/esphome-libs/micro-opus) — Xtensa DSP-optimized (~17–25% faster than vanilla on ESP32-S3), PSRAM-aware, thread-safe via per-thread pseudostack

**Size win vs the current `StoredPhrases.h` raw-PCM approach:**

| Format | 3-second phrase | Library of 20 phrases |
|---|---|---|
| Raw 16 kHz s16 PCM | ~96 KB | ~1.9 MB |
| **Opus 24 kbps voip** | **~9 KB** | **~180 KB** |

That ~10× compression makes a rich, varied phrase library fit comfortably (multiple takes per event for randomness — duck doesn't sound like a vending machine).

### 5.2 Wake word — on-device, no Mac required

For the duck to listen for "ducky" without a Mac in the loop, wake-word detection runs on the ESP32-S3. Three credible options:

| Option | Pros | Cons |
|---|---|---|
| **Espressif esp-sr / WakeNet** | Official, free, Xtensa DSP-optimized, drops into ESP-IDF | Custom wake-word training requires Espressif's paid service |
| **microWakeWord** (esphome) | Open source MIT, **Home Assistant Voice ships this**, custom wake words via Google Colab (~50 recordings → ~80 KB TFLite model) | TFLite-Micro runtime adds ~150 KB code/RAM; slightly less accurate than Porcupine in noisy environments |
| **Picovoice Porcupine** | Best accuracy, friendliest custom-word training (web tool, no audio recording) | Commercial license — free for hobby, ~$1–5/device for distribution |

**Recommended: microWakeWord.** Same chip class, proven in Home Assistant Voice, fully open + free, Colab notebook trains a custom "ducky" model in one session. Detection latency typically <200ms.

### 5.3 Conversational layer — ElevenLabs Convai

[ElevenLabs Conversational AI](https://elevenlabs.io/docs/conversational-ai/overview) bundles STT + LLM + TTS over a single WebSocket. Audio in, audio out. The duck becomes a thin client.

**Architecture:**

```
[mic ICS-43434] → [microWakeWord, on-device]
                          ↓ ("ducky" detected)
                  [open WebSocket → wss://api.elevenlabs.io/v1/convai/...]
                          ↓ stream raw 16 kHz PCM mic audio
                  [ElevenLabs Convai server]
                          STT → LLM (with tools) → TTS
                          ↓ stream Opus / MP3 response audio
                  [micro-opus decoder] → [I2S DAC] → [speaker]
                          ↓ end-of-speech / button → close
                  [back to wake-word listening]
```

**Tooling on the LLM side is the unlock** for printer-savvy answers. Configure the Convai agent with function-call tools the LLM can invoke mid-conversation:

- `get_printer_state()` — parsed `push_status` JSON (current stage, percent, layer, AMS, recent HMS codes)
- `get_print_history(n)` — last N print outcomes (persisted in NVS by the duck)
- `pause_print()` / `resume_print()` — publishes to `device/{serial}/request`
- `get_filament_inventory()` — AMS slot contents and remaining %
- `get_temperatures()` — nozzle / bed / chamber

User says "how's the dragon coming along?" → LLM calls `get_printer_state`, gets live data, replies in natural language with the duck's voice.

**Cost reality check**: ElevenLabs Convai bills per-minute (~$0.10–0.30/min depending on tier). Acceptable for occasional questions, expensive if abused. Gate firmly with the wake word + hard idle timeout (e.g., 30s of silence ends the session).

### 5.4 Future: MCP tool expansion

Once Convai is wired up, the LLM's tool list becomes expandable without firmware changes. A local or cloud-side **MCP server** can host additional tools the Convai agent registers as available:

- Slicer profile lookup ("recommended bed temp for ASA?")
- Filament inventory across multiple printers / AMS units
- Print queue management
- Bambu Studio integration (kick off a sliced profile)
- Cross-printer history ("which print this week finished closest to its estimate?")

MCP makes this open-ended — add a tool to the server, duck instantly knows about it. Out of scope for v1; design ergonomics toward this so we don't paint ourselves out of it.

---

## 6. Risks / open questions

**Bambu API**
- **Cloud-bound printers can't be reached locally.** A user without LAN Only + Developer Mode enabled has no local MQTT broker. The cloud MQTT path (section 4) is the alternative — at the cost of OAuth complexity and Bambu API instability.
- **TLS on ESP32**: local broker uses a self-signed cert that rotates with firmware. Cloud broker is properly CA-signed (easier). Pick a strategy and document it.
- **P1/A1 delta-push semantics** mean the duck has to maintain a local state object and diff it. Easy to miss edges (e.g., FINISH if snapshot lands before subscription completes).
- **HMS code catalog drifts.** New firmware adds codes; the wiki lags. Fall back to "something's wrong" for unknown codes rather than going silent.
- **Multi-printer households** — topic includes serial, so one duck per printer is the simple v1 model. Multi-printer duck is a v2 question.

**Voice / conversational layer**
- **Convai cost**: per-minute billing means a wake-word false-positive that opens a session and runs to idle-timeout costs real money. Tune the wake-word threshold conservatively, hard-cap idle timeout to ~30s.
- **Wake-word false-positive rate** in noisy environments (printer fans, music) is the single biggest UX risk. microWakeWord's Colab notebook lets us tune sensitivity; plan for at least one round of in-environment iteration.
- **Convai outage = no conversation, but proactive layer still works.** Make sure proactive Opus playback has zero dependency on the Convai connection.
- **API key management on the duck**: ElevenLabs API key has to live somewhere. NVS is the pragmatic answer; document the "reset duck" flow that wipes credentials.
- **Conversational latency budget**: wake-word (~200ms) + WebSocket open + first STT chunk + LLM tool call + TTS first byte ≈ 1–2 seconds before the duck starts speaking back. Anything longer feels broken. Worth instrumenting end-to-end early.
- **Tool authority**: giving the Convai LLM the ability to `pause_print()` is real power. Decide whether destructive tools require voice confirmation ("are you sure?") or stay read-only.

---

Sources:
- [Doridian/OpenBambuAPI](https://github.com/Doridian/OpenBambuAPI)
- [greghesp/ha-bambulab](https://github.com/greghesp/ha-bambulab)
- [Bambu Wiki — Developer Mode](https://wiki.bambulab.com/en/knowledge-sharing/enable-developer-mode)
- [Bambu Wiki — Third-party Integration](https://wiki.bambulab.com/en/software/third-party-integration)
- [hannasdev/n8n-nodes-bambulab](https://github.com/hannasdev/n8n-nodes-bambulab)
