# Stage — Boy Band's local fake relay

Headless macOS CLI. Impersonates the Bambu relay so 4 ducks can be driven
from one Mac for a live performance. Zero external dependencies (Network.framework + CryptoKit + AVFoundation).

See `../PLAN.md` for the why, `../docs/stage-protocol.md` for the wire
format, `../docs/duck-id-mapping.md` for how each duck knows its slot.

## Build + run

```sh
cd boyband/stage
swift run BoyBandStage --help
```

Common invocations:

```sh
# idle — server up, waiting for ducks
swift run BoyBandStage

# Sound check — send sine to every connected duck (different pitch each)
swift run BoyBandStage --sine

# Solo D2 with sine, others silent
swift run BoyBandStage --sine D2

# Different port (e.g. if 3334 is taken)
swift run BoyBandStage --port 3344

# List available audio input devices (find your BlackHole here)
swift run BoyBandStage --list-inputs

# Mode 1 — read 4 channels from BlackHole (or any 4+ ch input) and route to ducks
swift run BoyBandStage --mode1

# Mode 1 with explicit device name match
swift run BoyBandStage --mode1 --input-device "BlackHole 4ch"

# Disable the production /ws/duck path; only accept /duck/{ID} test connections
swift run BoyBandStage --no-duck-map
```

## Wiring a duck to talk to Stage

The Bambu duck firmware reads its relay URL from NVS at boot, then opens
`<relay_url>/ws/duck` with an `X-Duck-Id: <chip MAC>` header. To wire it
to Stage:

1. **Find the duck's MAC.** Three ways, in `../docs/duck-id-mapping.md`.
2. **Create the MAC→slot map.** Copy `../duck-map.example.json` to
   `../duck-map.local.json` (gitignored) and fill in the MACs of your
   physical ducks, one per slot D1..D4.
3. **Point the duck's NVS relay_url** at this Mac:
   - Hostname: `hostname -s` (e.g. `mybox.local`) — works if the duck
     can do mDNS resolution. Or use `ipconfig getifaddr en0` for the
     LAN IP.
   - Write `ws://<thismac>.local:3334` to NVS via the duck's
     onboarding wizard or `relay_url_save` API. **Plain `ws://`, not
     `wss://`.**
4. **Reboot the duck.** Stage logs `connect Dn  id=…` on success, or
   `reject MAC=… — not in duck-map` if the MAC isn't in your map yet.

## Status

What works today (Week 1 + most of Week 2):

- Listens on `ws://0.0.0.0:3334/`, accepts WS upgrades on:
  - `/ws/duck` + `X-Duck-Id: <MAC>` header (real firmware path,
    routed via duck-map)
  - `/duck/{D1..D4}` (test/dev shortcut, used by `fake-duck.py`)
- `DuckMap` loaded from `duck-map.local.json` (gitignored)
- Tracks 4 connections; reconnects replace stale entries
- Binary PCM send (`DuckConnection.sendPCM(_:)`)
- Text JSON send (`DuckConnection.sendJSON(_:)`)
- Sine generator (`--sine`) for sound check
- **Mode 1 input skeleton** (`--mode1`) — taps CoreAudio input,
  converts to int16 @ 16 kHz, demuxes 4 channels into 4 ducks
- `--list-inputs` to enumerate available audio devices
- Logs connect / disconnect / inbound text / reject reasons

What's stubbed or limited:

- **DAWInput device selection.** Currently uses system default input
  (macOS 26 doesn't expose the per-AVAudioEngine device-selection API
  to Swift). Workaround at the venue: set BlackHole 4ch as system
  default input in System Settings → Sound → Input. TODO in source is
  the AUHAL rewrite (~80 lines) for explicit selection.
- LLM orchestrator + ElevenLabs TTS (Mode 2, Week 3)
- Mic + PTT + interrupt (Mode 2, Week 3-4)
- Hotkeys + mode flip (Week 4)
- `/health` HTTP endpoint (Week 4)

## File map

- `Package.swift` — SwiftPM, macOS 26, language mode 5 (matches widget)
- `Sources/BoyBandStage/main.swift` — entry, CLI args, signal handling
- `Sources/BoyBandStage/StageServer.swift` — multi-duck WebSocket server
- `Sources/BoyBandStage/DuckMap.swift` — MAC → DuckID config loader
- `Sources/BoyBandStage/SineGenerator.swift` — sound-check test source
- `Sources/BoyBandStage/DAWInput.swift` — Mode 1 multichannel input
