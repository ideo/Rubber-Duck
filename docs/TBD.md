# TBD — Open Items

## 1. Onboarding — golden path
- Simulate the full onboarding flow end-to-end and handle every step
- Golden path: user has Claude Code installed → installs widget from App Store → plugin discovery/install → first session with duck active
- Each transition needs to be smooth: what does the user see/hear at every step?
- Handle edge cases: Claude not installed, widget not running, plugin not found, port conflict
- First-run experience: duck should introduce itself, explain what it does, set expectations
- Existing onboarding notes in `docs/ONBOARDING.md` — build on those, don't start from scratch

### Sub-task: on-device help / support — R&D DONE, ready to build

**R&D results** (Playground-tested, all tiers pass):
- Grounding document: `docs/DUCK-HELP-GROUNDING.md` — compact help entries in duck's voice (~1200 tokens)
- Playground tests: `widget/Playground/Sources/LLMPlayground/HelpPlayground.swift`
- Single-turn Q&A: ✅ accurate, grounded, no hallucination, good TTS output
- Classification + retrieval: ✅ correct topic routing with `@Generable` struct
- Multi-turn conversation: ✅ holds 3-4 turns coherently, handles off-topic refusal
- Key finding: entries must be meta-aware ("if you're talking to me, I'm running")
- Key finding: "Can you help me debug" triggers Apple safety filter — keep questions duck-focused
- Key finding: model quality tracks grounding doc quality directly — tight duck-voiced entries produce tight duck-voiced answers

**Implementation plan — DuckHelpService**:

Architecture:
- New `DuckHelpService.swift` actor (mirrors `LocalEvaluator` pattern)
- Connected to wake word: "ducky, how do I install the plugin?" → duck answers directly
- **Critic mode**: all wake word input routes to help (no tmux to relay to — this gives wake word a purpose)
- **Relay mode**: help always tries first. If Foundation recognizes it's NOT a duck question, it says something like "That sounds like a Claude question" and seamlessly relays to tmux
- **Intelligence-agnostic**: uses whatever eval engine is selected (Foundation/Haiku/Gemini), not just Foundation Models. Same grounding content, different backend.

Wake word UX:
- "Ducky" → duck immediately responds "What?" / "Hmm?" / "Yeah?" (short, varied pool) AND cocks head (expression state). Instant feedback it heard you.
- Currently wake word silently starts listening — that's a dead-air gap
- Help response spoken via same TTS path as eval reactions

Session lifecycle:
- `LanguageModelSession` kept alive between wake word activations
- Auto-reset after 4 turns (4K token window fills up) — duck says "I'm losing my train of thought — ask me again fresh?" (natural, in-character)
- Also reset after 60s inactivity (timer in SpeechService)

Files to change:
- `DuckHelpService.swift` (NEW) — actor with grounding content, session management, `ask()` method
- `SpeechService.swift` — add `onHelpQuestion` callback, wake word acknowledgment pool, mode awareness
- `RubberDuckWidgetApp.swift` — create help service, wire callbacks
- `DuckCoordinator.swift` — optional `isAnsweringHelp` state for thinking animation

## 2. Permissions-only mode
- Third mode alongside critic and relay — duck only handles permission requests
- No evals, no speech reactions, no scoring — just the voice permission flow
- Useful for users who want the safety net of voice-confirmed permissions without the commentary
- Needs mode selector in menu (critic / relay / permissions-only)

## 3. Improved permission option handling
- Currently always says "ALLOW?" with allow/deny — but not all permission prompts are binary allow/deny
- Use the selected intelligence (Foundation Models or API) to interpret the user's spoken response more flexibly
- Use intelligence to concisely summarize what the permission options actually are before asking
- Bug: MCP connector tool calls trigger "ALLOW?" as if they're blocked, but connectors don't necessarily block — investigate why they're treated as permission requests

## 4. Wildcard voice — tuning
- Two-pass Foundation Models implementation works (LocalEvaluator: score → LocalVoicePick)
- Currently defaults to Superstar for almost everything — only switches on extreme scores
- Could use more Playground iteration to make voice picks more expressive/varied
- Whisper might work well for skepticism — "I'm not sure about this..." inner-doubt moments
- Removed bubbles (too weird). Now 10 wildcard voices.

## 5. Wake word in critic mode
- **Largely solved by help mode** — in critic mode, wake word now routes to on-device help (see #2 sub-task)
- Remaining: could also speak last eval summary on demand: "ducky, how am I doing?" → recap scores
- Could speak a verbal status: "I'm watching. Things are looking rough."
- Wake word acknowledgment: "ducky" should immediately trigger a short response ("What?" / "Yeah?" / "Hmm?") + head cock animation, before the user even finishes speaking. This replaces the current silent-listening gap.

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
