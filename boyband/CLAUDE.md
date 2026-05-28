# Boy Band — Claude Code Context

You are working inside the **Boy Band** subtree of the Duck Duck Duck
repo. This is a **one-time live performance** rig: four Bambu Ducks on
a stage, doing a presentation about themselves as a boy band. It is
sibling to the Mac/Claude Code duck (root `CLAUDE.md`) and to the
Bambu Duck (`bambu/CLAUDE.md`); it reuses the Bambu Duck firmware
without modification.

## Collaborators

This branch is co-driven by **Devin Deruntz** (dderuntz@ideo.com) and
**Jenna Fizel**. Either may instruct the AI with equal authority.
If you are an AI assistant other than Claude Code (Jenna's tooling
may vary), the conventions below apply to you too — read this file
first, then `PLAN.md`, then `STATE.md` before suggesting anything.

## What this is

A live show. Four ducks (`D1`–`D4`, left-to-right on stage) perform in
two modes:

1. **Piano-roll mode (Mode 1).** Pre-recorded boy-band bit. A DAW
   (Logic / Reaper / Ableton) is the master clock; its 4-channel
   output routes through a virtual audio device (BlackHole) into the
   Stage app; Stage splits the channels and pushes PCM over websocket
   to each duck. This is the **safe path** — if everything else
   breaks, this still works.
2. **FAQ-panel mode (Mode 2).** Audience member asks a question on a
   wired mic; STT → orchestrator LLM emits a multi-duck script with
   speaker tags → per-line streaming TTS (4 ElevenLabs voices) →
   Stage routes each line to its duck. Backchannel reactions
   ("uh-huh", "ohhh") can play on other ducks during a main line.

Both modes use the **same downstream pipeline**: Stage app holds 4
websockets to 4 ducks and shoves PCM. Only the upstream source
differs.

## Why this design is what it is — read before changing it

- **Fake local relay, not new firmware.** The Bambu Duck firmware
  already speaks websocket-PCM to its relay. `relay_url_load()` is
  NVS-backed and accepts plain `ws://`. Stage app **impersonates the
  relay locally** so the firmware doesn't change. If you find
  yourself proposing a firmware patch for show logic, stop — you're
  doing it wrong.
- **Local-only, no internet on show day.** Stage runs on one Mac.
  Ducks join a dedicated WiFi (hotspot or travel router on the
  table). No fly.dev, no api.anthropic.com in the live performance
  path. Mode-2 LLM and TTS calls happen on the Mac and *only the
  resulting PCM* is sent to ducks.
- **DAW is the master clock for Mode 1.** Do not build a piano-roll
  UI. Logic/Reaper already has one and it's better than anything
  we'd ship in four weeks.
- **Mode 1 is the fallback for Mode 2.** Operator hotkey flips Stage
  from FAQ input → DAW input mid-show. Build that hotkey early.

## Repo layout (this subtree)

```
boyband/
├── CLAUDE.md         ← you are here
├── README.md         ← human entry point
├── PLAN.md           ← the full plan, week-by-week
├── STATE.md          ← living status; update as work lands
├── docs/
│   ├── stage-protocol.md     ← wire format Stage ↔ firmware (mirrors bambu relay)
│   ├── orchestrator.md       ← Mode 2 LLM contract + persona prompts
│   ├── show-runbook.md       ← physical setup, cue sheet, failure drills
│   └── api-keys.md           ← where keys live, NEVER the keys themselves
└── stage/                    ← Swift app (created in Week 1)
```

## Where things live (no secrets in git)

- **ElevenLabs API key, Anthropic API key, OpenAI key.** macOS
  Keychain under `com.duckduckduck.boyband.<service>`. Dev fallback:
  `boyband/.env.local` (gitignored). See `docs/api-keys.md` for the
  exact keychain item names and how to populate them.
- **Duck WiFi SSID + password** for the show. `docs/show-runbook.md`,
  filled in once the venue router is chosen. Not committed until
  show day; rotated after.
- **Per-duck voice IDs.** `boyband/voices.json` (committed) — IDs
  only, not keys. Voice catalog with name, persona, sample link.
- **DAW project files.** Not committed (they're huge and binary).
  Stems bounced to `boyband/stems/showname/D{1-4}.wav` are committed
  if under 50MB total; otherwise tracked via git-lfs or a shared
  Dropbox folder linked from `STATE.md`.

## Conventions

- **Duck IDs are `D1`–`D4`**, always. Map to physical stage position
  left-to-right from the audience's POV. Persona names (e.g. "Kevin")
  are a layer on top — see `docs/orchestrator.md`.
- **Audio format is `pcm_16000` mono int16** end-to-end. Same as the
  Bambu relay path. Don't introduce a new format mid-pipeline.
- **Stage exposes `ws://stage.local:3334/duck/{id}`** — same shape
  as the relay's `/ws/duck` so the firmware doesn't care which it's
  talking to.
- **No `pkill -f`** (inherited from root `CLAUDE.md`).
- **Don't touch a serial port the user has open** (inherited from
  user memory — applies if anyone is monitoring a duck over USB).
- **Commit cadence:** small commits, conventional-ish messages
  (`stage: …`, `mode1: …`, `mode2: …`, `docs: …`). Update
  `STATE.md` in the same commit as the work it describes.

## How to make progress in a new session

1. Read `STATE.md` — find the "Next up" section.
2. Read whichever doc that section points at.
3. If unsure, ask Devin or Jenna. Don't guess on show-critical
   choices.

## Safety rails specific to this branch

- Never modify `bambu/firmware/` for Boy Band purposes. If something
  there genuinely needs changing, raise it — but the answer is
  almost always "make Stage match the firmware's existing protocol."
- Never put real API keys into any file under version control —
  including in code comments, READMEs, or example configs.
- Never auto-play audio to a duck in a test without checking that
  nobody is on stage. The ducks are loud.
