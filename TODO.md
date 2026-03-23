# Duck Duck Duck — TODO

## 🔥 Priority: Onboarding & Distribution

- [ ] **First-run onboarding flow** — duck guides new user from install to first reaction. Get Started menu item exists but needs polish. Speech bubble fallback for no-audio setups.
- [ ] **Get Started script polish** — current version lists features but needs tighter flow
- [ ] **Cowork support** — verify hooks fire in Claude Desktop Cowork sessions, enable on marketplace listing
- [ ] **Privacy policy** — get IDEO legal to draft one for the Anthropic plugin submission and App Store

## 🧠 Foundation Models Tuning

- [ ] **Scoring accuracy** — 3B model inflates scores on trivial inputs ("phase 1" gets r=100), can't detect over-engineering (request vs response mismatch beyond 3B reasoning)
- [ ] **Short affirming replies** — "yep", "yes", "sure" get dismissive reactions ("meh") instead of evaluating the decision being affirmed. Context reframing helps but doesn't always fire (claudeContext may be empty)
- [ ] **Reaction tone** — occasional cheerleading on positive vibe, rare voice/reaction mismatch (cheerful voice + negative reaction). Playground at `widget/Playground/Sources/LLMPlayground/EvalV4Playground.swift`
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
- [ ] **ESP32-C3 GPL cleanup** — replace AudioTools with raw ESP-IDF I2S calls so C3 firmware can rejoin repo under OHL-P

## 🔮 Future

- [ ] **Sparkle auto-updater** — push app updates without manual DMG drag. SPM dependency (`sparkle-project/Sparkle`, MIT). Needs appcast.xml hosted on GitHub Pages or releases, EdDSA signing key. First external dependency.
- [ ] **Firmware OTA updates** — push firmware to hardware duck from the widget, no Arduino IDE needed. ESP32-S3: native OTA over serial or WiFi. Widget downloads binary from GitHub releases, pushes to device.
- [ ] **Repo rename** — `ideo/Rubber-Duck` → `ideo/duck-duck-duck` (blocked: name taken by marketing site). See `docs/REPO-RENAME.md` for full checklist.
- [ ] **Realtime API migration** — replace STT/TTS with unified streaming backend. Duck becomes conversational intermediary.
- [ ] **ESP32-S3 standalone** — WiFi-connected duck, no Mac needed
- [ ] **Duck-as-agent-teammate** — via agent teams inbox (needs rethink)
- [ ] **Three.js viewer refinement** — beak geometry, PCB details, sound, permission visualization

## ✅ Recently Shipped

- [x] **Repo public** — `ideo/Rubber-Duck` is now public
- [x] **Plugin submitted to Anthropic** — awaiting review for official marketplace listing
- [x] **Licenses** — MIT (software) + CERN OHL-P v2 (hardware), badges in README
- [x] **Plugin bundled in app** — installs offline from `Contents/Resources/plugin/`, no GitHub access needed
- [x] **Claude CLI prereq check** — helpful dialog with download link when CLI not found
- [x] **README rewrite** — privacy section, clear structure, architecture diagram, accordions
- [x] **Plugin README rewrite** — matches top-level tone, privacy emphasis
- [x] **Release page polish** — install steps, troubleshooting, accordion changelog
- [x] **Repo cleanup** — removed .claude/, .vscode/, dead hooks/, renamed gemini→plugin-gemini, firmware naming
- [x] **GPL isolation** — C3 firmware (AudioTools GPL dep) removed from public repo, gitignored
- [x] **V5 two-pass eval** — scores then reaction with sentiment context. Eliminates typo comments.
- [x] **Score-gated voice selection V2** — math narrows voice pool, LLM picks from tone labels
- [x] **Permission improvements** — natural language voice matching, smarter tool summaries
- [x] **Permission classifier** — Foundation Models fallback for ambiguous voice input
- [x] **4-mode system** — Companion, Permissions Only, Companion (No Mic), Relay (Experimental)
- [x] **Menu/UX overhaul** — Pause/Quit split, Ducky connected status, mic status, volume 65% default
- [x] **Short message context reframing** — "yes" evaluated as decision, not word
- [x] **New hooks** — SessionEnd, PreCompact/PostCompact (Jeopardy), StopFailure, PostToolUse
- [x] **Skip empty permissions** — MCP connectors with pre-authorized tools no longer nag
- [x] **Voice previews** — personality phrases per voice in picker menu
- [x] **Markdown/emoji TTS strip** — no more "asterisk personality asterisk"
- [x] **Whisper voice fix** — LLM always called, can pick secretive
- [x] **No more "quack"** — removed "rubber duck" from reaction prompt
- [x] **Mic entitlements fix** — DMG builds request mic permission on launch
- [x] **Permissions-only mode** — silent watchdog, voice-confirmed permissions
- [x] **Mode persistence** — survives app restart via UserDefaults
- [x] **Plugin system** — hooks load in CLI and Desktop, marketplace install works
- [x] **Onboarding test** — full walkthrough documented at `docs/ONBOARDING-TEST-REPORT.md`
