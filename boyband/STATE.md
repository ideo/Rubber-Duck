# Boy Band — State

Living status doc. Update in the same commit as the work it describes.

## Where we are

**Week 1 — Stage skeleton verified end-to-end (in software).**
Branch `feature/boy-band`. Docs scaffolded. Stage CLI builds and
runs, listens on `ws://0.0.0.0:3334/duck/{D1..D4}`, handshakes
WebSocket per RFC 6455, sends binary PCM and text JSON, generates a
per-duck sine for sound check (`--sine` flag).

**End-to-end protocol verified** with `boyband/scripts/fake-duck.py`:
fake duck connects, Stage broadcasts sine, fake duck writes WAV.
Zero-crossing analysis confirms 329.5 Hz on D2 (expected E4 =
329.6 Hz) at 0.20 amplitude. Every byte on the wire is correct.

**Hardware not yet tested.** If a real duck fails after this, the
problem is firmware/I2S/speaker, not Stage.

## Next up

1. **Hardware smoke test.** Point one real Bambu Duck's NVS
   `relay_url` at `ws://<mac>.local:3334`, reboot it, confirm it
   connects to `/duck/D1` and plays a steady C4 sine when Stage is
   run with `--sine`. If the head doesn't wobble, that's a wire
   format mismatch — re-cross-check with `bambu/relay/duck_proxy.py`.
2. **Cross-check `docs/stage-protocol.md`** against actual observed
   frames once a duck is connected. Replace the stub with concrete
   shapes seen on the wire.
3. **Audition voices.** Pick 4 ElevenLabs voice_ids with distinct
   characters that survive over a PA. Record IDs + notes in
   `boyband/voices.json` (file to be created).
4. **Open question — duck ID mapping.** Right now Stage routes by
   URL path (`/duck/D1`). The firmware needs to know which ID it
   is. Either bake it into NVS at provisioning time (preferred), or
   have Stage assign on first-connect. Decide before Week 2 because
   multi-duck rehearsal can't start until this is solved.

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
      inbound PCM to WAV, exercises text + binary frame paths
- [x] End-to-end protocol verification (sine round-trip → WAV →
      frequency confirmed)

## Not yet started

- [ ] First real-hardware smoke test (one duck plays sine)
- [ ] `boyband/voices.json` (voice catalog)
- [ ] `docs/stage-protocol.md` upgrade from stub to confirmed-on-wire
- [ ] BlackHole input adapter (Mode 1, Week 2)
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
