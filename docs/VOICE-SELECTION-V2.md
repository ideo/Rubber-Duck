# Voice Selection V2 — Score-Gated Architecture

Status: **In Progress** (playground testing)

## Problem

V1 asks a 3B on-device model to pick from 11 voices with only a text prompt for guidance.
Results: model hallucinates invalid voices ("stalwart"), over-selects special voices on neutral
content (good_news on "They haven't asked anything yet"), and uses jester way too often.

## Key Insight

We already have eval scores (rigor, craft, novelty, ambition, risk → sentiment).
Many voice choices are **mathematically deterministic** — bad_news should never fire when
scores are positive. The LLM should only decide when the scores leave room for ambiguity.

## Architecture

```
Eval Scores → Score Gates (math) → Candidate Pool → LLM picks from pool
                                    ↑ always includes superstar
```

1. **Score gates** produce a candidate pool (2-4 voices max)
2. If pool is just `[superstar]` → skip LLM entirely, use superstar
3. If pool has 2+ options → LLM picks from ONLY those voices
4. Validation layer: if LLM outputs a voice not in pool → fallback to superstar

## Voice Categories

### Hard-Gated (score math, no ambiguity)

| Voice | Gate | Rationale |
|-------|------|-----------|
| good_news | sentiment > 0.6 | Only on clearly positive work |
| bad_news | sentiment < -0.4 | Only on clearly negative work |
| ralph | risk > 0.7 | Only when something dangerous happened |
| organ | ambition > 0.7 | Only on massive scope changes |
| bubbles | ambition > 0.8 AND risk > 0.8 | Ultra rare — voice is nearly unintelligible |

### Soft-Gated (score threshold + LLM picks)

| Voice | Gate | Rationale |
|-------|------|-----------|
| cellos | novelty > 0.6 AND abs(ambition) > 0.5 | "Big surprise" — novel AND notably scoped |
| trinoids | craft < -0.3 AND novelty < -0.3 | Mechanical, unoriginal grinding |
| zarvox | craft < -0.3 AND novelty < -0.3 | Cold, calculating (same gate as trinoids, LLM picks between) |

### LLM-Only (always in pool, purely vibes)

| Voice | Rationale |
|-------|-----------|
| superstar | Default. Always available. 80% of the time. |
| whisper | "Secrets/private thoughts" — content-based, scores can't detect |

### Removed

| Voice | Reason |
|-------|--------|
| jester | Over-eager, unintelligible on long sentences. Dumped entirely. |

## Sentiment Formula

```
sentiment = rigor * 0.3 + craft * 0.25 + novelty * 0.2 + ambition * 0.15 - risk * 0.1
```

## Open Questions

- Cellos gate: is `novelty > 0.6 AND abs(ambition) > 0.5` the right "surprise" formula?
- Organ + cellos can both qualify simultaneously (high ambition + high novelty) — LLM picks between them. Is that right?
- Trinoids vs zarvox: same gate, different flavor. Worth keeping both or merge?
- Whisper: no gate at all — should there be a soft one (e.g. low ambition + low risk)?

## Testing

Playground: `widget/Playground/Sources/LLMPlayground/VoicePickerPlayground.swift`
- "Gate Check" block: pure math, shows candidate pool per case
- "V2 Gated" block: full pipeline with LLM picking from gated pool
