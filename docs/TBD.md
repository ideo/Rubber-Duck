# TBD — Open Items

## Completed

- [x] **Permissions-only mode** — full watchdog mode with passive greetings, face reset, mode persistence
- [x] **Improved permission handling** — Bash description field, internal tool names, natural language voice matching, Foundation Models classifier fallback, empty-suggestion skip
- [x] **Wildcard voice V2** — score-gated architecture replaces V1 (see `docs/VOICE-SELECTION-V2.md`). Math filters pool, LLM picks tone label, mapped back to Mac voice. Jester removed.
- [x] **New hooks** — SessionEnd, PreCompact, PostCompact, StopFailure
- [x] **Companion mode rename** — Critic → Companion (`.critic` enum kept internal)
- [x] **Relay mode rename** — subtitle now "Walkie Talkie with Claude CLI", flask icon
- [x] **Menu reorganization** — Setup + Help left menus, right-click/right-icon unified. Functionally done, needs visual polish and regression testing.
- [x] **File-based API keys** — replaced Keychain with Application Support files. No more scary dialog.
- [x] **Dynamic help prompt** — DuckHelpService knows which eval provider is active, explains privacy accurately per mode.
- [x] **Dynamic port** — widget tries 3333, falls back to 3334-3343 if taken. Writes port to file, hooks read it.
- [x] **System mute detection** — Mac muted + no hardware duck → auto speech bubble + mouth animation. Hardware duck bypasses.
- [x] **Intelligence picker restored** — back in right-click and status bar menus with modal key prompt.
- [x] **Desktop plugin install path** — PluginInstaller detects Desktop-only users, copies bundled plugin directly.
- [x] **Moby Duck easter egg** — 3-attempt backstory gate, staged deflections, full bedtime story TTS reading, TTS-optimized prose, clean exit back to normal mode.
- [x] **TTS pronunciation pipeline** — phoneme replacements for "Ahab" and "Claude" in TTSEngine.
- [x] **Beak mouth animation** — random flutter during TTS, syncs to speech bubble duration when muted.
- [x] **Window focus recovery** — `canBecomeKey` override on borderless window, glass stays saturated after Settings.

---

## Menu + Preferences — visual polish pass

Structure is done (Setup, Help, right-click, Preferences window). Needs:
- **Visual consistency** — accent color, spacing, alignment across all menus
- **Preferences tabs** — Intelligence and Voice tabs work but look rough. Need proper spacing, grouping, polish.
- **Custom SF Symbols** — puzzle piece (plugin), flask (experimental), sparkles (get started), manual (help) icons carried over to left menus
- **Regression testing** — modes, volume, voice, launch session, experimental toggle all need re-testing after the restructure
- **View menu** — still shows up empty. Need to suppress it (SwiftUI fights back on this one).

---

## Status bar icon disappearing on some Macs

Reported on another user's Mac — the duck menu bar icon appears and disappears intermittently.

**Root cause:** macOS hides overflow status bar items when space runs out, especially on notch Macs (14"/16" MacBook Pro) where the area between Apple menu and notch is limited. System items (WiFi, battery, clock) get priority over third-party items.

**Mitigations applied:**
- Added `autosaveName` so macOS remembers the icon's position across launches

**Still needed:**
- Consider making the icon `NSStatusItem.squareLength` instead of `variableLength` to minimize width
- Investigate `isVisible` property to detect when macOS hides us and warn the user
- Fallback: if status item is hidden, the duck widget itself should still be fully functional (right-click still works)
- Document for users: "If the menu bar icon disappears, you may have too many menu bar items. Try Bartender or remove unused items."
- Long-term: consider whether the status bar icon is essential or if the widget right-click + left menus are sufficient

---

## Claude version detection + compatibility

The `StopFailure` hook broke all plugin loading on Claude 2.1.76 because it's not a valid hook event in that version. One invalid key = zero hooks loaded, silently.

**Need to build:**
- Widget detects Claude version at startup (parse `claude --version` or check binary metadata)
- Maintain a compatibility table: which hooks are valid in which version
- `hooks.json` generated dynamically or the widget warns about incompatible hooks
- On plugin install, check version and warn: "Your Claude version doesn't support all features. Update recommended."
- Session start hook could report Claude version to the widget for display in dashboard/help
- Minimum supported version tracked in one place (currently 1.1.7714 for basic hooks)

**Known hook support gaps:**
- `StopFailure` — not in 2.1.76, present in 2.1.83
- Need to map all hooks to the version that introduced them

---

## Red dot + conversation timeout — bugs

