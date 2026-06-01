# Boy Band — Operations Manual

**The authoritative guide to running the boy band system: how it connects,
how to flash a duck, how to run the computer side, and how to debug it
when it misbehaves.** Written for collaborators (Devin, Jenna, and any AI
assistant either of them is driving). If something here is wrong or
out of date, fix it in the same commit as whatever you changed.

> First-time reader: read this top to bottom once. It's long because the
> bring-up had real gotchas and this is where they're written down so you
> don't lose an afternoon to them.

---

## 1. What the system is (30-second mental model)

Four rubber ducks perform on stage, driven by one Mac.

```
                    ┌─────────────────────────────────────┐
   Mode 1 (DAW):    │              THE MAC                 │
   Logic → BlackHole│                                      │
              ──────┼─►  Stage app (BoyBandStage)          │
   Mode 2 (FAQ):    │    - WebSocket server on :3334       │
   mic→STT→LLM→TTS ─┼─►  - routes audio to 4 ducks         │
                    │    - maps each duck's MAC → D1..D4    │
                    └───────────┬──────┬──────┬──────┬─────┘
                                │      │      │      │
                       ws://<mac-ip>:3334/ws/duck (+ X-Duck-Id header)
                                │      │      │      │
                                ▼      ▼      ▼      ▼
                               D1     D2     D3     D4
                          (ESP32-S3 ducks running BAMBU_DUCK_BOYBAND firmware)
```

- The **duck firmware** is the Bambu Duck firmware compiled with a special
  `BAMBU_DUCK_BOYBAND` flag ("puppeteer mode"). It auto-connects to the Mac
  at boot, holds the connection open forever, and just plays whatever audio
  the Mac streams to it (wobbling its head to the sound).
- The **Stage app** (`boyband/stage/`, Swift) is a local server that
  *impersonates the Bambu cloud relay*. The firmware doesn't know the
  difference — it speaks the exact same WebSocket + PCM protocol.
- **Everything is local.** No internet required for the performance. No
  cloud relay, no fly.dev. The Mac and the ducks just need to be on the
  same WiFi.

The two performance modes (DAW playback vs live FAQ) share the entire
downstream path — only the audio *source* on the Mac differs. See
`PLAN.md` for mode details. This doc is about the plumbing they share.

---

## 2. One-time setup

### On the Mac (computer side)

You need:

- **Xcode / Swift toolchain** (macOS 26, Swift 6.2). Check: `swift --version`.
- **The repo**, on the `feature/boy-band` branch:
  ```sh
  cd ~/Documents/GitHub/Rubber-Duck
  git switch feature/boy-band
  ```
- Build the Stage app once to confirm it compiles:
  ```sh
  cd boyband/stage
  swift build
  ```

### For flashing ducks (only needed if you're (re)flashing firmware)

- **ESP-IDF v5.3.4** installed at `~/esp/esp-idf/`. Check:
  ```sh
  . ~/esp/esp-idf/export.sh && idf.py --version   # → ESP-IDF v5.3.4
  ```
  If the Python env complains, see `bambu/docs/FLASHING.md` § Gotchas.
- A **USB data cable** (not charge-only) to connect the duck to the Mac.
- **pyserial** for reading duck logs (optional, debug only):
  ```sh
  bambu/relay/.venv/bin/pip install pyserial
  ```

---

## 3. The network (read this — it bit us hard)

The duck and the Mac **must be on the same WiFi**, and the duck must be
able to open a TCP connection to the Mac on port 3334.

### ⚠️ USE THE MAC'S RAW IP, NOT ITS `.local` HOSTNAME

We wasted significant time on this. On IDEO networks (corporate *and*
guest), **mDNS hostname resolution is poisoned** — `<mac>.local` resolves
to a stale/ghost IP that's pinned by corporate policy and survives even a
`sudo killall -HUP mDNSResponder` flush. The duck dutifully connects to
the ghost IP and times out forever (`errno=119`, `EHOSTUNREACH`).

**The fix is to bake the Mac's actual IP address into the firmware**, not
its hostname. See §4.

