# Rubber Duck — Phase 3 Handoff

## What was done

### Phase 1: Hardware + Voice (commits up to `2388420`)
- Teensy 4.0 firmware: servo, I2S chirps, bidirectional USB audio
- Widget: STT/TTS, wake word ("ducky"), serial comms
- Python eval service: Claude Haiku scoring, WebSocket broadcast
- Hook scripts connecting Claude Code events to the duck

### Phase 2: Modularity + Modes (commits up to `db6c597`)
- Refactored widget into focused components (STTEngine, TTSEngine, WakeWordProcessor, etc.)
- Added critic/relay voice modes with Teensy button toggle
- Expression engine mapping scores to widget animations

### Phase 3: Swift Consolidation (commit `39cabc4`)
- **Eliminated the Python service entirely.** The widget now embeds a Hummingbird 2 HTTP+WebSocket server.
- One self-contained macOS app — drag to Applications, done.
- New modules: `ClaudeEvaluator`, `DuckServer`, `PermissionGate`, `TmuxBridge`, `WebSocketBroadcaster`, `LocalEvalTransport`
- Deleted: `ServiceProcess.swift` (managed the Python process lifecycle)
- API key lookup (for optional Anthropic API): `~/Library/Application Support/DuckDuckDuck/api_key`
- Dashboard and 3D viewer bundled as Swift Package resources
- Fixed PermissionGate crash (`Task.detached` for timeout, not `Task`)

## Current state

**What works end-to-end:**
- `make run` → widget launches with on-device eval (no API key needed), server binds `:3333`, hooks fire, duck evaluates + speaks + animates + moves servo
- Default eval: Apple Foundation Models (~3B, free, sub-second). Optional: Anthropic API (Claude Haiku) via menu bar toggle.
- Voice input via "ducky [command]" → transcribed → tmux → Claude Code
- Voice permissions: duck asks, you answer yes/no/first/second
- Dashboard at `localhost:3333`, 3D viewer at `localhost:3333/viewer`
- All audio routes through Teensy speaker (not laptop)

**Known limitations:**
- `make debug` (terminal launch) doesn't get macOS mic permissions — use `make run`
- No retry logic on API failures (returns zero scores silently) — applies to both Foundation Models and Anthropic API
- TmuxBridge blocks the calling thread on `waitUntilExit()` — fine for now but could hang if tmux session is missing
- Localhost WebSocket is open to any local process (acceptable for a dev tool)
- Intel Macs: Foundation Models unavailable, must use Anthropic API with key

## What's next: Hardware Expressions + Prompt Refinement

The software is stable. The next phase is about making the duck **feel right** — refining how it physically and vocally reacts to code.

### Hardware Expression Tuning

**Servo behavior:**
- The servo uses spring physics (easing.ino) but the reducer mapping is basic. Experiment with:
  - Tilt angle range (currently maps soundness → base angle)
  - Speed/snap for high-ambition scores
  - Wiggle amplitude and frequency for risky code
  - Whether the duck should "nod" on permission approval or "shake" on deny
- Consider adding a second servo for a different axis of expression (e.g., left-right shake vs up-down nod)

**Chirp synthesis:**
- Current chirps: ascending sweep = positive, descending = negative, sawtooth = risky
- Room to explore: chord progressions, rhythm patterns, different waveforms for different dimensions
- The mixer gain (4.5x) may need adjusting if TTS and chirps fight each other

**LED bar (currently disabled):**
- `LEDControl.ino` exists but `ENABLE_LED_DUCK` is false — no matching NeoPixel hardware yet
- If adding LEDs to the new breadboard, the reducer mapping is already scaffolded

**Button input:**
- Teensy already reads a button for critic/relay mode toggle
- Could add more buttons for quick feedback (thumbs up/down, "say that again")

### Prompt Refinement

**Eval prompts (two separate prompts, one per engine):**
- `LocalEvaluator.swift` — Foundation Models V3 tuned prompt. Uses different dimension names (rigor/craft/novelty) mapped to production names (soundness/elegance/creativity). Int -100...100 scale. See `docs/FOUNDATION-MODELS-RESEARCH.md` for tuning learnings.
- `ClaudeEvaluator.swift` — Anthropic API (Haiku) prompt. Uses production dimension names directly. Double -1.0...1.0 scale.
- The prompts are kept separate — each model has different strengths and the 3B model needs specific prompt engineering (see "Elephant Principle" in research doc).
- Tuning opportunities:
  - Reaction tone: more/less snarky, more domain-specific, seasonal moods
  - Score calibration: both engines tend toward generous — consider adjusting
  - Over-engineering detection: 3B model can't compare "what was asked" vs "what was delivered"

**Permission voice prompts (`PermissionGate.describeSuggestion`):**
- Converts permission suggestions to TTS-friendly labels
- Current labels are functional but could be more natural ("wanna let it read that file?")

**Critic mode prompt:**
- The relay/critic mode (from Phase 2) has its own prompt style — may need alignment with the new eval prompt

### Key files to modify

| What | File | Notes |
|------|------|-------|
| Foundation Models eval | `widget/.../LocalEvaluator.swift` | V3 tuned prompt, @Generable struct, dimension mapping |
| Anthropic API eval | `widget/.../ClaudeEvaluator.swift` | System prompt, reaction style, score calibration |
| Eval provider config | `widget/.../DuckConfig.swift` | `EvalProvider` enum, UserDefaults persistence |
| Permission voice labels | `widget/.../PermissionGate.swift` | `describeSuggestion()` |
| Servo reducer | `firmware/.../ServoControl.ino` | Angle mapping, spring constants |
| Chirp reducer | `firmware/.../I2SAudio.ino` | Frequency, waveform, duration |
| Expression engine | `widget/.../ExpressionEngine.swift` | Score → widget animation mapping |
| Serial protocol | `firmware/.../SerialProtocol.ino` + `widget/.../SerialManager.swift` | If adding new commands |
| Config flags | `firmware/.../Config.h` | Enable/disable hardware features |

### Dev workflow for tuning

```bash
# Widget changes: rebuild and relaunch
cd widget && make run

# Firmware changes: Arduino IDE → Upload, then relaunch widget
# (serial reconnects automatically)

# Test eval without full pipeline
curl -X POST http://localhost:3333/evaluate \
  -H "Content-Type: application/json" \
  -d '{"text":"your test prompt here","source":"test"}'

# Watch live scores
open http://localhost:3333          # dashboard
open http://localhost:3333/viewer   # 3D viewer

# Check logs
tail -f ~/Library/Application\ Support/DuckDuckDuck/DuckDuckDuck.log
```
