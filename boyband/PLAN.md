# Boy Band — Plan

A one-time live performance: four Bambu Ducks (`D1`–`D4`) on stage as a
boy band, doing a presentation about themselves. Two modes share one
downstream pipeline.

## Architecture at a glance

```
                               ┌─────────────────┐
   Mode 1 (DAW)                │   DAW (Logic)   │
                               │   4 channels    │
                               └────────┬────────┘
                                        │ via BlackHole
                                        ▼
   Mode 2 (FAQ)        ┌─────────────────────────────────┐
   mic→STT→LLM→TTS ───►│         Stage app (Mac)         │
                       │ - owns 4 websockets             │
                       │ - mode switch (DAW / FAQ)       │
                       │ - mic gate, interrupt, levels   │
                       └────────┬───┬───┬───┬────────────┘
                                │   │   │   │
                          ws://stage.local:3334/duck/{1..4}
                                │   │   │   │
                                ▼   ▼   ▼   ▼
                               D1  D2  D3  D4    (Bambu Duck firmware,
                                                  unchanged, NVS pointed
                                                  at ws://stage.local)
```

**Key invariant:** Stage talks to firmware over the **same protocol the
Bambu relay already speaks** — `pcm_16000` mono int16 over WebSocket
on `/ws/duck`. The firmware doesn't know it's talking to Stage instead
of the cloud relay.

## Mode 1 — Piano roll (the safe bet)

### Authoring (off-Mac)

1. Pre-render boy-band lines per duck via ElevenLabs streaming TTS
   (`eleven_v3` or `eleven_turbo_v2_5`, one voice_id per duck). Save
   as WAVs.
2. Drop the WAVs into Logic/Reaper/Ableton on tracks 1–4. Edit the
   bit: timing, overlaps, "uh-huh" backchannels, silences. Add any
   musical bed on extra tracks bussed to track 1 or wherever you
   want the "lead" duck to drive it.
3. Route DAW outputs 1, 2, 3, 4 → BlackHole 4ch (a free virtual
   audio device). Each duck = one channel.

### Playback (on-Mac via Stage)

- Stage opens BlackHole 4ch as a CoreAudio input.
- Reads 4 channels of `pcm_16000` (or downsamples from 44.1/48k —
  use AVAudioConverter, no exotic DSP).
- Per audio buffer, pushes channel `n` as PCM frames to duck `Dn`'s
  websocket.
- Master clock = DAW. Hit space, all four ducks play in sync.
- Latency target: <80ms DAW-to-speaker. WiFi UDP/WS over a local
  router will be ~10–30ms; rest is buffering.

### Why DAW-driven is the right call

We are not in the business of writing a piano-roll UI. Logic's region
editor, fade tool, and tempo grid will outclass anything we'd build
in 4 weeks. The DAW also gives us free: scrubbing, loops, automation,
recording reactions during rehearsal, and a familiar tool for Jenna
if they're authoring lines.

### Mode 1 acceptance test

Bounce a 30-second demo of one duck monologuing while the other
three throw in "mhm" / "ohhh" / "preach" at scripted offsets. All
four heads wobble in time with their own audio. No glitches over a
5-minute soak.

## Mode 2 — FAQ panel (the ambitious one)

### Pipeline

```
push-to-talk mic
   ↓ (CoreAudio)
STT (local Whisper.cpp, or ElevenLabs STT if latency wins)
   ↓ transcript
Orchestrator LLM (Claude Sonnet 4.x via Anthropic API)
   ↓ structured JSON, one line at a time (streamed)
Per-line: ElevenLabs streaming TTS, voice_id = duck's
   ↓ PCM frames
Stage's per-duck websocket
```

### Orchestrator contract

See `docs/orchestrator.md` for the full system prompt and persona
sheet. Output schema (streamed line-by-line):

```json
{"main":      {"duck": "D2", "line": "Oh, *finally*, a real question."}}
{"reaction":  {"duck": "D4", "clip": "mhm"}}
{"main":      {"duck": "D1", "line": "...I hate it here."}}
```

- `main` lines are full TTS; they play **serially** by default (one
  line, then the next).
- `reaction` lines reference a pre-rendered short clip in
  `stems/backchannel/{voice}/{clip}.wav`. They can fire **during**
  a main line on a different duck. Library is small (~20 clips ×
  4 voices = 80 files, all sub-2-second).

### Turn-taking

v1: strictly serial main lines, backchannel reactions allowed to
overlap. This is comprehensible and forgiving. Overlapping main
lines (real "argument") is a v2 stretch — only attempt if Week 3
has slack.