**Red dot persistence during easter egg:**
- During full story TTS reading, the red dot stays on the whole time
- After backstory conversation, the dot sometimes doesn't clear on exit back to normal mode
- Normal help conversations and wake word flow are mostly fine

**Conversation mode drops unexpectedly:**
- Sometimes the mic just stops listening mid-conversation — no follow-up window, just dead.
- Likely a race condition in the conversation timeout timer — TTS finishing, STT restarting, and the timeout firing may be stepping on each other.
- The timer is a dumb fixed duration after the duck finishes speaking. No intelligence about whether the conversation feels "done" vs "open."
- Future polish: LLM could tag responses as final vs open and adjust the timeout accordingly.

---

## TTS interrupt — stop the duck mid-speech

No way to interrupt long TTS (especially the bedtime story). Need:
- Voice command: "stop", "shut up", "quiet" kills `say` process
- Duck face tap could also interrupt
- On interrupt, duck says a short quip: "Ok, enough of that."
- `killall say` is the manual escape hatch for now

---

## Onboarding — remaining gaps

- **CLI install helper** — for non-technical users. Commands are: `curl -fsSL https://claude.ai/install.sh | bash` then PATH setup. Need a Terminal helper with copy/paste flow, or widget opens Terminal and does it.
- **Version warning polish** — minimum Claude 1.1.7714. Alert exists but could be more prominent.
- **Golden path testing** — end-to-end first-launch experience needs a full walkthrough.

---

## Foundation Models tuning — remaining

- **Help vs free chat flow** — 3B model sometimes gets stuck in help mode during casual chat. Needs clearer routing.
- **Easter egg sensitivity** — some normal questions still trigger the backstory deflection path.

---

## Shelved

### UAC audio — S3

**Status**: Shelved. Serial streaming works and is shipping-ready. UAC is a polish item.

**Risks discovered**:
- ESP32-S3 UAC ecosystem is immature vs Teensy (which does this in one line)
- Composite USB (CDC serial + UAC audio) requires custom TinyUSB descriptors — no turnkey solution
- macOS may reject 16kHz mono — one project had to use 48kHz stereo
- Speaker audio reportedly crackly over UAC (mic is fine)
- Requires ESP-IDF build system (not Arduino IDE) — different toolchain for one chip variant
- `CONFIG_UAC_SUPPORT_MACOS=y` breaks Windows compatibility

**What's done (widget side)**:
- `AudioDeviceDiscovery.findDuckDevice()` — generalized from Teensy-only to match any duck UAC device
- `DuckConfig.duckAudioDeviceNames` — list of UAC device name patterns, env-overridable
- `SerialTransport.hasUAC` / `.needsSerialAudio` — board identity determines audio path
- `SpeechService` — S3 triggers CoreAudio path if UAC detected, falls back to serial streaming if not
- New `AudioPath.duckUAC` — ESP32-S3 uses same STTEngine + TTSEngine as Teensy
- Widget dual-path logic is tested and working — this is all reusable if UAC ever ships

**What's done (firmware side)**:
- ESP-IDF project at `firmware/rubber_duck_s3_uac/` — compiles under ESP-IDF v5.3.4 + Arduino component
- TLC59711 LED bar removed, replaced with built-in NeoPixel StatusLED (GPIO 48)
- Gap analysis: `docs/S3-FIRMWARE-GAP.md`
- UAC component (`usb_device_uac`) researched and integrated
- Build instructions: `firmware/rubber_duck_s3_uac/README.md`

**What we tested (2026-03-20)**:
- UAC component integrated, device enumerates on macOS as "usb uac" (1 in / 1 out)
- macOS sees 16kHz, 1ch, 16-bit — format accepted, no rejection
- Speaker output: NO AUDIO through MAX98357 I2S DAC despite callback wiring
- Likely causes: blocking I2S write deadlocks USB task, DMA buffer sizing, possibly need ring buffer + separate writer task
- CDC serial lost when UAC enabled (no composite device support without custom TinyUSB descriptors)
- Device name "Duck Duck Duck" not applied — UAC component uses its own `CONFIG_UAC_TUSB_PRODUCT`

**What's left if we revisit**:
- Debug speaker output: add ring buffer between UAC callback and I2S, separate writer task
- Solve composite CDC+UAC (custom TinyUSB descriptors + `skip_tinyusb_init`)
- Fix device name in CoreAudio
- Test NeoPixel status LED (need hardware to verify)
- Test MelodyEngine routing to S3 UAC device (outputDeviceID)

