# Boy Band

Four Bambu Ducks performing live as a boy band. One-time show.

## Quick links

- **`CLAUDE.md`** — AI assistant context. Read this first if you're
  an LLM (Claude or otherwise).
- **`PLAN.md`** — the plan, architecture, and week-by-week schedule.
- **`STATE.md`** — living status. Update with each commit.
- **`docs/show-runbook.md`** — physical setup and cue sheet for show
  day. (Filled in Week 4.)
- **`docs/stage-protocol.md`** — wire format between Stage app and
  duck firmware. (Mirrors Bambu relay's `/ws/duck`.)
- **`docs/orchestrator.md`** — Mode 2 LLM contract and persona
  prompts.
- **`docs/api-keys.md`** — where keys live. **Never put real keys
  in this repo.**

## TL;DR

Two performance modes, one Mac, four ducks on a local WiFi.

- **Mode 1 (Piano roll):** A DAW plays a pre-rendered 4-track bit.
  Stage app routes each channel to one duck. Safe / always-works
  fallback.
- **Mode 2 (FAQ):** Audience mic → STT → orchestrator LLM → 4-voice
  ElevenLabs TTS → Stage → ducks. They debate the answer in
  character.

Stage app pretends to be the Bambu relay locally. **No firmware
changes** — ducks get pointed at `ws://stage.local:3334` via NVS.

## Who's working on this

Devin Deruntz and Jenna Fizel. Either may drive an AI assistant on
this branch with equal authority. See `CLAUDE.md` for the working
agreement.

## Status

See `STATE.md`.
