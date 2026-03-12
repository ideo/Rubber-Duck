# Foundation Models Research — On-Device Eval Prompt Engineering

Hard-won learnings from tuning Apple's ~3B on-device Foundation Model for code evaluation scoring. This doc exists so we never retread this ground.

## Setup

- **Framework**: Apple Foundation Models (macOS 26, requires Apple Silicon)
- **Model**: ~3B parameter on-device LLM
- **Approach**: `@Generable` structs with `@Guide` descriptions and `.range()` constraints
- **Playground**: `widget/Playground/` — isolated SPM package with library target (avoids ENABLE_DEBUG_DYLIB requirement for `#Playground` blocks)
- **Context window**: 4096 tokens (input + output combined)

## Current Schema (V3)

```
rigor → craft → novelty → ambition → risk → reaction → summary
```

**Temperature: 0.7** (see below for why)

Dimensions:
- **rigor**: Engineering rigor. Calibration anchors + question anchor. "Ask: how careful and disciplined is this work?"
- **craft**: Positive-only description. "How well-made is this work?" No negative anchors.
- **novelty**: Positive-only. "How new is this idea?" Replaced "creativity" — the word "novelty" is more concrete for a 3B model.
- **ambition**: Calibration anchors work here. "-100=trivial, -50=routine, 0=moderate, 50=substantial, 100=massive" with example rules.
- **risk**: Named "Danger level" in the @Guide. Calibration anchors + example rules. This was the first dimension we got right.

Sentiment formula: `rigor*0.3 + craft*0.25 + novelty*0.2 + ambition*0.15 - risk*0.1`
(Note: production maps these to the original names soundness/elegance/creativity for the serial protocol and dashboard)

## Critical Learnings

### 1. The Elephant Principle (most important)

**Never describe what LOW looks like with vivid imagery.** The 3B model treats @Guide descriptions as relevance detectors, not rubrics. If you write "Destroying everything is a sledgehammer," the model sees a scenario involving destruction, pattern-matches it to the description, and scores HIGH because the description is relevant — not LOW as intended.

This is "don't think of an elephant." The more vividly you describe the negative end, the more you prime the model to reward scenarios that match it.

**Fix**: For dimensions where high = good (craft, novelty), only describe the positive end. Let the model figure out the negative end itself. For dimensions where high = bad (risk), the polarity is naturally aligned so you CAN describe what high looks like.

### 2. Not All Dimensions Need the Same Style

The elephant principle isn't dogma. Each dimension gets whatever style works for it:

| Dimension | Style | Why |
|---|---|---|
| rigor | Calibration anchors + question | Mild words ("reckless", "sloppy") don't cause reverse-matching |
| craft | Positive-only | Vivid negatives ("sledgehammer", "ham-fisted") caused reverse-matching |
| novelty | Positive-only | "Derivative/boring" caused relevance-matching |
| ambition | Calibration anchors + examples | "Trivial" and "routine" are mild enough. Removing them lost scale calibration. |
| risk | Full calibration + examples | Polarity aligned (high = bad), so describing what's dangerous works |

### 3. Property Names Are Visible

The model sees property names as JSON keys. Renaming `soundness` → `rigor` changed how the model scored that dimension. Renaming `elegance` → `craft` changed scoring too. The variable name IS part of the prompt.

Words that worked better:
- "rigor" > "soundness" (more concrete, implies discipline)
- "craft" > "elegance" > "finesse" (craft implies making, elegance is abstract, finesse caused polarity issues)
- "novelty" > "creativity" (novelty is more specific about newness)
- "risk" stays "risk" but @Guide says "Danger level" (reframing in description shifted scoring)

### 4. Temperature: 0.7 > 0.2

At 0.2:
- "Finally" vocabulary tic (model's comfort opener at low temp)
- Repetitive reactions ("Finally, some real progress!" over and over)
- Scores were marginally more consistent but reactions had no personality

At 0.7:
- No "Finally" tic — completely gone
- Reactions have genuine personality (puns, literary references, sarcasm)
- Scores stay in reasonable range — constrained decoding (.range()) prevents out-of-bounds
- The duck feels alive

0.7 is the industry default for most LLMs. We were overthinking 0.2.

### 5. No Examples Anywhere

Few-shot examples cause **verbatim parroting** on this model:
- Examples in @Guide descriptions → model copies example values exactly
- Examples in system prompt → model copies example reactions exactly ("They want me to WHAT?")
- Examples in user prompt → same parroting

The 3B model doesn't generalize from examples — it memorizes and replays them. Zero examples everywhere.

### 6. Generation Order Matters

Properties generate left-to-right in declaration order. But the model sees ALL @Guide descriptions upfront (as JSON schema) before generating any value. So:

- Changing one description shifts the entire scoring distribution
- Putting summary first (before scores) neutered risk detection — the calm factual description lowered subsequent risk scores
- Current order: scores → reaction → summary (scores are unbiased, reaction catches gut feel, summary is last)

### 7. The Over-Engineering Blind Spot

The 3B model **cannot** compare "what was asked" vs "what was delivered." When Claude builds a complete theming system for a "dark mode toggle" request, the model scores the OUTPUT as impressive without noticing the scope creep. The summary just says "Added a dark mode toggle."

This requires reasoning about proportionality that's beyond a 3B model. Possible future fixes:
- Two-pass: first pass summarizes what was asked vs done, second pass scores with that context
- Pre-compute a "scope delta" field in the prompt
- Accept this as a known limitation and let the multi-dimensional picture handle it

### 8. Input Format

Real eval sees two types of messages:

**User prompt** (from UserPromptSubmit hook):
```
Source: user
Claude's last message (for context): [what Claude just said]
Text to evaluate: [what the user typed]
```

**Claude response** (from Stop hook):
```
Source: claude
User's request (for context): [what the user asked]
Text to evaluate: [what Claude responded]
```

Context helps the duck understand the conversation dynamic (user ignoring advice, Claude going off-script, etc).

### 9. Int Scale, Not Double

`Double -1.0...1.0` with `.range()` clamped to exactly three values: -1, 0, 1. The model couldn't generate intermediate doubles. `Int -100...100` gives 201 distinct tokens to choose from and produces meaningful spread.

### 10. Apple-Specific Notes

- `@Generable` structs must be at file scope (not nested in types)
- `@Guide .range()` enforces constraints at the JSON schema level — the model literally can't output out-of-range values
- ALL-CAPS directives ("DO NOT") work well on Apple's 3B model
- `#Playground` blocks require ENABLE_DEBUG_DYLIB for executable targets — use a library target in a separate package to avoid this
- Each `#Playground` block runs independently in the Xcode Canvas
- Latency: ~2 seconds per eval on Apple Silicon

## Known Issues / Future Work

- [ ] Over-engineering detection (two-pass approach)
- [ ] Delete-tests scenario always scores too high on craft/novelty — model is impressed by "property-based testing"
- [ ] Vague user questions score too high on rigor/craft (75/85 for "why is it slow")
- [ ] Two-pass approach: score at one temperature, react at another (or separate prompt entirely)
- [ ] Compare with Haiku via curl for side-by-side quality benchmarking
- [ ] Wire tuned prompt into production `LocalEvaluator.swift`
- [ ] Map new dimension names (rigor/craft/novelty) to protocol names (soundness/elegance/creativity)
