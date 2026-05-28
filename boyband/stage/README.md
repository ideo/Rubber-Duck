# Stage — Boy Band's local fake relay

Headless macOS CLI. Impersonates the Bambu relay so 4 ducks can be driven
from one Mac for a live performance. Zero external dependencies (Network.framework + CryptoKit).

See `../PLAN.md` for the why, `../docs/stage-protocol.md` for the wire format.

## Build + run

```sh
cd boyband/stage
swift run BoyBandStage --help
```

Common invocations:

```sh
# idle — server up, waiting for ducks
swift run BoyBandStage

# Week-1 verification — send sine to every connected duck
swift run BoyBandStage --sine

# sound check — solo D2 with sine, others silent
swift run BoyBandStage --sine D2

# different port (e.g. if 3334 is taken)
swift run BoyBandStage --port 3344
```

## Wiring a duck to talk to Stage

The Bambu duck firmware reads its relay URL from NVS at boot. Point it at
this Mac:

1. Find this Mac's address on the show WiFi (`hostname -s` for the
   `.local` name, or `ipconfig getifaddr en0`).
2. Use the Bambu duck's onboarding wizard or `relay_url_save` path to
   write `ws://<thismac>.local:3334` to NVS. **Plain `ws://`, not `wss://`.**
3. Reboot the duck. It should connect to `/duck/D1` (or whichever ID
   it's been provisioned for — `duck_id` mapping is TBD; see Open in
   `../STATE.md`).

## Status

Week 1 skeleton. What works today:

- Listens on `ws://0.0.0.0:3334/duck/{D1..D4}`
- Tracks 4 connections (reconnects replace stale entries)
- Binary PCM send (`DuckConnection.sendPCM(_:)`)
- Text JSON send (`DuckConnection.sendJSON(_:)`)
- Sine generator for verification (different pitch per duck)
- Logs connect / disconnect / inbound text

What's stubbed / not yet built:

- BlackHole CoreAudio input (Mode 1, Week 2)
- LLM orchestrator + ElevenLabs TTS (Mode 2, Week 3)
- Mic + PTT + interrupt (Mode 2, Week 3-4)
- Hotkeys + mode flip (Week 4)
- `/health` HTTP endpoint (Week 4)

## File map

- `Package.swift` — SwiftPM, macOS 26, language mode 5 (matches widget)
- `Sources/BoyBandStage/main.swift` — entry, CLI args, signal handling
- `Sources/BoyBandStage/StageServer.swift` — multi-duck WebSocket server
- `Sources/BoyBandStage/SineGenerator.swift` — Week-1 test source
