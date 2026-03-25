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

---

## Menu + Preferences — visual polish pass

Structure is done (Setup, Help, right-click, Preferences window). Needs:
- **Visual consistency** — accent color, spacing, alignment across all menus
- **Preferences tabs** — Intelligence and Voice tabs work but look rough. Need proper spacing, grouping, polish.
- **Custom SF Symbols** — puzzle piece (plugin), flask (experimental), sparkles (get started), manual (help) icons carried over to left menus
- **Regression testing** — modes, volume, voice, launch session, experimental toggle all need re-testing after the restructure
- **View menu** — still shows up empty. Need to suppress it (SwiftUI fights back on this one).

---

## "Can you hear me" mishandled

When users say "ducky, can you hear me" as a mic check, the duck answers as if it's a capabilities question ("I run everything locally, I can't hear you"). It should recognize this as a literal mic test and respond accordingly — "Yep, I hear you!" or "Loud and clear."

**Fixes needed:**
- Detect "can you hear me" / "do you hear me" / "are you listening" as mic-check phrases
- Short-circuit before the LLM — return a hardcoded affirmative (like the backstory stages)
- Add mic/audio info to the helpdesk prompt so if someone asks about hearing/microphone/audio capabilities, the duck knows it DOES use a mic in Companion and Relay modes
- Current system prompt says nothing about the mic — it should mention: Companion mode listens for wake word, Relay mode listens for commands, Permissions Only listens for yes/no, No Mic mode doesn't listen at all

---

## ~~Voice command popover~~ ✅ DONE
Popover resizes dynamically, arrow points away from duck (user's speech, not duck's). Looks good.

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

## ~~3. Onboarding + Help (unified)~~ ✅ MOSTLY DONE

Core system shipped: DuckHelpService, wake word UX, speech bubble, session lifecycle, HelpView articles, mic/audio docs.

### Still open
- **Golden path polish** — first-launch experience needs testing end-to-end. Install detection works (alerts on missing Claude), but the guided flow isn't seamless yet.
- **CLI install helper** — for users without Claude Code CLI. Need Terminal helper with copy/paste flow. The install commands are: `curl -fsSL https://claude.ai/install.sh | bash` then `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc`. Gnarly for normal humans.
- **Desktop zip install path** — for users with Claude Desktop but no CLI. Need a .zip ready for drag-in upload via Desktop's plugin UI. May need a folder with instructions + screenshots showing how to navigate to the upload button.
- **Version warning in install flow** — minimum Claude 1.1.7714. Alert exists on app launch but could be more prominent.

## ~~4. Foundation Models tuning~~ ✅ MOSTLY DONE

~~Typo obsession~~ ✅ Fixed. ~~Meaner than Haiku~~ ✅ Fixed. ~~Response length~~ ✅ Fixed. ~~Wildcard slow voice fallback~~ ✅ Fixed.

### Still open
- **Help vs free chat flow** — the 3B model sometimes gets stuck in help mode when the user is just chatting. Needs clearer routing.
- **Easter eggs need continued testing** — Moby Duck backstory gate works (3-attempt unlock → bedtime story reading) but phrasing sensitivity needs tuning. Some normal questions still trigger the deflection path.
- **"Can you hear me" mic check** — documented, not yet short-circuited in Swift. Should be a hardcoded affirmative before hitting the LLM.

## ~~5. Wildcard voice — tuning~~ ✅ DONE
Score-gated V2 shipped. See `docs/VOICE-SELECTION-V2.md`.

## ~~6. Wake word in companion mode~~ ✅ DONE
Shipped. Wake word in companion = help. Wake word in relay = help-first, then relay.

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
