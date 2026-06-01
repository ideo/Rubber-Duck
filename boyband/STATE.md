# Boy Band — State

Living status doc. Update in the same commit as the work it describes.

## Where we are

**🎉 FIRST REAL DUCK CONNECTED & ANIMATING (2026-06-01).** A physical
Bambu duck flashed with BOYBAND firmware connected to the Stage app
over WiFi and wobbled its head to a streamed sine. **The entire
pipeline works end-to-end on real hardware.** Read `OPERATIONS.md`
for the complete run/connect/flash guide — it captures every gotcha
from this bring-up.

Key facts from bring-up:
- Test duck MAC `dcb4d92961e9` → D1.
- Network: IDEO-Guest (WPA-PSK). **Had to bake the Mac's RAW IP**
  (`ws://10.5.128.41:3334`) into firmware — IDEO mDNS poisons
  `.local` hostnames with a corporate-pinned ghost IP that even a
  HUP flush won't clear. Hostname approach is dead on IDEO networks.
- BOYBAND firmware flavor added to `bambu/firmware/` (puppeteer mode:
  auto-connect, no wake gate, no notify, VOL_STEP boot volume). This
  is a deliberate, `#ifdef`-gated build — see "firmware" note below.
- The firmware branch was **merged into feature/boy-band** — all boy
  band work (Stage + firmware + docs) now lives on ONE branch.

**Week 1 — Stage skeleton verified end-to-end (in software).**
**Week 2 — Production routing + Mode 1 skeleton landed.** Branch
`feature/boy-band`.

Stage CLI builds and runs, accepts WebSocket upgrades on:
  - `/ws/duck` + `X-Duck-Id: <MAC>` header (real firmware path,
    routed via `duck-map.local.json`)
  - `/duck/{D1..D4}` (test/dev shortcut, used by fake-duck.py)

Both paths verified with the test matrix in commit history.
Rejected connections (unknown MAC, missing header, no map loaded)
produce clear HTTP responses and helpful stderr lines telling the
operator what to fix.

**Mode 1 input skeleton** present (`DAWInput.swift`): finds a 4+ch
CoreAudio input device, taps audio, converts to int16 @ 16 kHz,
demuxes 4 channels into 4 ducks. CLI flag `--mode1 --input-device
BlackHole`. **One known limitation**: macOS 26 doesn't expose the
"set explicit input device" API to Swift, so for now Stage captures
from whichever device is the system default input. Workflow at the
venue: set BlackHole 4ch as system default input in System
Settings → Sound → Input before starting Stage. Full fix is to
rewrite around AUHAL (~80 lines) — flagged as TODO in the source.

**End-to-end protocol verified** with `boyband/scripts/fake-duck.py`:
fake duck connects, Stage broadcasts sine, fake duck writes WAV.
Zero-crossing analysis confirms 329.5 Hz on D2 (expected E4 =
329.6 Hz) at 0.20 amplitude. Every byte on the wire is correct.

**Hardware not yet tested.** If a real duck fails after this, the
problem is firmware/I2S/speaker, not Stage.

**🎉 TWO DUCKS CONNECTED SIMULTANEOUSLY (2026-06-01).** Mallard (D1,
duck_id `dcb4d92961e9`) and Pekin (D2, duck_id `dcb4d9296125`) both
flashed BOYBAND, both on IDEO-Guest, both holding live Stage
connections at once. Multi-duck foundation proven on hardware.
Multi-`--play` routes distinct audio per duck (verified in software
via two fake-ducks). Have NOT yet played different audio out the two
physical ducks at once (gated on noise tolerance, not on unknowns).

Two hardware learnings (also in MEMORY.md):
- **duck_id = SoftAP MAC = base MAC + 1.** esptool reports base MAC;
  duck-map needs base+1. (Pekin base `…6124` → duck_id `…6125`.)
- **Copy WiFi creds duck→duck via NVS dump** — no phone/portal:
  `esptool read_flash 0x9000 0x6000` then `write_flash 0x9000` to the
  target. Safe (duck_id is efuse-derived, not NVS). Used to give Pekin
  Mallard's IDEO-Guest creds.

**Real-audio path built (`--play FILE [DUCK] [--loop]`).** New
`FilePlayer.swift` decodes any audio file (wav/aiff/mp3/m4a),
resamples once to 16k/mono/int16 via AVAudioConverter, and paces it
at 20ms so the duck buffer can't overflow. Verified end-to-end into
`fake-duck.py`: a 48k/stereo/24-bit system sound came out clean 16k
mono, real varying audio. **Not yet played out the physical duck**
(awaiting a moment where a whisper of sound is OK — boot vol is
still VOL_STEP=3). fake-duck.py also made version-robust across
websockets header-kwarg rename.