### Mic and interrupt

- **Push-to-talk** on a wired XLR / USB mic at the operator's
  station. Stage opens mic only while button is held. No open mic.
- **Auto-gate:** while any duck is sending PCM, mic input is
  discarded even if PTT is held — prevents the ducks from
  triggering each other. (Cheap, just a boolean.)
- **Interrupt:** dedicated hotkey (or USB foot pedal) cancels all
  active TTS streams and websocket sends within 50ms. Stage drains
  send buffers; ducks fall silent.

### Failure modes (designed-in, not afterthoughts)

| Failure | Stage's response |
|---|---|
| STT returns garbage / silence | Randomly-picked duck says "didn't catch that" from a pre-rendered fallback pool |
| LLM stalls >5s | "Hold on, conferring" fallback from another pool |
| TTS stream errors mid-line | Cut to next line in script; log; do not retry inline |
| WiFi drops to one duck | That duck is muted in mixer; show continues on three |
| Internet drops entirely (Mode 2 unusable) | Operator hits `Cmd+Shift+1` → Stage flips to Mode 1; pre-loaded filler stems play |
| Anything else weird | Operator hits interrupt; rolls Mode 1 from a known cue |

## Week-by-week schedule

### Week 1 — Stage skeleton + one-duck loop closed

- New Swift app `boyband/stage/` (SwiftPM, macOS 26, parity with the
  widget's build setup).
- Hard-coded single websocket server on `ws://0.0.0.0:3334/duck/D1`.
- Generate a 440Hz sine PCM frame, send continuously, verify the
  duck (with NVS relay URL flipped to `ws://stage.local:3334`)
  plays it and its head wobbles.
- **Done when:** one duck plays sine on demand from Stage.

### Week 2 — 4 ducks + DAW input + first show-able demo

- Generalize Stage to 4 simultaneous websockets, one per duck.
- BlackHole 4ch as the input source; per-channel routing.
- Bounce a 1-minute boy-band test from Logic. Play through Stage.
- Basic UI: 4 level meters, 4 mute buttons, mode toggle (DAW /
  FAQ — FAQ disabled for now), interrupt button.
- **Done when:** we have a 60s clip of all four ducks performing a
  bit, looks fun on video. **Show is now feasible even if Mode 2
  never ships.**

### Week 3 — Mode 2 orchestrator + serial TTS

- Mic + push-to-talk + STT pipeline.
- Orchestrator client: Anthropic API, streaming, line-by-line JSON
  parse, per-line ElevenLabs TTS streaming.
- Voices wired: `voices.json` maps `D1`–`D4` to ElevenLabs voice_id.
- Backchannel library: pre-render ~20 reactions × 4 voices into
  `stems/backchannel/`.
- Persona prompt v1 in `docs/orchestrator.md`. Iterate against
  ~30 sample questions written by Devin + Jenna.
- **Done when:** end-to-end Q&A works with <4s mouth-to-mouth latency.

### Week 4 — Show prep, dress rehearsal, failure drills

- `Cmd+Shift+1` mode-flip hotkey (FAQ → DAW filler).
- Interrupt foot pedal or hotkey.
- Show-runbook walkthrough (`docs/show-runbook.md`): cabling,
  power, WiFi setup, sound check sequence, what to do if X.
- Latency tuning, voice-stability tuning, persona prompt
  adjustments.
- Full dress rehearsal at the venue (or a venue-like room) with
  real audience-sized PA. Test heckler scenarios.
- **Done when:** we ran the show end-to-end twice without
  intervention, plus once with a deliberate failure injected.

## Open questions

These need answers from Devin / Jenna before the week they touch:

1. **Voices.** Four ElevenLabs voice_ids picked, with distinct
   characters that survive over a PA. *(Week 1 task to start
   auditioning.)*
2. **Personas.** Each duck's name, tone, schtick, and how they
   relate to the other three. *(Week 3 input.)*
3. **The bit.** What is the actual content of the Mode 1 piano-roll
   performance? Length? Songs? Story? *(Authoring happens Week 2,
   but topic needed earlier.)*
4. **Venue + audio chain.** Where is this performed? Is there a PA?
   Are ducks individually mic'd into FOH, or do they project
   acoustically? Affects WiFi reliability and whether we need
   in-ear monitors for the operator. *(Week 4 critical.)*
5. **Stage positions and labels.** Visible name cards under each
   duck? Lighting cues per duck on speak? *(Nice-to-have, Week 4.)*
