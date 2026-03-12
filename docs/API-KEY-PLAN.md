# API Key Onboarding — Plan

Status: **implemented** — shipped in `f757a41` on `foundation-LLM` branch.

## Problem (solved)

Duck Duck Duck used to prompt for an Anthropic API key on first launch. This was a hard stop for casual users. The eval scoring system (Claude Haiku) required this key, so without it the duck was completely inert.

## What was implemented

Foundation Models is now the **default eval engine**. The app works immediately on first launch with zero configuration — no API key needed. Users can optionally switch to Anthropic API (Claude Haiku) from the menu bar for higher-quality scoring.

### How it differs from this plan

| This plan proposed | What was built |
|---|---|
| `EvalProvider` protocol with `HaikuProvider` / `FoundationProvider` conformances | Dual evaluator: `LocalEvaluator` actor + existing `ClaudeEvaluator`, dispatched by `DuckConfig.evalProvider` enum |
| Three-button first-launch dialog (Enter Key / Get Key / Try Without) | No dialog at all — Foundation Models is the default, API key prompt only appears when switching to Anthropic in the menu |
| `@Generable` with `Double -1.0...1.0` ranges | `Int -100...100` ranges (3B model can't generate intermediate doubles — see research doc) |
| Original dimension names (creativity, soundness, elegance) | V3 names (rigor, craft, novelty) mapped back to production names at output |
| `@available(macOS 26, *)` gating | `#if canImport(FoundationModels)` with stub actor fallback for Intel |

### Key files

| File | Role |
|---|---|
| `LocalEvaluator.swift` | `@Generable` struct with V3 tuned prompt + `LocalEvaluator` actor |
| `DuckConfig.swift` | `EvalProvider` enum (`.foundation` / `.anthropic`) persisted via UserDefaults |
| `DuckServer.swift` | Dual evaluator dispatch based on `DuckConfig.evalProvider` |
| `RubberDuckWidgetApp.swift` | Removed blocking API key prompt — only prompts if Foundation Models unavailable |
| `StatusBarManager.swift` | Eval provider radio section in menu bar |

## Original Options Considered

The plan evaluated four options (A–D). The implemented solution is closest to **Option C** (Foundation Models as default) but skipped the three-button dialog entirely — Foundation Models just works on launch, and the API key prompt only appears when the user actively switches to Anthropic in the menu.

See `docs/FOUNDATION-MODELS-RESEARCH.md` for the prompt engineering learnings that made this work.

## Resolved Questions

- **`.range()` on Double**: Does NOT work — 3B model clamps to {-1, 0, 1}. Solution: `Int -100...100` mapped to `Double -1.0...1.0` at output.
- **Latency**: ~2 seconds per eval on Apple Silicon. Fast enough, no loading indicator needed.
- **Quality floor**: Quality is good — the V3 tuned prompt produces usable scores with personality. Prompts are kept separate between Foundation Models and Anthropic API.
- **Intel Macs**: Foundation Models unavailable → app prompts for API key on launch (only case where the old behavior remains).
- **Permission options**: Unchanged — still yes/no/ordinal. Revisit separately.
