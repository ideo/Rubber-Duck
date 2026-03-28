# TBD — Open Items

## Active (priority order)

### 1. Conversation polish — latency, red dot, timeouts
Combined performance/UX issues in voice conversations:
- **Mouth starts before audio**: mouth animation fires on `speak()` but `say` process has cold-start lag on first utterance. Subsequent calls are fast. Mainly noticeable on conversation start.
- **Red dot persistence**: during easter egg TTS reading, red dot stays on. After backstory conversation, dot sometimes doesn't clear on exit.
- **Conversation drops**: mic stops listening mid-conversation — no follow-up window. Likely race condition in conversation timeout timer (TTS finishing, STT restarting, timeout firing stepping on each other).
- **Future**: LLM could tag responses as final vs open and adjust timeout accordingly.

### 2. Foundation Models tuning
- Help vs free chat flow — 3B model sometimes gets stuck in help mode
- Easter egg sensitivity — some normal questions still trigger backstory deflection

### 3. Version check via GitHub API
Lightweight update check — no Sparkle dependency:
- `GET api.github.com/repos/ideo/Rubber-Duck/releases/latest`
- Compare tag against bundle version
- Show notification linking to release page (GitHub) or App Store
- App Store safe — no self-update mechanism

### 4. Menu + Preferences — regression testing
- View menu suppression working but hacky (didBecomeActiveNotification + delay)
- Full regression test needed after all restructuring (modes, volume, voice, launch, experimental)

### 5. Status bar icon disappearing on some Macs
macOS hides overflow status bar items on notch Macs when space runs out.
- `autosaveName` applied — macOS remembers position
- Settings menu and right-click cover all features — not blocking

---

## Shelved

### TTS interrupt — voice command
Wing tap stops speech. Voice command ("stop", "shut up") would be nice but not needed.

### UAC audio — S3
Serial streaming works and is shipping-ready. UAC is a polish item.

### C3 audio quality — chirp synthesis
Chirps garbled due to ESP32-C3 lacking APLL. TTS is clean. Hardware limitation.

### 3D duck viewer
Three.js viewer at localhost:3333/viewer. Dev-only.

### Claude Cowork plugin support
Researched 2026-03-28. Cowork has no hook support — it's for non-technical knowledge workers. Agent Teams (experimental) has new hooks (TeammateIdle, TaskCreated, TaskCompleted) but our value is mainly in permission blocks. Revisit when agent teams stabilize.

---

## Completed (2026-03-28)

- [x] Onboarding audit — 15/20 fixed, 5 accepted. See `docs/ONBOARDING-AUDIT.md`
- [x] Hooks: jq → python3, silent when widget off, log rotation, repo name removed from greeting
- [x] Port: stale PID cleanup, OS auto-assign fallback, dynamic port file
- [x] Permissions: alert icon, menu status items, settings links, refresh on menu open, skip redundant dialogs
- [x] Install: Claude version check, idempotent .zshrc, atomic JSON, better success copy, findClaude paths
- [x] DuckView: isolated DuckFaceView/DuckBeakView/DuckWingsView/DuckStatusOverlay/DuckContextMenu
- [x] Preferences: Behavior tab (Mode/Sound/Microphone), mic device picker with hot-plug, permission rows
- [x] Polish: DuckTheme.accent, icon updates (asterisk/sparkle/xmark), shortened menu labels, actool silenced
- [x] Serial: displayName "Duck, Duck, Duck", phonetic pronunciation (Ayhab/Klawd)
- [x] Wings: glass liquid SVG shape, hover animation, tap-to-stop speech with quip
- [x] Eval: cloud fallback to Foundation Model, varied error reactions
- [x] Privacy: 3rd party terms notice + policy links in Preferences
- [x] View menu: killed permanently (CommandGroup replacing + didBecomeActiveNotification strip)
- [x] Menu stripping fix: NSMenu.didAddItemNotification was breaking eval/speech pipeline
- [x] All prior completions (permissions-only mode, wildcard voice V2, hooks, menu reorg, API keys, dynamic port, mute detection, plugin install, easter egg, TTS pronunciation, beak animation, window focus, experimental toggle)
