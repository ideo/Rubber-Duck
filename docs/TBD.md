# TBD — Open Items

## Active

### Claude Cowork plugin support / hooks
Explore what's possible with the Claude Cowork plugin system and hooks:
- What new hooks or plugin capabilities does Cowork expose beyond standard Claude Code?
- Can the duck participate as a cowork plugin (custom skills, connectors, workflows)?
- Hook into cowork sessions — react to multi-agent collaboration, team activity, task progress
- Plugin marketplace presence via Cowork's distribution model
- Any new APIs or event types we could listen to for richer duck reactions

### TTS interrupt — stop the duck mid-speech
No way to interrupt long TTS (especially the bedtime story). Need:
- Voice command: "stop", "shut up", "quiet" kills `say` process
- Duck face tap could also interrupt
- On interrupt, duck says a short quip: "Ok, enough of that."
- `killall say` is the manual escape hatch for now

### TTS-to-device latency — voice stream lag
Noticeable delay when streaming TTS audio to the hardware duck (Teensy/ESP32). The voice starts late compared to the speech bubble appearing on screen. Need to investigate:
- Buffering in the serial audio path (DMA buffer sizes, chunk sizes)
- `say` process startup latency vs when audio actually hits the device
- Whether pre-buffering or smaller chunks would help
- Measure actual latency to quantify the gap

### Red dot + conversation timeout — bugs
**Red dot persistence during easter egg:**
- During full story TTS reading, the red dot stays on the whole time
- After backstory conversation, the dot sometimes doesn't clear on exit back to normal mode

**Conversation mode drops unexpectedly:**
- Sometimes the mic just stops listening mid-conversation — no follow-up window, just dead
- Likely a race condition in the conversation timeout timer
- Future polish: LLM could tag responses as final vs open and adjust the timeout accordingly

### Status bar icon disappearing on some Macs
macOS hides overflow status bar items on notch Macs when space runs out.
- `autosaveName` applied — macOS remembers position
- Consider `NSStatusItem.squareLength` to minimize width
- Investigate `isVisible` to detect when hidden and warn
- Document workaround for users

### Menu + Preferences — visual polish pass
- View menu still shows up empty — need to suppress it
- Regression testing after all the restructuring (modes, volume, voice, launch, experimental)

### Foundation Models tuning
- Help vs free chat flow — 3B model sometimes gets stuck in help mode
- Easter egg sensitivity — some normal questions still trigger backstory deflection

---

## Shelved

### UAC audio — S3
Shelved. Serial streaming works and is shipping-ready. UAC is a polish item. See detailed notes in previous TBD versions or `docs/S3-FIRMWARE-GAP.md`.

### C3 audio quality — chirp synthesis
Chirps intelligible but garbled due to ESP32-C3 lacking APLL. TTS is clean. Hardware limitation — accept it or switch to FM/wavetable synthesis.

### 3D duck viewer
Three.js viewer at localhost:3333/viewer exists but never dialed in. Dev-only.

---

## Completed (2026-03-28)

- [x] Onboarding audit — 15/20 fixed, 5 accepted. See `docs/ONBOARDING-AUDIT.md`
- [x] Hooks: jq → python3, silent when widget off, log rotation, repo name removed from greeting
- [x] Port: stale PID cleanup, OS auto-assign fallback, dynamic port file
- [x] Permissions: alert icon, menu status items, settings links, refresh on menu open, skip redundant dialogs
- [x] Install: Claude version check, idempotent .zshrc, atomic JSON, better success copy, findClaude paths
- [x] DuckView: isolated DuckFaceView/DuckBeakView — context menu stays open during animations
- [x] Preferences: Behavior tab (Mode/Sound/Microphone), mic device picker with hot-plug, permission rows
- [x] Polish: DuckTheme.accent, icon updates (asterisk/sparkle/xmark), shortened menu labels, actool silenced
- [x] Serial: displayName "Duck, Duck, Duck" for identified boards
- [x] All prior completions (permissions-only mode, wildcard voice V2, hooks, menu reorg, API keys, dynamic port, mute detection, plugin install, easter egg, TTS pronunciation, beak animation, window focus, experimental toggle)
