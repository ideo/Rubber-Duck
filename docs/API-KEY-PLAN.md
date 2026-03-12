# API Key Onboarding — Plan

Status: **planning** — not yet implemented.

## Problem

Duck Duck Duck prompts for an Anthropic API key on first launch. This is a hard stop for casual users who don't have one and don't know what it is. The eval scoring system (Claude Haiku) requires this key, so without it the duck is completely inert — no reactions, no scores, no personality.

## Current State

- First launch → `NSAlert` text field → "Enter your Anthropic API key"
- Key saved to `~/Library/Application Support/DuckDuckDuck/api_key`
- No explanation of what the key is, where to get one, or what it costs
- No way to use the app without a key

## Options

### Option A: Better dialog copy + "Get API Key" button

Lowest effort. Improve the prompt so a new user can self-serve:

- Explain what it is: "Duck Duck Duck uses Claude to evaluate your coding sessions."
- Explain cost: "Typical usage costs less than $1/month."
- Add "Get API Key" button → opens `console.anthropic.com` in browser
- Add "Skip for now" button → launches in degraded mode (see Option C)
- Keep the existing paste-key flow for users who already have one

### Option B: OAuth / token exchange

Not viable today. Anthropic doesn't offer OAuth for third-party apps. Parking this — revisit if they ship it.

### Option C: Degraded mode with Apple Foundation Models

Use Apple's on-device Foundation Models framework (macOS 26+) as a local eval engine when no API key is present. The ~3B parameter model is less capable than Haiku but enough to produce eval scores and reactions.

