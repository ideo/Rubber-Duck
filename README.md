# Duck Duck Duck

[![Software License: MIT](https://img.shields.io/badge/software-MIT-a31f34.svg)](LICENSE)
[![Hardware License: CERN-OHL-P-2.0](https://img.shields.io/badge/hardware-CERN--OHL--P--2.0-000000.svg)](firmware/LICENSE)

A companion for Claude Code on Mac. It watches your coding sessions, scores every prompt and response, speaks opinionated reactions, and handles permissions by voice. Optionally connects to a [physical duck](https://duck-duck-duck.web.app/) for hardware reactions.

🔒 [**Default intelligence is fully on-device and private.**](#data--privacy) No cloud audio. Your data is not used for training.

## Requirements

- **macOS 26** (Tahoe) or later, Apple Silicon
- **Claude Code** or **Claude Desktop** — [get Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)

## Install

1. Download `DuckDuckDuck.dmg` from [GitHub Releases](https://github.com/ideo/Rubber-Duck/releases)
2. Drag to Applications, launch
3. Grant **Microphone** and **Speech Recognition** when prompted — all audio stays on-device
4. Right-click the duck → **Install Claude Plugin**
5. Open a Claude Code session (CLI or Desktop) — the duck is watching

<details>
<summary>Build from source</summary>

```bash
git clone https://github.com/ideo/Rubber-Duck.git
cd Rubber-Duck/widget
make run
```

Then right-click the duck → **Install Claude Plugin**.

Requires Xcode with Swift 6.2+ (macOS 26 SDK).

</details>

## How It Works

```
You  ──►  🦆 Hardware Duck  ──►  Duck Widget (SwiftUI)  ◄──  Claude Code / Desktop
          mic + speaker          eval engine (Foundation      plugin hooks (prompt,
          servo + LED            Models / Haiku / Gemini)     response, permission)
               ▲                        │
               │                   voice out (TTS)
               └────────────────── servo + LED commands
                                   speaker audio

          (no Duck, Duck, Duck device? laptop mic + speakers work too)
```

1. **Hooks** fire on Claude Code events and POST to the widget's embedded server
2. **Eval engine** scores text on-device via Apple Foundation Models (free, sub-second) — returns scores + a spoken reaction
3. **Widget** animates the duck face, speaks the reaction, optionally drives hardware via USB serial
4. **Voice permissions** — the duck summarizes what Claude wants to do and asks. Say "yes", "always allow", "deny". Foundation Models classifies ambiguous responses.
5. **Voice commands** — say "ducky [command]" to inject text into Claude Code via tmux
6. **Wildcard voice** — score-gated AI picks from 10 voices per reaction (normal, grave, cheerful, dramatic, whisper, etc.)

## Modes

| Mode | What it does | Mic |
|------|-------------|-----|
| **Companion** | Reacts to everything, voice permissions, wake word | On |
| **Permissions Only** | Silent until a permission arrives | On |
| **Companion (No Mic)** | Reacts and speaks, click-only permissions | Off |
| **Relay** (Experimental) | Speak directly to Claude CLI via tmux | On |

## Evaluation

Each prompt and response is scored from -1.0 to +1.0:

| Dimension | What it measures |
|-----------|-----------------|
| **creativity** | Novel/surprising vs boring/obvious |
| **soundness** | Technically solid vs flawed |
| **ambition** | Bold undertaking vs trivial tweak |
| **elegance** | Clean/clear vs hacky/convoluted |
| **risk** | Could break things vs safe |

Defaults to Apple Foundation Models (on-device, free). Switch to Claude Haiku or Gemini Flash from the menu bar for higher-quality scoring. See [Data & Privacy](#data--privacy) for details.

## Voice

| What you say | What happens |
|---|---|
| "ducky, refactor the auth module" | Command sent to Claude Code |
| "yes" / "no" (during permission) | Approves or denies |
| "always allow" (during permission) | Applies the session-wide suggestion |
| "ducky, quit" | Duck says goodbye |

## Troubleshooting

- **"Claude Code not found"** — [Install Claude Code](https://claude.com/download), then retry the plugin install.
- **No mic permission dialog** — System Settings → Privacy & Security → Microphone → enable Duck Duck Duck.
- **Duck not reacting** — Make sure the widget is running (duck in menu bar) and you have an active Claude session. Try `/reload-plugins`.
- **Plugin not loading** — Start a new session. Hooks are cached at session start.

## Data & Privacy

By default, Duck Duck Duck's intelligence is **fully contained to your machine**.

| Component | Where it runs | Data sent externally |
|-----------|--------------|---------------------|
| **Apple Foundation Models** (default) | On-device | None. Private and free. Not used for training. |
| **Voice (STT + TTS)** | On-device via Apple APIs | None. No audio leaves your machine. |
| **Claude Haiku eval** (opt-in) | Anthropic API | Prompts/responses sent to Anthropic for scoring. |
| **Gemini Flash eval** (opt-in) | Google API | Prompts/responses sent to Google for scoring. |

In Foundation Models mode (the default), the entire experience — eval scoring, voice recognition, text-to-speech, and the help system — runs privately on your machine at zero cost. [Apple does not use your interactions to train Foundation Models.](https://machinelearning.apple.com/research/introducing-apple-foundation-models)

**Optional cloud eval:** If you switch to Haiku or Gemini, your prompts and responses are sent directly to the respective API for evaluation. You provide your own API key at your own discretion. Keys are stored locally in `~/Library/Application Support/DuckDuckDuck/` and are never shared. Costs are between you and the API provider. There is no intermediary server — the widget calls the APIs directly.

## Project Structure

```
widget/          SwiftUI macOS app — the duck's brain
plugin/          Claude Code plugin — hooks that connect to the widget
plugin-gemini/   Gemini CLI extension — experimental
firmware/        Arduino firmware for hardware duck (ESP32-S3, Teensy 4.0)
scripts/         Shell scripts (tmux launcher, hook helpers)
```

### Widget (`widget/`)

Self-contained SwiftUI app. Zero external dependencies — Network.framework for HTTP/WS, CryptoKit for WebSocket, Foundation Models for eval.

<details>
<summary>Key components</summary>

**Server:** DuckServer (HTTP+WS on :3333), LocalEvaluator (Foundation Models), ClaudeEvaluator (Haiku), GeminiEvaluator (Flash), PermissionGate, WebSocketBroadcaster, TmuxBridge

**Speech:** SpeechService (orchestrator), STTEngine (Apple Speech), TTSEngine (macOS `say`), SerialMicEngine/SerialTTSEngine (ESP32 audio streaming), WakeWordProcessor, PermissionVoiceGate, PermissionClassifier (Foundation Models fallback), AudioDeviceDiscovery

**UI:** DuckView (liquid glass + animated face), ExpressionEngine (scores → expressions), DuckCoordinator (side effects), MelodyEngine (Jeopardy thinking hum)

**Hardware bridge:** SerialManager (USB serial), SerialTransport (binary framing), EvalService (transport-agnostic)

</details>

### Plugin (`plugin/`)

Hooks fire on Claude Code events and POST to the widget.

| Hook | What it does |
|------|-------------|
| **SessionStart** | Health check — tells Claude if the duck is active |
| **UserPromptSubmit** | Sends your prompt for eval |
| **Stop** | Sends Claude's response for eval |
| **PermissionRequest** | Voice-confirmed permission gate |
| **SessionEnd** | Duck acknowledges session close |
| **PreCompact / PostCompact** | Jeopardy thinking melody during context compaction |
| **StopFailure** | Duck reacts to API errors |
| **PostToolUse** | Clears permission state after CLI approval |

### Hardware (Optional)

Connect the [IDEO Duck, Duck, Duck](https://duck-duck-duck.web.app/) or build your own. The widget auto-detects boards via USB.

<details>
<summary>Supported boards and serial protocol</summary>

**Boards:**
- **ESP32-S3** — primary board. Serial audio streaming (TTS + mic over serial binary frames), servo, speaker, I2S DAC. Firmware: `firmware/rubber_duck_s3/`
- **Teensy 4.0** — DIY option. USB Audio Class (mic + TTS routed as a USB audio interface), servo, I2S DAC. Firmware: `firmware/rubber_duck_teensy40/`
- **ESP32-S3 LED** — LED bar variant. Firmware: `firmware/rubber_duck_s3_led/`

**Serial protocol** (newline-terminated, all boards):
```
I                              → identity request
U,0.20,0.70,0.00,0.60,-0.30   → user eval scores
C,-0.80,0.90,0.30,-0.50,0.80  → claude eval scores
P,1 / P,0                     → permission pending / resolved
```

</details>

## Development

```bash
cd widget && make run       # release build + launch
cd widget && make sandbox   # re-sign with App Sandbox entitlements
cd widget && make debug     # debug build in terminal
cd widget && make dmg       # notarized DMG for distribution
```

### Reducer Pattern

Each output target has its own reducer mapping eval dimensions to what it can express:

| Dimension | Widget | Hardware |
|-----------|--------|----------|
| soundness | eye shape | servo base angle |
| elegance | transition speed | easing smoothness |
| creativity | hue shift + eye widening | frequency range |
| ambition | scale | servo speed |
| risk | rotation angle | oscillation/wiggle |
| thinking | eye darting + Jeopardy hum | — |
| permission | exclamation mark eyes | alert chirp |

<details>
<summary>Gemini CLI support (experimental)</summary>

The duck can also watch [Gemini CLI](https://github.com/google-gemini/gemini-cli) sessions. Install via **Experimental → Install Gemini Extension** in the menu bar. Observe-only — scores and speaks but cannot relay permission decisions.

</details>

## License

Software (widget, plugin, scripts) — [MIT License](LICENSE)

Hardware (firmware, PCB, enclosure) — [CERN Open Hardware Licence v2 — Permissive](firmware/LICENSE)