Find the Mac's current IP:
```sh
ipconfig getifaddr en0      # en0 is WiFi on this hardware
# e.g. 10.5.128.41
```

> **Caveat — guest DHCP leases change.** If the Mac's IP changes (lease
> renewal, reconnect, different day), the baked-in firmware URL is wrong
> and the duck can't connect. You'll have to reflash with the new IP. For
> the **actual show**, the plan is a dedicated travel router with reserved
> IPs so this never happens (see `docs/show-runbook.md`). For dev, just
> re-check `ipconfig getifaddr en0` and reflash if it moved.

### WiFi requirements for the duck

- **WPA2/WPA3-Personal (PSK)** — a single shared password. The duck's
  onboarding **cannot** do WPA2-Enterprise (the 802.1X username+password
  login that corporate "IDEO" WiFi uses). IDEO-Guest works (it's PSK).
  A phone hotspot works.
- The network must **not** have client isolation so aggressive that it
  blocks duck↔Mac TCP. IDEO-Guest allowed it in testing (ARP + TCP both
  worked between clients). Some guest networks don't — if so, use a phone
  hotspot or the dedicated show router.

---

## 4. Flashing a duck

All commands run from `bambu/firmware/` with ESP-IDF sourced:

```sh
cd bambu/firmware
. ~/esp/esp-idf/export.sh
```

### The one command

```sh
make flash-boyband \
    PORT=/dev/cu.usbmodem101 \
    STAGE_URL=ws://<MAC-IP>:3334 \
    [VOL_STEP=3]
```

Concrete example (Mac at 10.5.128.41, very-quiet boot volume):
```sh
make flash-boyband PORT=/dev/cu.usbmodem101 STAGE_URL=ws://10.5.128.41:3334
```

Parameters:

| Param | Meaning | Notes |
|---|---|---|
| `PORT` | Serial device of the duck | Find with `ls /dev/cu.usbmodem*`. Usually `...101`. |
| `STAGE_URL` | **Mac's raw IP**, `ws://IP:3334` | **Required.** Plain `ws://`, not `wss://`. No hostname (see §3). Build fails fast if omitted. |
| `VOL_STEP` | Boot volume 0–4 | Optional. Default **3** (Very Quiet, 0.05). See volume table below. |

Volume steps (boy band has **no volume button** — this is fixed at flash time):

| `VOL_STEP` | Preset | Amplitude | Use |
|---|---|---|---|
| 0 | Loud | 0.75 | Stage / PA |
| 1 | Normal | 0.50 | Room-filling — hot in a quiet room |
| 2 | Quiet | 0.25 | Indoor speaking volume |
| 3 (default) | Very Quiet | 0.05 | Crowded-room first boot. Near-silent. |
| 4 | Mute | 0.00 | — |

### What happens after flashing

1. The duck hard-resets and boots the BOYBAND firmware.
2. **WiFi**: if it already has WiFi creds in NVS (e.g. carried over from
   previous firmware — NVS survives reflashing), it connects silently. If
   not, it brings up a captive-portal AP named `DuckSetup-XXXX`; join it
   from a phone, browse to `http://192.168.4.1`, enter **WiFi only**
   (leave Bambu/printer fields blank — boy band ignores them; the form's
   "required" markers are HTML-only and not server-enforced on this
   turnkey build).
3. It auto-opens a session to `STAGE_URL/ws/duck` and **holds it forever**,
   reconnecting every ~7s if it drops. No tap-to-wake, no buttons.
4. It sends its chip MAC as an `X-Duck-Id` header — that's how Stage knows
   which duck it is (see §5).

### Finding a duck's MAC — and the +1 gotcha

You need each duck's MAC to map it to a slot (D1..D4).

> ⚠️ **The duck's `duck_id` is its SoftAP MAC, which is the base MAC + 1
> in the last octet.** `duck_id_get()` uses `esp_read_mac(ESP_MAC_WIFI_SOFTAP)`.
> But `esptool` / `chip_id` reports the **base** MAC. So if you read the
> MAC with esptool, **add 1 to the last byte** before putting it in the
> duck-map. We got this wrong once (used the base MAC, duck got rejected
> with "not in duck-map").

Most reliable: read the **`duck_id=...`** line from the boot serial — that
prints the exact value the firmware sends (already SoftAP/+1, no math).
It logs the first time the duck opens a session. Other ways:

- Let it connect to Stage with `--no-duck-map`; Stage logs the rejected
  `duck_id` (see §6) — copy that verbatim.
- `esptool ... chip_id` reports the base MAC → remember to +1.
- The boot log's `softAP (xx:xx:...:NN)` line is the SoftAP MAC directly.

### The duck roster (our hardware)

| Name | Slot | duck_id (SoftAP MAC) | base MAC (esptool) | USB port |
|---|---|---|---|---|
| **Mallard** | D1 | `dcb4d92961e9` | `…61e8` | `…usbmodem101` |
| **Pekin** | D2 | `dcb4d9296125` | `…6124` | `…usbmodem1101` |

(Both ESP32-S3 ducky PCBs, same vendor batch — note the sequential MACs.)
The live MAC→slot+name binding lives in `duck-map.local.json` (gitignored,
per-Mac); `duck-map.example.json` shows the format.

### Copying WiFi creds between ducks (NVS clone) — skip the captive portal

If one duck already has working WiFi creds and you're flashing another for
the same network, you can clone the creds over USB instead of running the
captive portal again:

```sh
. ~/esp/esp-idf/export.sh
# Dump the source duck's NVS partition (0x9000, size 0x6000). Resets it.
python -m esptool --chip esp32s3 -p /dev/cu.usbmodemSRC \
    read_flash 0x9000 0x6000 /tmp/nvs.bin
# Write it onto the target duck's NVS.
python -m esptool --chip esp32s3 -p /dev/cu.usbmodemDST \
    write_flash 0x9000 /tmp/nvs.bin
```

**Why it's safe:** `duck_id` is derived from efuse at runtime, NOT stored
in NVS — so the target keeps its own MAC/identity, it just inherits the
WiFi creds. (It also inherits the source's volume + relay_url, but BOYBAND
overrides volume at boot via `VOL_STEP`, and the relay_url is the same
baked URL anyway.) The NVS partition offset/size come from
`bambu/firmware/partitions.csv` (`nvs 0x9000 0x6000`). We used this to give
Pekin Mallard's IDEO-Guest creds in ~5 seconds — no phone, no portal.

---

## 5. Running the Stage app (computer side)

From `boyband/stage/`:

```sh
cd boyband/stage
swift run BoyBandStage [options]
```

(Or run the built binary directly: `./.build/debug/BoyBandStage [options]`.)

### The duck map

Stage routes each duck to a slot by chip MAC. Create
`boyband/duck-map.local.json` (gitignored, per-Mac — copy from
`duck-map.example.json`):

```json
{
  "dcb4d92961e9": "D1",
  "<mac of duck 2>": "D2",
  "<mac of duck 3>": "D3",
  "<mac of duck 4>": "D4"
}
```

MACs are case-insensitive. The example file documents the format without
leaking anyone's specific hardware.

### Common invocations

```sh
# Sound check — stream a sine to every connected duck (distinct pitch each)
swift run BoyBandStage --duck-map ../duck-map.local.json --sine

# Solo one duck with sine (others silent) — what we used for first bring-up
swift run BoyBandStage --duck-map ../duck-map.local.json --sine D1

# Real audio — stream an audio file to one duck (wav/aiff/mp3/m4a).
# Resamples to 16k/mono/int16 ONCE offline, then paces at 20ms so the
# duck's buffer never overflows. The safest real-audio source (no live
# device clock, no realtime resampler). --loop to repeat.
#   ⚠️ THIS MAKES THE PHYSICAL DUCK PLAY SOUND — warn anyone nearby first.
swift run BoyBandStage --duck-map ../duck-map.local.json --play song.wav D1 --loop

# List Mac audio input devices (find your BlackHole for Mode 1)
swift run BoyBandStage --list-inputs

# Mode 1 — read 4 channels from BlackHole and route to D1..D4
swift run BoyBandStage --duck-map ../duck-map.local.json --mode1

# Test mode without real hardware — accept fake-duck.py on /duck/{ID}
swift run BoyBandStage --no-duck-map --sine
```

### Two connection paths Stage accepts

| Path | Who uses it | Slot comes from |
|---|---|---|
| `/ws/duck` + `X-Duck-Id: <MAC>` header | **Real duck firmware** | duck-map.local.json lookup |
| `/duck/{D1..D4}` | `fake-duck.py`, manual tests | the path itself |

`--no-duck-map` **disables** `/ws/duck` (returns HTTP 503). A real duck
hitting Stage in that mode logs `503` on its serial — that's not a bug,
it just means "load a duck-map." This exact thing confused us during
bring-up.

---

## 6. Verifying it works

When a duck connects successfully:

- The duck's serial logs `agent: ws connected to relay` (no 503, no
  connect errors).
