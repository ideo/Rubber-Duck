# TBD — Open Items

## 1. UAC audio — S3 launch readiness
- S3 boards are the likely launch hardware — UAC audio path needs to be rock solid
- Test USB Audio Class mic input from S3 (not just Teensy) — verify sample rate, format, latency
- Test TTS output via `say -a` to S3 UAC device — verify routing, volume, no clipping
- Test hot-plug behavior: S3 plugged in mid-session → widget detects and switches audio paths
- Test hot-unplug: S3 removed mid-session → falls back to local Mac mic + speakers cleanly
- Test swap: S3 connected while ESP32 serial device is also connected → correct device wins
- Verify `AudioDeviceDiscovery.findTeensy()` naming works for S3 (device name may differ)
- Test MelodyEngine routing to S3 UAC device (outputDeviceID)

## 2. Onboarding — golden path
- Simulate the full onboarding flow end-to-end and handle every step
- Golden path: user has Claude Code installed → installs widget from App Store → plugin discovery/install → first session with duck active
- Each transition needs to be smooth: what does the user see/hear at every step?
- Handle edge cases: Claude not installed, widget not running, plugin not found, port conflict
- First-run experience: duck should introduce itself, explain what it does, set expectations
- Existing onboarding notes in `docs/ONBOARDING.md` — build on those, don't start from scratch

### Sub-task: on-device help / support via Foundation Models
- Can the 3B model answer user questions about the duck widget grounded in a support doc?
- Grounding document: `docs/DUCK-HELP-GROUNDING.md` — compact help entries (~1200 tokens)
- Playground tests: `widget/Playground/Sources/LLMPlayground/HelpPlayground.swift`
- Three tiers to test (each in the Playground):
  1. **Grounded single-turn Q&A** — model answers from inline help text. Tests accuracy, grounding (no hallucination), conciseness. 5 test cases covering factual, troubleshooting, out-of-scope, ambiguous.
  2. **Classification + retrieval** — model picks the right help topic from a list, then answers from that entry. Tests whether a two-step retrieve→answer approach works. Uses `@Generable` struct for structured topic pick.
  3. **Multi-turn conversation** — model holds a 3-4 turn support dialog using `LanguageModelSession` transcript. Tests context preservation, off-topic handling, coherence across turns.
- Apple's guidance (WWDC25 "Meet Foundation Models"): use `LanguageModelSession` for multi-turn (transcript preserved), use tool calling to ground responses in app data, model is NOT suited for world knowledge or advanced reasoning — keep tasks small and specific.
- Apple's guidance (WWDC25 "Prompt Design & Safety"): embed verified information directly in prompts for grounding, break complex tasks into simpler steps, avoid code generation, use ALL-CAPS directives.
- Apple's guidance (WWDC25 "Deep dive"): tool calling for on-demand retrieval is recommended over stuffing everything in the prompt. Define a `SearchHelp` tool that the model calls to fetch relevant entries.
- Known risk: 4096 token context window — full help doc fits in single-turn (~1600 total), but multi-turn fills up fast. Rotate sessions after 3-4 turns.
- Known risk: 3B model parrots examples (our research) — FAQ answers must not appear as few-shot examples. Use instructions-only grounding.
- Known risk: aggressive safety guardrails may reject harmless help content — test actual entries for false positives.
- If Foundation can't handle conversational support, fall back to tier 1 (grounded Q&A) or simple FAQ matching and surface a "learn more" link to docs.

## 3. Permissions-only mode
- Third mode alongside critic and relay — duck only handles permission requests
- No evals, no speech reactions, no scoring — just the voice permission flow
- Useful for users who want the safety net of voice-confirmed permissions without the commentary
- Needs mode selector in menu (critic / relay / permissions-only)

## 4. Improved permission option handling
- Currently always says "ALLOW?" with allow/deny — but not all permission prompts are binary allow/deny
- Use the selected intelligence (Foundation Models or API) to interpret the user's spoken response more flexibly
- Use intelligence to concisely summarize what the permission options actually are before asking
- Bug: MCP connector tool calls trigger "ALLOW?" as if they're blocked, but connectors don't necessarily block — investigate why they're treated as permission requests

## 5. Wildcard voice — tuning
- Two-pass Foundation Models implementation works (LocalEvaluator: score → LocalVoicePick)
- Currently defaults to Superstar for almost everything — only switches on extreme scores
- Could use more Playground iteration to make voice picks more expressive/varied
- Whisper might work well for skepticism — "I'm not sure about this..." inner-doubt moments
- Removed bubbles (too weird). Now 10 wildcard voices.

## 6. Wake word in critic mode
- "Ducky" wake word works in relay mode (sends commands to Claude via tmux)
- In critic mode there's no tmux session — wake word triggers but has nothing to do
- Options: disable wake word in critic, or give it a critic-specific role
- Could speak last eval summary on demand: "ducky, how am I doing?" → recap scores
- Could speak a verbal status: "I'm watching. Things are looking rough."

---

## Shelved

### 3D duck viewer
- Three.js viewer at localhost:3333/viewer exists but was never fully dialed in
- Both duck prototypes (servo + LED) render but need polish
- Dev-only — not user-facing
