# TBD — Open Items

## Active (priority order)

### 1. Foundation Models extremely slow on M1
On-device eval via Apple Foundation Models takes ~60 seconds on base M1 (vs sub-second on M4). Makes the duck nearly unusable in default config on older Apple Silicon. Workaround: switch to Claude API key in Preferences → Intelligence. Consider: auto-detect slow eval and suggest switching providers, or show a warning on first slow eval.

### 2. Alternate wake word names
The duck should respond to "Ishmael", "Ahab", and "Moby Duck" as wake words in addition to "ducky". These are character names from the backstory — using them as invocations adds personality and rewards players who unlocked the easter egg.

**Needs testing:**
- Can STT reliably distinguish "Ishmael" from background noise? Multi-syllable names are harder to false-trigger but harder to recognize.
- "Ahab" is short and punchy — good wake word candidate, but might conflict with common words.
- "Moby Duck" is two words — need to check if WakeWordProcessor can handle multi-word triggers.
- TTS pronunciation: "Ahab" already has a phoneme fix, but STT needs to *recognize* it correctly from speech input too.
- Each name could unlock a slightly different personality response (Ishmael = wistful, Ahab = intense, Moby Duck = dramatic).

### 3. Sparkle auto-updater — one-click app updates
Replace manual DMG download with Sparkle (SPM: `sparkle-project/Sparkle`).
- User clicks "Install Update" → app downloads, replaces itself, relaunches
- Appcast XML can auto-generate from GitHub Releases (already have the infrastructure)
- Sandboxed builds need Sparkle's XPC helper service for write access to /Applications
- First external dependency — but it's the industry standard (VS Code, Discord, Sublime all use it)
- Unlocks: once in place, any future capability (firmware flashing, new providers) ships via auto-update
- Estimate: ~1 day integration

### 4. OTA firmware update for ESP32-S3 hardware duck
Ship precompiled firmware in the app bundle and flash the hardware duck over USB without Arduino IDE.
- ESP32-S3 uses a well-documented serial bootloader protocol
- `esptool` ships as a standalone binary (no Python) — bundle it in the .app
- Flow: detect device via serial → check firmware version → "Update Firmware" button → send serial command to enter bootloader → esptool flashes bundled .bin → reboot
- Could trigger bootloader mode via a serial command from existing firmware (no physical button press)
- **Sandbox concern**: App Sandbox may block spawning bundled executables. GitHub release (unsandboxed) would work. App Store version would need a workaround or entitlement.
- **Bonus**: could version-check on every USB connect and prompt automatically
- **Alternative**: Web Serial API via ESP Web Tools on duck-duck-duck.web.app — Chrome/Edge only but zero install, could ship before Sparkle

### 5. Menu cleanup (post-launch wish list)
- Residual AppKit menus (Edit, occasional Format/View) are harmless but messy
- `CommandGroup(replacing:)` handles SwiftUI side. Edit menu kept intentionally (Cmd+V).
- Aggressive stripping via `applicationWillUpdate` caused flickering — removed.
- Revisit if a clean solution exists that doesn't flicker during @Published updates.

### 6. Conversation & Foundation Models polish (post-launch)
Combined voice conversation and on-device model tuning. Many of these issues have been heavily tinkered with — re-examine before fixing, some may be stale.
- **Mouth starts before audio**: mouth animation fires on `speak()` but `say` process has cold-start lag on first utterance
- **Red dot persistence**: during easter egg TTS reading, red dot stays on. After backstory conversation, dot sometimes doesn't clear on exit
- **Conversation drops**: mic stops listening mid-conversation — likely race condition in conversation timeout timer
- **Help vs free chat**: 3B model sometimes gets stuck in help mode
- **Easter egg sensitivity**: some normal questions still trigger backstory deflection
- **Future**: LLM could tag responses as final vs open and adjust timeout accordingly

---

## Investigated, Not Viable

### Embedded API key in release build
Explored shipping a bundled Haiku key so M1/M2 users get fast eval out of the box. Not viable:
- Any key in the binary is extractable (strings, Hopper, reverse engineering)
- Obfuscation (XOR, split) stops `strings` but not a determined attacker
- IDEO would eat all API costs (~$20/month at 100 users, scales linearly)
- Proxy server would secure the key but adds infrastructure to maintain
- Spend caps limit exposure but a rotated key breaks all existing installs
- Conclusion: users bring their own key. Gemini free tier is the best zero-cost option for M1/M2 users.

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

## Completed

- [x] Window identity — positive ID via WindowTagger + NSWindow.identifier (v0.9.3)
- [x] CheckboxDelegate — moved to top-level class, no more local @MainActor class (v0.9.3)
- [x] Status bar icon — all features accessible via right-click and Preferences, no gaps
- [x] Double filler speech — removed redundant acknowledgement from sendVoiceCommand (v0.9.2)
- [x] Permission feedback loop — ignore transcripts while TTS is playing (v0.9.1)
- [x] Plugin install — direct file copy first, no git/xcode-select needed (v0.9.1)
- [x] Version check via GitHub API — polls releases/latest, 30s delay then every 12h, force-check on About (v0.9.1)
- [x] Menu suppression: CommandGroup(replacing:) for all standard groups
- [x] Legal disclaimer: NSAlert modal after permissions, re-triggers on version change, Terms of Use in app menu
- [x] About pane: version, credits, View Open Source Project link
- [x] Setup checklist: non-blocking SwiftUI window, live refresh, Help → Get Started
- [x] Window launch race: configureDuckWindow + applicationWillUpdate fallback
- [x] Install Claude Code: .command file via NSWorkspace (no Automation permission needed)
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
- [x] All prior completions (permissions-only mode, wildcard voice V2, hooks, menu reorg, API keys, dynamic port, mute detection, plugin install, easter egg, TTS pronunciation, beak animation, window focus, experimental toggle)