- With `--sine`, the duck **wobbles its head continuously** as if talking.
  This is correct: a constant unbroken tone keeps the duck pinned in its
  "speaking" animation. Real audio (with swells and silences) looks
  natural; a flat sine looks like nonstop chatter.
- Audio comes out the speaker — but at `VOL_STEP=3` (0.05) it's
  **near-silent**. Don't conclude "no audio" from inability to hear it in
  a noisy room; bump `VOL_STEP` to actually test the audio path.

### Telemetry without breaking things

> **⚠️ Reading the duck's serial port RESETS the chip.** Opening
> `/dev/cu.usbmodem101` with pyserial asserts DTR, which reboots the
> ESP32-S3 and drops its connection to Stage. **Do not poll serial when
> you need the duck to stay connected.** Read it once to capture the boot
> log / MAC, then leave it alone and use the methods below.

Non-destructive checks:

```sh
# Is Stage listening?
lsof -nP -iTCP:3334 | grep LISTEN

# Is a duck actually connected (TCP ESTABLISHED)?
lsof -nP -iTCP:3334 | grep ESTAB

# Is Stage still running?
ps aux | grep BoyBandStage | grep -v grep
```

The most reliable telemetry during a test is **the physical duck itself**
— is the head moving? Is there (quiet) sound?