### C3 audio quality — chirp synthesis

**Status**: Chirps intelligible but garbled. TTS is nearly clean. Hardware limitation.

**Root cause**: ESP32-C3 has no APLL (Audio PLL). The I2S bit clock is derived from the 160MHz crystal via integer dividers, producing ~0.1% jitter. This is inaudible in broadband speech (TTS) but very audible on pure tones (chirps). Every ESP32-C3 board has this — it's silicon, not a defect.

**What worked**:
- pschatzmann/arduino-audio-tools library (better I2S clock config than raw IDF driver)
- 16kHz sample rate (cleanest for C3; 22kHz was worse, 8kHz had aliasing)
- 47µF cap on MAX98357 VIN (essential — eliminates power rail noise)
- 5V power to MAX98357 (3.3V causes dropouts on C3's smaller regulator)
- Drip-feed chirp generation (16 samples/chunk, one chunk per loop() call)

**What didn't help**:
- MCLK_MULTIPLE overrides (256, 384, 512 — all worse or no change)
- Assigning MCLK to a GPIO pin
- Larger DMA buffers (8→12 count)
- 22050Hz sample rate (worse than 16kHz)
- schreibfaul1/ESP32-audioI2S library (designed for streaming, not raw sample injection)
- 15625Hz "clean divider" rate (160MHz / 4M = exactly 40) — disproved fractional divider theory
- Soft-knee tanh compressor on chirp output — peaks aren't the issue
- Widget-side chirp generation streamed over serial — same garble, confirming it's the I2S output path
- 220µF cap (bigger cap helped power but didn't fix tonal garble)

**Key finding**: Streamed chirps (generated on Mac, identical samples) garble the same as locally generated ones. The problem is definitively the C3 I2S output path with tonal content, not the synthesis code.

**Key finding**: Servo plugged in = cleaner audio. The servo motor's inductance acts as a power filter on the rail. Without it, audio quality drops.

**Hardware notes for C3 BOM**:
- 220µF+ electrolytic cap on MAX98357 VIN/GND (essential)
- 5V power to MAX98357 (not 3.3V — C3 regulator too weak)
- Servo on same rail provides accidental filtering

**Possible next steps**:
- FM synthesis or noise-based chirps (less power-dynamic, masks jitter naturally)
- Wavetable DDS (proven clean on C3 by psitech project)
- PCM5102A DAC (own oscillator, bypasses C3 clock entirely — hardware swap)
- Accept it: TTS clean + chirps recognizable is a shippable C3 product
- Skip chirps on C3, use servo-only expression

**Test tool**: `firmware/rubber_duck_c3/test_chirp_synth.py` — Python port of ChirpSynth.ino, plays on laptop or streams to duck via `--serial` for A/B comparison

**Forum reference**: https://forum.seeedstudio.com/t/xiao-esp32c3-and-i2s-how-to/270576

### 3D duck viewer
- Three.js viewer at localhost:3333/viewer exists but was never fully dialed in
- Both duck prototypes (servo + LED) render but need polish
- Dev-only — not user-facing

---

## Recent completions (2026-03-24)

- [x] **File-based API key storage** — replaced Keychain with plaintext files in Application Support. No more scary "wants to use your confidential information" dialog.
- [x] **Menu reorganization** — Setup + Help left menus, right-click/right-icon unified and simplified.
- [x] **Preferences window** — Intelligence tab with inline API keys, Voice tab with picker, accent color throughout.
- [x] **Beak art update** — new beak PNGs, mouth animation during TTS (random flutter).
- [x] **TTS pronunciation** — phoneme pipeline for "Ahab" and "Claude" via `TTSEngine.applyPronunciations`.
- [x] **Moby Duck easter egg** — 3-attempt backstory gate, staged deflections, full bedtime story TTS reading, clean exit back to normal mode.
- [x] **Wake word head tilt** — 45° ± 10° tilt on both Teensy and ESP32 firmwares.
- [x] **Voice command popover** — dynamic resize, arrow points away from duck, anchored to red dot.
- [x] **Plugin debug logging** — `duck_debug()` in duck-env.sh, per-hook DUCK_HOOK_NAME, health check on every invocation. `/tmp/duck-plugin-debug.log`.
- [x] **Helpdesk docs** — mic/audio section, IDEO attribution, team section, mode-specific listening behavior.
- [x] **Settings window focus** — `applicationDidResignActive` re-activates duck window so glass stays saturated.
- [x] **Experimental features toggle** — Gemini behind feature flag, menu updates reactively via `@Published`.
