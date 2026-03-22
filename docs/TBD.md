# TBD — Open Items

## Completed

- [x] **Permissions-only mode** — full watchdog mode with passive greetings, face reset, mode persistence
- [x] **Improved permission handling** — Bash description field, internal tool names, natural language voice matching, Foundation Models classifier fallback, empty-suggestion skip
- [x] **Wildcard voice V2** — score-gated architecture replaces V1 (see `docs/VOICE-SELECTION-V2.md`). Math filters pool, LLM picks tone label, mapped back to Mac voice. Jester removed.
- [x] **New hooks** — SessionEnd, PreCompact, PostCompact, StopFailure
- [x] **Companion mode rename** — Critic → Companion (`.critic` enum kept internal)
- [x] **Relay mode rename** — subtitle now "Walkie Talkie with Claude CLI", flask icon

---

## 3. Onboarding + Help (unified)

The duck IS the onboarding. It walks you through setup, answers questions, and that first interaction is also the demo of what it does. Help and onboarding are the same system.

### Golden path
1. User installs widget from App Store → duck appears, introduces itself
2. Duck guides plugin installation via voice/text: "Say 'ducky, help me install' or click the button"
3. First permission fires → duck demonstrates the voice flow
4. User is set up and understands all three modes

### On-device help — R&D DONE, ready to build

**R&D results** (Playground-tested, all tiers pass):
- Grounding document: `docs/DUCK-HELP-GROUNDING.md` — compact help entries in duck's voice (~1200 tokens)
- Playground tests: `widget/Playground/Sources/LLMPlayground/HelpPlayground.swift`
- Single-turn Q&A: ✅ accurate, grounded, no hallucination, good TTS output
- Classification + retrieval: ✅ correct topic routing with `@Generable` struct
- Multi-turn conversation: ✅ holds 3-4 turns coherently, handles off-topic refusal
- Key finding: entries must be meta-aware ("if you're talking to me, I'm running")
- Key finding: "Can you help me debug" triggers Apple safety filter — keep questions duck-focused
- Key finding: model quality tracks grounding doc quality directly — tight duck-voiced entries produce tight duck-voiced answers

### DuckHelpService architecture

- New `DuckHelpService.swift` actor (mirrors `LocalEvaluator` pattern)
- Connected to wake word: "ducky, how do I install the plugin?" → duck answers directly
- **Companion mode**: wake word routes to help (gives wake word a purpose beyond relay)
- **Relay mode**: help tries first. If Foundation recognizes it's NOT a duck question, says "That sounds like a Claude question" and relays to tmux
- Handles random chats and curious people poking at the duck
- **Intelligence-agnostic**: uses whatever eval engine is selected (Foundation/Haiku/Gemini)

### Wake word UX
- "Ducky" → immediate short response ("What?" / "Hmm?" / "Yeah?") + head cock expression. No dead-air gap.
- Can also recap status on demand: "ducky, how am I doing?" → verbal score summary
- Help response spoken via same TTS path as eval reactions

### Session lifecycle
- `LanguageModelSession` kept alive between wake word activations
- Auto-reset after 4 turns (4K token window) — "I'm losing my train of thought — ask me again fresh?"
- Also reset after 60s inactivity

### Speech bubble fallback
- Not everyone has speakers/mic — duck needs a text fallback
- Speech bubble below/beside the duck face shows what it would have said
- Liquid glass bubble that appears/fades with the utterance
- Required for: App Store version (sandbox blocks mic on some setups), silent environments, accessibility
- Also useful as a visual transcript — see what the duck said even with audio on

### Files to change
- `DuckHelpService.swift` (NEW) — actor with grounding content, session management, `ask()` method
- `SpeechService.swift` — add `onHelpQuestion` callback, wake word acknowledgment pool
- `RubberDuckWidgetApp.swift` — create help service, wire callbacks
- `DuckCoordinator.swift` — `isAnsweringHelp` state for thinking animation
- `DuckView.swift` — speech bubble overlay (NEW)

## 4. Foundation Models eval prompt tuning

The 3B on-device model has personality issues:
- **Typo obsession** — fixates on typos in user prompts. "phase 1" → "really, a typo." Short casual messages get roasted for no reason.
- **Meaner than Haiku** — Foundation reactions skew harsher than Claude Haiku on the same input. The duck should be snarky but not hostile.
- **User prompts aren't code** — user messages to Claude are conversational, not code. The eval prompt treats everything like a code review. Short human messages ("ok", "yes do that", "phase 1") shouldn't trigger craft/rigor scoring as if they're sloppy code.

### Possible fixes
- Separate prompt paths for user prompts vs Claude responses — user prompts scored more leniently
- Add "short casual messages are normal and fine" to the system prompt
- Adjust reaction tone: "snarky but ultimately supportive" not "mean"
- More Playground iteration with real user prompt examples (not just code scenarios)
- Compare Foundation vs Haiku side-by-side on same inputs to calibrate

### Testing
- `widget/Playground/Sources/LLMPlayground/` — add a "User Prompts" batch with casual/short messages
- Compare reaction tone across eval engines

## ~~5. Wildcard voice — tuning~~ ✅ DONE
Score-gated V2 shipped. See `docs/VOICE-SELECTION-V2.md`.

## ~~6. Wake word in companion mode~~ → merged into #3
Help mode covers this. Wake word in companion = help. Wake word in relay = help-first, then relay.

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