> **Note on Stage logs:** Swift's `print()` block-buffers when stdout is
> redirected to a file, so `> stage.log` may stay empty even while Stage
> is working fine. Run Stage in a foreground terminal (TTY) to see logs
> live, or rely on `lsof`/serial. (A future improvement: add `setvbuf`
> line-buffering or a proper log file in Stage.)

---

## 7. Troubleshooting (every error we actually hit)

| Symptom (duck serial / Mac) | Cause | Fix |
|---|---|---|
| `Error connecting to host ...`, `errno=119`, `EHOSTUNREACH` | Mac IP unreachable — usually the **mDNS ghost IP** (baked hostname resolves to a dead corporate-pinned address) or wrong/changed Mac IP | Bake the Mac's **raw IP** into firmware (§3–4). Re-check `ipconfig getifaddr en0`. |
| `esp_ws_handshake_status_code=503`, `Sec-WebSocket-Accept not found` | Stage running with `--no-duck-map` (production `/ws/duck` path disabled) | Restart Stage **with** `--duck-map ../duck-map.local.json` |
| `reject MAC=xxxx — not in duck-map` (Mac stderr) | Duck's MAC isn't in the map — OR you used the **base** MAC instead of the SoftAP MAC | Add the rejected `duck_id` verbatim to `duck-map.local.json`. Remember duck_id = base MAC **+1** (§4). |
| Duck connects then immediately drops, repeatedly | You're **polling the serial port** (each open resets the chip) | Stop reading serial; use `lsof` instead |
| No `/dev/cu.usbmodem*` appears | Charge-only cable, or chip not enumerating | Swap to a data cable (`bambu/docs/FLASHING.md`) |
| Build error: `BAMBU_DUCK_BOYBAND requires -DRELAY_BASE_URL` | Forgot `STAGE_URL=` on the make line | Add `STAGE_URL=ws://<ip>:3334` |
| Can't hear any audio | `VOL_STEP=3` is near-silent by design | Reflash with `VOL_STEP=2` or `1` |
| Duck head wobbles constantly / "too much" | It's receiving a constant sine → constant "speaking" state | Expected. Real varied audio looks natural. |
| Captive portal won't submit (Bambu fields "required") | HTML `required` markers | They're not server-enforced — fill WiFi only and submit; or POST directly to `/save` with just `ssid`+`pw` |
| Port held during flash (`lsof` shows a holder) | A serial monitor (Arduino IDE, screen, etc.) owns the port | **Ask the human to close it** — never kill it (project rule) |

