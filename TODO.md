# Duck Duck Duck — TODO

## 🔥 Priority: Onboarding & Distribution

- [ ] **First-run onboarding flow** — duck guides new user from install to first reaction. Get Started menu item exists but needs polish. Speech bubble fallback for no-audio setups.
- [ ] **Bundle plugin in DMG** — offline install without GitHub access. Not sandbox-safe but fine for GitHub release tier.
- [ ] **Public repo** — required for marketplace install (`claude plugin marketplace add`). Currently private.
- [ ] **Plugin install voice feedback** — duck speaks "installing" and "plugin installed" (partially done, "installed" works)
- [ ] **Onboarding test script** — repeatable walkthrough doc at `docs/ONBOARDING-TEST-REPORT.md`

## 🧠 Foundation Models Tuning

- [ ] **Scoring accuracy** — 3B model inflates scores on trivial inputs ("phase 1" gets r=100), can't detect over-engineering (request vs response mismatch beyond 3B reasoning)
- [ ] **Reaction tone** — occasional cheerleading on positive vibe, rare voice/reaction mismatch (cheerful voice + negative reaction). Playground at `widget/Playground/Sources/LLMPlayground/EvalV4Playground.swift`
- [ ] **Whisper voice tuning** — works but LLM rarely picks "secretive" on its own
- [ ] **Emoji in reactions** — 3B sometimes outputs emoji which `say` reads literally. TTS sanitizer strips markdown but not emoji yet.

## 🎙️ Voice & Permissions

- [ ] **Foundation Models permission classifier** — built and wired in, needs live testing with ambiguous voice input ("uh, I guess so" instead of "yes")
- [ ] **Compaction hooks** — pre/post compact with Jeopardy thinking melody. Coded but untested (hard to trigger on demand)
- [ ] **StopFailure hook** — coded, untested. Needs actual API error to fire. LLM should simplify error message.

## 📊 Observability

- [ ] **Eval history view** — no way to review what the duck said. Dashboard (`localhost:3333`) shows live state only.
- [ ] **Log reliability** — logs inconsistent across `make run` vs DMG vs sandbox. Timestamps and eval reactions not always captured.
- [ ] **How To LLM Playground doc** — write up for future sessions so we stop forgetting how Canvas works

## 🎨 Widget Polish

- [ ] **Speech bubble** — text fallback for when audio isn't available. Shows what the duck would have said.
- [ ] **Tooltip showing reaction text on hover**
- [ ] **Localization** — add more languages to String Catalog
- [ ] **Custom duck face expressions** — more eye/beak states

## 🔌 Hardware

- [ ] **Hot-swap Teensy ↔ ESP32** — widget auto-detects board type but swapping mid-session untested
- [ ] **Rapid voice switching during active eval** — changing voices mid-TTS can cause audio desync

## 🔮 Future

- [ ] **Realtime API migration** — replace STT/TTS with unified streaming backend. Duck becomes conversational intermediary.
- [ ] **ESP32-S3 standalone** — WiFi-connected duck, no Mac needed
- [ ] **Duck-as-agent-teammate** — via agent teams inbox (needs rethink)
- [ ] **Three.js viewer refinement** — beak geometry, PCB details, sound, permission visualization

## ✅ Recently Shipped

- [x] **V5 two-pass eval** — scores then reaction with sentiment context. Eliminates typo comments.
- [x] **Score-gated voice selection V2** — math narrows voice pool, LLM picks from tone labels (grave, cheerful, etc.)
- [x] **Permission improvements** — natural language voice matching, smarter tool summaries, spoken option descriptions
- [x] **Permission classifier** — Foundation Models fallback for ambiguous voice input
- [x] **4-mode system** — Companion, Permissions Only, Companion (No Mic), Relay (Experimental)
- [x] **Menu/UX overhaul** — Pause/Quit split, Ducky connected status, mic status, volume 65% default
- [x] **Short message context reframing** — "yes" evaluated as decision, not word
- [x] **New hooks** — SessionEnd (18 farewell variations), PreCompact/PostCompact (Jeopardy melody), StopFailure
- [x] **Skip empty permissions** — MCP connectors with pre-authorized tools no longer nag
- [x] **Voice previews** — personality phrases per voice in picker menu
- [x] **Markdown TTS strip** — no more "asterisk personality asterisk"
- [x] **Synchronized eye blink** — both eyes blink together (desync on negative eval only)
- [x] **Whisper voice fix** — LLM always called now, can pick secretive
- [x] **No more "quack"** — removed "rubber duck" from reaction prompt
- [x] **Mic entitlements fix** — DMG builds now request mic permission on launch
- [x] **Permissions-only mode** — silent watchdog, voice-confirmed permissions
- [x] **Mode persistence** — survives app restart via UserDefaults
- [x] **Plugin system** — hooks load in CLI and Desktop, marketplace install works
- [x] **Sandbox testing** — core experience works, tmux/CLI launcher blocked (expected)
