# TBD — Open Items

## 1. Permissions-only mode

**Why first**: This is the simplest, most universally useful duck mode. Many users want voice-confirmed permissions without commentary. It also forces us to nail the permission UX before layering on evals and onboarding.

**Current state**: The mic menu already has a "Permissions Only" listen mode that disables wake word but keeps permission listening. However, this is a *mic* setting, not a *mode*. The duck still runs evals and speaks reactions — it just ignores wake word input.

**What we want**: A true permissions-only mode where the duck is silent until a permission request arrives. No evals, no reactions, no scoring overhead. Just a watchdog.

### Implementation plan

**Menu change** — Add "Permissions Only" as a third mode alongside Critic and Relay:
```
Mode (current: Critic)
  ☑ Critic           [inner monologue and alerts]
  ◯ Relay            [walkie talkie with Claude]
  ◯ Permissions Only [voice-confirmed permissions only]
```

**Behavior in permissions-only mode**:
- Evals: **OFF** — hooks still fire but widget discards eval results (no scoring, no TTS reaction)
- Permission hook: **ON** — full voice flow as today (speak prompt, listen for yes/no)
- Mic: **always on** in permissions-only (forced to `.permissionsOnly` listen mode)
- Duck face: neutral/idle, no expression changes from evals
- Chirps: only permission chirp (uh-oh), no expression chirps
- Servo: only permission nag animation, no eval-driven movement
- Serial to firmware: only `P,1` / `P,0` commands, no score messages

**Files to change**:
- `StatusBarManager.swift` — add Permissions Only to mode submenu
- `DuckCoordinator.swift` — check mode before processing evals, skip scoring/expression/TTS in permissions-only
- `SpeechService.swift` — force `.permissionsOnly` listen mode when in this mode
- `EvalService.swift` — skip eval processing when mode is permissions-only (or just don't speak results)
- `DuckConfig.swift` — persist mode as enum: `.critic`, `.relay`, `.permissionsOnly`

**Estimated effort**: Small — mostly gating existing code paths with a mode check.

## 2. Improved permission option handling

**Why second**: The current permission prompt is too simple. It always says "Tool name. Allow?" regardless of what the tool is or what options Claude offers. Smarter prompts make the duck more useful and less annoying.

**Current flow**:
1. Hook sends: `tool_name`, `tool_input` (JSON), `permission_suggestions` (array of rules)
2. Widget speaks: `"Read config. Allow?"` (or just `"Read. Allow?"` if no summary)
3. User says: "yes" / "no" / "first" / "second" (to select a suggestion)

**Problems**:
- `tool_input` is raw JSON — not human-friendly for TTS
- Permission suggestions are rule objects, not plain English — user has no idea what "first" or "second" means
- All permissions sound the same regardless of risk level
- MCP connector tool calls trigger permission prompts even when they shouldn't block

### Implementation plan

**Phase 1: Better prompts (no intelligence needed)**
- Parse `tool_input` to extract meaningful context:
  - Bash: read the `command` field → "Run git status. Allow?"
  - Edit: read `file_path` → "Edit StatusBarManager.swift. Allow?"
  - Read: read `file_path` → "Read Config.h. Allow?"
  - WebFetch: read `url` → "Fetch from github.com. Allow?"
- Speak suggestion labels clearly: "Say 'first' to always allow Read, or 'second' to always allow in this project"
- Use `PermissionGate.describeSuggestion()` (already exists) to generate TTS-friendly labels

**Phase 2: Intelligence-powered summaries**
- Send `tool_name` + `tool_input` to the selected eval engine (Foundation/Haiku/Gemini)
- Prompt: "Summarize this tool call in 5 words for a voice assistant"
- Example: Bash `{"command": "rm -rf /tmp/build"}` → "Delete temp build folder"
- Risk assessment: "Is this destructive? Rate 1-5" → adjust TTS urgency/voice

**Phase 3: Smarter response matching**
- Use intelligence to interpret ambiguous responses: "uh, I guess so" → allow
- Handle conditional responses: "allow but only this once" → allow without suggestion
- Handle questions: "what does it do?" → re-read the summary

**Phase 4: MCP connector bug**
- Investigate why MCP tool calls trigger permission requests
- May need to filter by tool source in the hook script

**Files to change**:
- `scripts/on-permission-request.sh` — pass more structured data (extract command/path before sending)
- `DuckServer.swift` — parse tool_input JSON, extract human-readable summary per tool type
- `SpeechService.swift` — speak richer prompts with option descriptions
- `PermissionVoiceGate.swift` — smarter matching (Phase 3)
- `EvalService.swift` or new `PermissionSummarizer.swift` — intelligence-powered summaries (Phase 2)

**Estimated effort**: Phase 1 is small (string parsing). Phase 2 is medium (new eval prompt). Phase 3-4 are polish.

## 3. Onboarding — golden path
- Simulate the full onboarding flow end-to-end and handle every step
- Golden path: user has Claude Code installed → installs widget from App Store → plugin discovery/install → first session with duck active
- Each transition needs to be smooth: what does the user see/hear at every step?
- Handle edge cases: Claude not installed, widget not running, plugin not found, port conflict
- First-run experience: duck should introduce itself, explain what it does, set expectations
- Existing onboarding notes in `docs/ONBOARDING.md` — build on those, don't start from scratch
- **Depends on #1 and #2**: onboarding should default to permissions-only mode (least intimidating) and demonstrate the improved permission prompts

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

## 5. Wildcard voice — tuning
- Two-pass Foundation Models implementation works (LocalEvaluator: score → LocalVoicePick)
- Currently defaults to Superstar for almost everything — only switches on extreme scores
- Could use more Playground iteration to make voice picks more expressive/varied
- Whisper might work well for skepticism — "I'm not sure about this..." inner-doubt moments
- Removed bubbles (too weird). Now 10 wildcard voices.

## 6. Wake word in critic mode
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