---

## 8. Scaling to four ducks

Everything above is single-duck. For the full band:

1. Flash all four ducks with the **same** `STAGE_URL` (same Mac).
   They differ only by chip MAC, which is hardware-unique.
2. Put all four MACs in `duck-map.local.json`, mapped D1→D4 by their
   physical left-to-right stage position.
3. Start Stage once; all four connect to the same server. `--sine` (no
   solo) sends a distinct pitch to each (C-E-G-C chord) so you can
   confirm channel routing by ear.
4. Physical position = slot identity. If D1's audio comes out of the
   duck on the right, either swap the ducks physically or edit the map
   and restart Stage.

---

## 9. Dev vs show-day differences

| | Dev (now) | Show day |
|---|---|---|
| Network | IDEO-Guest / hotspot, raw IP, reflash if IP drifts | Dedicated travel router, reserved IPs, baked once |
| Volume | `VOL_STEP=3` (quiet, room-safe) | `VOL_STEP=0/1` (PA-level), reflashed before show |
| Stage source | `--sine` for verification | `--mode1` (DAW) or Mode 2 (FAQ orchestrator) |
| Telemetry | serial + lsof + watching the duck | watching the ducks; serial detached |

The show runbook (cabling, cue sheet, failure drills, T-minus checklist)
lives in `docs/show-runbook.md`. This doc is the engineering plumbing;
that one is the performance choreography.

---

## 10. File map (where the code lives)

Everything boy band is on the **`feature/boy-band`** branch, in one place:

```
boyband/
├── OPERATIONS.md           ← you are here (run/connect/flash)
├── PLAN.md                 ← architecture + week-by-week plan
├── STATE.md                ← living status; what's done, what's next
├── CLAUDE.md               ← collaborator working agreement
├── README.md               ← entry point / quick links
├── duck-map.example.json   ← MAC→slot map template (copy to .local.json)
├── docs/
│   ├── stage-protocol.md   ← exact wire format Stage ↔ firmware
│   ├── duck-id-mapping.md   ← how MAC→slot routing works + rationale
│   ├── orchestrator.md     ← Mode 2 LLM contract + personas
│   ├── show-runbook.md     ← show-day choreography + checklists
│   └── api-keys.md         ← where keys live (never in git)
├── scripts/
│   └── fake-duck.py        ← pretend to be a duck (test Stage w/o hardware)
└── stage/                  ← the Stage app (Swift)
    └── Sources/BoyBandStage/
        ├── main.swift           ← CLI entry, arg parsing
        ├── StageServer.swift    ← WebSocket server, MAC routing
        ├── DuckMap.swift        ← MAC→slot config loader
        ├── SineGenerator.swift  ← sound-check tone source
        ├── FilePlayer.swift     ← --play: stream an audio file to one duck
        └── DAWInput.swift       ← Mode 1 multichannel audio input

bambu/firmware/              ← the duck firmware (Bambu duck + BOYBAND flavor)
├── Makefile                 ← `make flash-boyband STAGE_URL=...`
└── main/
    ├── config.h             ← BOYBAND requires RELAY_BASE_URL
    ├── main.c               ← BOYBAND puppeteer loop (auto-connect, no wake)
    ├── audio.c              ← BOYBAND volume override (VOL_STEP)
    └── CMakeLists.txt       ← BOYBAND + RELAY_BASE_URL build flags

bambu/docs/FLASHING.md       ← general Bambu-duck flashing (web flasher, etc.)
```