**What works without an API key (degraded mode):**
- Eval scoring on all 5 dimensions (creativity, soundness, ambition, elegance, risk)
- Gut-reaction quotes from the duck
- One-line summaries
- All widget animations, TTS, serial output
- Permission voice gate (doesn't need eval at all)

**What's worse in degraded mode:**
- Eval quality — smaller model, less nuanced scores
- Latency — on-device inference may be slower on older hardware
- Reaction personality — may be less witty/sharp than Haiku

**What's unchanged:**
- Voice input/output (Apple Speech, no API key needed)
- Permission handling (local logic, no API)
- Widget UI, animations, serial to Teensy
- Dashboard and 3D viewer

### Option D: Piggyback on Claude Code's API access

Not viable. Hooks can send data to our server but can't proxy API calls through Claude Code's credentials. The plugin system doesn't expose the host's API key or provide an eval endpoint.

## Recommended Path: A + C together

1. **First launch (no key):** Improved dialog with three choices:
   - "Enter API Key" → paste field (existing flow, better copy)
   - "Get API Key" → opens console.anthropic.com
   - "Try without key" → degraded mode with Foundation Models

2. **Degraded mode:** Duck works immediately. Local eval via Foundation Models. Menu bar shows "Local mode — add API key for better eval" or similar subtle indicator.

3. **Upgrade path:** Settings menu (or re-prompt after N sessions) lets user add API key anytime. Seamless switch from local to Haiku eval — no restart needed.

## Foundation Models Integration

### Prior art: choir-editor

The choir-editor project (`Sources/ChoirController/`) already uses Foundation Models in production for lyric generation and phoneme extraction. Patterns to reuse directly:

- **Availability check**: `SystemLanguageModel.default.availability` switch with `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` cases — copy from `PhonemeExtractor.swift`
- **`@Generable` with `@Guide`**: Structured output with `.anyOf()` and `.range()` constraints — proven to work for constrained domains
- **`LanguageModelSession(instructions:)` → `.respond(to:generating:)`**: Standard pattern, no streaming needed for eval
- **`@available(macOS 26, *)` gating**: All Foundation Models code behind availability checks
- **Xcode AI Playground**: Use `#Playground()` blocks in `LLMPlayground.swift` for rapid prompt iteration before wiring into the app

### Architecture

```
ClaudeEvaluator (existing)
    |
    EvalProvider protocol  ←--- NEW abstraction
    |                  \
HaikuProvider           FoundationProvider
(URLSession → API)      (on-device, no key)
```

### EvalProvider protocol

```swift
protocol EvalProvider {
    func evaluate(text: String, type: EvalType) async throws -> EvalResult
}
```

`ClaudeEvaluator` currently does HTTP to `api.anthropic.com`. Extract the eval logic into a protocol, then add a second conformance that uses Foundation Models.

### FoundationProvider implementation

```swift
import FoundationModels

@available(macOS 26, *)
@Generable
struct LocalEvalResult {
    @Guide(description: "Creativity: novel/surprising vs boring/obvious",
           .range(-1.0...1.0))
    var creativity: Double
    @Guide(description: "Technical soundness: correct/solid vs flawed/naive",
           .range(-1.0...1.0))
    var soundness: Double
    @Guide(description: "Ambition: bold undertaking vs trivial tweak",
           .range(-1.0...1.0))
    var ambition: Double
    @Guide(description: "Elegance: clean/clear vs hacky/convoluted",
           .range(-1.0...1.0))
    var elegance: Double
    @Guide(description: "Risk: could-go-wrong vs safe/predictable",
           .range(-1.0...1.0))
    var risk: Double
    @Guide(description: "Short gut reaction, max 10 words, be opinionated")
    var reaction: String
    @Guide(description: "One-line summary of the evaluation")
    var summary: String
}
```

Uses `.range()` constraints (proven in choir-editor's `LLMSyllable.weight`) to keep scores bounded. The `@Generable` macro generates a JSON schema that constrains the model's output to exactly match the struct — no parsing needed.

```swift
@available(macOS 26, *)
struct FoundationProvider: EvalProvider {
    func evaluate(text: String, type: EvalType) async throws -> EvalResult {
        let session = LanguageModelSession(
            instructions: Instructions("""
            You are an opinionated code critic. Score this \(type) on 5 dimensions.
            Be honest. Scores should spread across the range, not cluster near zero.
            """)
        )
        let response = try await session.respond(
            to: text,
            generating: LocalEvalResult.self
        )
        let local = response.content
        return EvalResult(
            creativity: local.creativity,
            soundness: local.soundness,
            ambition: local.ambition,
            elegance: local.elegance,
            risk: local.risk,
            reaction: local.reaction,
            summary: local.summary
        )
    }
}
```

### Availability and fallback

Reuse the choir-editor pattern from `PhonemeExtractor.checkAvailabilityImpl()`:

```swift
@available(macOS 26, *)
func checkAvailability() -> (available: Bool, message: String?) {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        return (true, nil)
    case .unavailable(let reason):
        let message: String
        switch reason {
        case .deviceNotEligible:
            message = "This Mac doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            message = "Enable Apple Intelligence in System Settings"
        case .modelNotReady:
            message = "Apple Intelligence model is downloading…"
        @unknown default:
            message = "Apple Intelligence unavailable"
        }
        return (false, message)
    @unknown default:
        return (false, nil)
    }
}
```

If Foundation Models isn't available, the "Try without key" option shows the reason or is hidden entirely.

### Prompt iteration via Xcode Playground

Before wiring into the app, iterate on eval prompts using `#Playground()` blocks (same approach as choir-editor's `LLMPlayground.swift`). Create `widget/LLMPlayground.swift` with test cases:

```swift
#Playground {
    let session = LanguageModelSession(instructions: Instructions("..."))
    let result = try await session.respond(
        to: "refactor the auth module to use JWT",
        generating: LocalEvalResult.self
    )
    print(result.content)
}
```

Test with varied prompts: trivial ("fix typo"), ambitious ("rewrite the database layer"), risky ("delete all tests"), creative ("build a DSL for animations"). Tune instructions until score distributions feel right.

### Prompt design for local eval

The on-device model is ~3B parameters — smaller than Haiku. Keep the instructions simple and direct. The `@Guide` descriptions on the struct do most of the work (same pattern as choir-editor's phoneme constraints). The session instructions just set tone and context.

### Learnings from choir-editor `.cursor/rules`

Patterns proven in choir-editor that apply here:

- **Deployment target = 26 means `@available` is unnecessary.** Choir-editor's `build-guide.mdc`: "When the deployment target IS 26+, `@available` annotations are unnecessary." Our widget targets macOS 26 exclusively, so `@available(macOS 26, *)` on `@Generable` structs and `FoundationProvider` can be omitted. Simplifies the code.

- **`@Generable` structs must be at file scope.** Not inside functions, playgrounds, or other types. Keep `LocalEvalResult` as a top-level struct in its own file.

- **`@AppStorage` + `@State` bridge for animated settings.** The eval mode toggle (Local/Cloud) should use `@AppStorage("evalMode")` as source of truth, bridged to `@State` in views that animate the transition. Menu bar reads `@AppStorage` directly. Pattern from `app-settings-pattern.mdc`.

- **Swift 6 concurrency: `@MainActor` for services, `nonisolated(unsafe)` for static mutable state.** `FoundationProvider` should be `@MainActor` since eval results feed directly into UI state. Avoid `DispatchQueue.main.asyncAfter` — use structured concurrency instead.

- **Xcode Canvas `#Playground` blocks run any async code**, not just LLM calls. Use them for rapid iteration on eval prompts before wiring into the app. The playground approach is how choir-editor developed and tuned all its Foundation Models prompts.

- **Release pattern: `.release/` directory (gitignored) for signing identity and notarization steps.** We should adopt this for `make release` — keep `DISTRIBUTION.md` with signing details out of the repo.

## Implementation Steps

1. **Playground first** — Create `LLMPlayground.swift` with `#Playground()` blocks to test eval quality before touching any production code. Iterate until scores are usable.

2. **Extract `EvalProvider` protocol** from `ClaudeEvaluator`
   - Define protocol with `evaluate(text:type:)` method
   - Make existing Haiku path conform as `HaikuProvider`
   - `ClaudeEvaluator` holds an `EvalProvider` and delegates to it

3. **Implement `FoundationProvider`**
   - `@Generable` struct with `.range()` constraints
   - `LanguageModelSession` wrapper
   - Availability check (copy choir-editor pattern)

4. **Update first-launch dialog**
   - Three-button layout: Enter Key / Get Key / Try Without
   - "Try Without" only shown if Foundation Models `.available`
   - Show reason if unavailable (device not eligible, not enabled, downloading)
   - Better copy explaining what the key is and cost

5. **Add mode indicator**
   - Menu bar item shows current eval mode (Local / Cloud)
   - "Add API key" option always available in menu

6. **Runtime provider switching**
   - Adding API key mid-session switches from Foundation to Haiku
   - No restart needed — just swap the provider

## Open Questions

- **`.range()` on Double**: Choir-editor uses `.range(1...3)` on Int. Need to verify `.range(-1.0...1.0)` works on Double — test in playground first.
- **Latency**: How fast is on-device eval for a typical code prompt (200-500 tokens)? If >5s, may need "evaluating..." indicator. Choir-editor's phoneme extraction gives a baseline.
- **Quality floor**: If local scores are too low-quality to be useful, is it better to show no scores than bad scores? Playground testing will answer this.
- **Intel Macs**: Foundation Models requires Apple Silicon. macOS 26 still supports some Intel Macs — those users get neither local nor cloud eval without a key. Show "API key required" for them.
- **Permission options beyond yes/no**: The current voice permission gate only supports allow/deny. But Claude Code permissions are often more nuanced — "allow once", "allow for session", "allow always", or choosing between multiple options. The Foundation Models local eval doesn't change this, but the permission UX needs a rethink to handle richer option sets. Revisit separately.

## Files to modify

| File | Change |
|------|--------|
| `ClaudeEvaluator.swift` | Extract `EvalProvider` protocol, refactor to use it |
| NEW `FoundationProvider.swift` | On-device eval via Foundation Models |
| NEW `EvalProvider.swift` | Protocol definition |
| `DuckConfig.swift` | Add `evalMode` (local/haiku), update API key dialog |
| `StatusBarManager.swift` | Show eval mode in menu, "Add API key" option |
| `Package.swift` | Add Foundation Models framework dependency (if needed — may be implicit on macOS 26) |
