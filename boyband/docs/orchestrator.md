# Mode 2 — Orchestrator contract

The orchestrator is the LLM that turns one audience question into a
multi-duck scripted response. Stage app calls it; it streams JSON
back; Stage hands each line to TTS as it arrives.

## Status

Skeleton. Persona content to be co-written with Jenna in Week 3.
What's here is the *shape* and the rationale — fill in the
personalities, leave the schema alone unless there's a strong reason.

## Model + provider

- **Provider:** Anthropic API.
- **Model:** Claude Sonnet 4.x (latest at build time).
- **Streaming:** yes. Output is line-delimited JSON; parse and act
  per line.
- **Max tokens:** 1024 (one short panel exchange).
- **Temperature:** 0.8 (we want personality, not consistency).

## Input

```json
{
  "question": "<transcribed user question>",
  "history": [
    {"role": "user", "text": "..."},
    {"role": "duck", "duck": "D2", "text": "..."}
  ]
}
```

History is the last ~6 turns so callbacks land. Keep it short — this
is a live show, not a transcript-builder.

## Output (streamed, line-delimited JSON)

```json
{"main":     {"duck": "D2", "line": "Oh, *finally*, a real question."}}
{"reaction": {"duck": "D4", "clip": "ohhh"}}
{"main":     {"duck": "D1", "line": "...I hate it here."}}
{"reaction": {"duck": "D3", "clip": "mhm"}}
{"main":     {"duck": "D3", "line": "Yeah. I hate it here too."}}
{"end": true}
```

Rules the model **must** follow (reinforce in the system prompt):

- One JSON object per line, no array wrapper, no trailing commas.
- `main.line`: 1–2 sentences, max ~25 words. Spoken English. No
  markdown, no asterisks for emphasis, no stage directions in
  brackets. Punctuation OK for prosody.
- `reaction.clip`: must be one of the allowed clip names in
  `stems/backchannel/<voice>/`. The system prompt enumerates them.
- Each panel response: 3–6 `main` lines total. Long answers kill
  energy.
- Final line is `{"end": true}`.

## Personas — placeholders to be replaced

| Duck | Stage position | Working name | Schtick |
|---|---|---|---|
| D1 | Far left | TBD | The cynic / sarcasm / refuses to be impressed |
| D2 | Center-left | TBD | The earnest one / over-explains / loves the bit |
| D3 | Center-right | TBD | The agreer / piles on whoever spoke last / no spine |
| D4 | Far right | TBD | The weird one / speaks in metaphors / non-sequiturs |

Co-write these with Jenna. Keep the contrasts sharp — over a PA
with a live audience, subtle character differences disappear. The
audience should be able to tell who's speaking within one second of
voice + position.

## System prompt (skeleton)

```
You are scripting a 4-duck boy band's response to an audience question
at a live show. The ducks are rubber ducks on a desk; they have
personalities but are not pretending to be human.

The four ducks:
- D1 ({{name}}): {{persona}}
- D2 ({{name}}): {{persona}}
- D3 ({{name}}): {{persona}}
- D4 ({{name}}): {{persona}}

Output JSON, one object per line. See the schema above. Stay in
character. Be brief and funny. Don't lecture. Refusals — if a
question is hostile or inappropriate, deflect in character (the
cynic mocks it, the earnest one misses the point, etc.) — never
break the bit.

Question: {{question}}
```

## Backchannel clips library

To be pre-rendered in Week 3. Plan ~20 clips per duck. Suggested
starter list (per voice):

- `mhm`, `mhm_long`, `yeah`, `nooo`, `wow`, `ohhh`, `ha`, `ha_short`,
  `excuse_me`, `wait_what`, `boring`, `keep_going`, `say_more`,
  `disagree`, `agree`, `oof`, `groan`, `gasp`, `applause`, `sigh`.

Stored at `stems/backchannel/{D1,D2,D3,D4}/{clip}.wav`. Stage knows
the catalog at startup (just scans the directory).

## Fallback content (pre-rendered, no LLM call)

For when STT fails / LLM stalls / network is sick:

- `stems/fallback/didnt_catch_that/{D1..D4}.wav` — "Sorry, didn't
  catch that" in each voice.
- `stems/fallback/conferring/{D1..D4}.wav` — "Hold on, we're
  conferring".
- `stems/fallback/next_question/{D1..D4}.wav` — graceful punt.

Stage picks one at random when triggered. Always available, even
offline.

## Don't over-engineer this

The orchestrator is a single API call per question. No retries on
content (only on transport errors). No "agentic" multi-step
reasoning. If the response is bad, the operator hits interrupt and
moves on. A live show forgives a flub way more than it forgives a
20-second pause.