## Next up

1. **Hardware smoke test.** Plug in one real Bambu Duck. Find its
   MAC (see `docs/duck-id-mapping.md` for three ways). Copy
   `duck-map.example.json` → `duck-map.local.json`, fill in that
   one MAC as D1. Point the duck's NVS `relay_url` at
   `ws://<mac>.local:3334`. Reboot. Run `swift run BoyBandStage
   --sine` from `boyband/stage`. Listen for a C4 tone and watch the
   head wobble.
2. **Install BlackHole 4ch + first DAW round-trip** (once #1 works).
   `brew install blackhole-4ch`; set as system default input;
   `swift run BoyBandStage --mode1`; play a 4-channel test bounce
   from Logic.
3. **Audition voices.** Pick 4 ElevenLabs voice_ids with distinct
   characters that survive over a PA. Record IDs + notes in
   `boyband/voices.json` (file to be created).
4. **Begin orchestrator (Week 3 work)** — Anthropic streaming
   client + ElevenLabs streaming TTS → Stage's existing per-duck
   `sendPCM`. Mic + PTT can wait until orchestrator works in a
   text-input dry-run.

## Resolved decisions

- ~~Duck ID mapping~~. **Resolved 2026-05-28**: MAC → slot via
  `duck-map.local.json` (gitignored, per-Mac). Stage accepts both
  `/ws/duck` + X-Duck-Id (production) and `/duck/{ID}` (test). Zero
  firmware change. Full rationale + workflow in
  `docs/duck-id-mapping.md`.

## Open decisions blocking work

- Show topic / script outline (blocks Mode 1 authoring, not Week 1
  infra).
- Venue + PA setup (blocks Week 4 rehearsal planning; can defer).
- Personas + names for the four ducks (blocks Week 3 orchestrator
  prompt; can be drafted as placeholders earlier).

## Done

- [x] Branch created
- [x] Plan written (`PLAN.md`)
- [x] CLAUDE.md / collaborator working agreement
- [x] Doc skeleton (api-keys, stage-protocol stub, orchestrator
      contract + persona placeholders, show-runbook skeleton)
- [x] Stage SwiftPM project (`boyband/stage/`) — builds clean
- [x] Multi-duck WebSocket server with binary PCM send
- [x] Sine generator (`--sine [DUCKID]`) for sound check
- [x] CLI args, signal handling, graceful shutdown
- [x] `boyband/scripts/fake-duck.py` — pretends to be a duck, captures
      inbound PCM to WAV, exercises text + binary frame paths.
      Updated with `--mac` flag to exercise production /ws/duck route.
- [x] End-to-end protocol verification (sine round-trip → WAV →
      frequency confirmed)
- [x] `docs/stage-protocol.md` — upgraded from stub to authoritative
      contract, cross-checked against duck_proxy.py + agent.c
- [x] `docs/duck-id-mapping.md` + Stage `/ws/duck` + X-Duck-Id route
      + `DuckMap` config (resolved the multi-duck rehearsal blocker)
- [x] `DAWInput.swift` — Mode 1 CoreAudio input skeleton (4ch device
      discovery, tap, format conversion, demux, per-duck PCM send).
      One TODO: explicit device selection (works around via system default).
- [x] `--list-inputs` CLI flag for device discovery

## Not yet started

- [ ] First real-hardware smoke test (one duck plays sine)
- [ ] `boyband/voices.json` (voice catalog)
- [ ] BlackHole-installed end-to-end DAW test
- [ ] AUHAL rewrite of DAWInput (explicit device selection)
- [ ] Orchestrator client + ElevenLabs TTS streaming (Mode 2, Week 3)
- [ ] Mic + PTT + interrupt (Week 3-4)
- [ ] Hotkeys + mode flip + `/health` endpoint (Week 4)
- [ ] Personas + show content (Devin + Jenna co-write)

## Risk log

| Risk | Likelihood | Mitigation |
|---|---|---|
| WiFi flakey at venue | Medium | Bring our own travel router; have Mode 1 stems pre-loaded on Mac local |
| ElevenLabs latency spikes in Mode 2 | Medium | Pre-render a fallback pool; Mode 1 hotkey flip |
| One duck dies on stage | Low–Medium | Mute that channel; show continues; have a spare duck and a spare USB-C cable in the kit |
| Operator forgets the hotkeys | Low | Cheat-sheet card taped to laptop; rehearse to muscle memory |
| Audience mic feedback | Medium | Push-to-talk only; auto-gate while ducks speak |
| Voice IDs sound too similar | Medium | Audition over actual PA in Week 1, not headphones |
