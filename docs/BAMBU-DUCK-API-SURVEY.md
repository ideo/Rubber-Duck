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

## 4. Risks / open questions

- **Cloud-bound printers can't be reached locally.** A user who never enabled LAN Only + Developer Mode has no MQTT to talk to. Onboarding has to walk them through enabling it (and warn that it disables Bambu Handy app cloud control).
- **TLS on ESP32**: cert is self-signed and rotates with firmware. Either ship Bambu's CA bundle and accept future breakage, or skip CN verification (works, slightly less paranoid). PSK is not an option here.
- **P1/A1 delta-push semantics** mean the duck has to maintain a local state object and diff it — can't just react to whatever arrived in the last message. Easy to get subtly wrong (e.g. missing the FINISH edge if the snapshot arrives before subscription).
- **HMS code catalog drifts.** New firmware adds codes; the wiki lags. Duck should fall back to "something's wrong" (event #6) for unknown codes rather than going silent.
- **Multi-printer households** — topic includes serial, so one duck per printer is the simple model. A duck that watches several printers is a v2 question, not v1.

---

Sources:
- [Doridian/OpenBambuAPI](https://github.com/Doridian/OpenBambuAPI)
- [greghesp/ha-bambulab](https://github.com/greghesp/ha-bambulab)
- [Bambu Wiki — Developer Mode](https://wiki.bambulab.com/en/knowledge-sharing/enable-developer-mode)
- [Bambu Wiki — Third-party Integration](https://wiki.bambulab.com/en/software/third-party-integration)
- [hannasdev/n8n-nodes-bambulab](https://github.com/hannasdev/n8n-nodes-bambulab)
