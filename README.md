# Duck Duck Duck

A companion for Claude Code (on Mac) that watches your coding sessions, evaluates both your prompts and Claude's responses, then expresses its judgment through voice, a liquid-glass desktop widget, and (optionally) physical hardware. Say "ducky" to give voice commands that get injected directly into Claude Code.

## Install

**Hardware is optional.** The widget works standalone — voice, eval scoring, and the desktop duck all work without any physical components.

### Option A: Download (recommended)

1. Download `DuckDuckDuck.app` from [GitHub Releases](https://github.com/ideo/Rubber-Duck/releases)
2. Move to Applications and launch — works immediately with on-device eval (no API key needed)
3. Click **"Install Claude Plugin"** from the 🦆 menu bar icon
4. Open Claude Code in any repo — the duck is watching

### Option B: Build from source

```bash
git clone https://github.com/ideo/Rubber-Duck.git
cd Rubber-Duck/widget
make run
```

Then click **"Install Claude Plugin"** from the 🦆 menu bar.

### Option C: Manual plugin install

If you prefer CLI commands instead of the menu bar button:

```bash
claude plugin marketplace add ideo/Rubber-Duck
claude plugin install duck-duck-duck
```

### Requirements

- macOS 26+ (Tahoe) with Apple Silicon
- Claude Code 1.0.33+
- tmux for voice commands (`brew install tmux`)

**Eval engine:** Defaults to Apple Foundation Models (free, on-device, sub-second). Optionally switch to Anthropic API (Claude Haiku) or Google Gemini Flash from the 🦆 menu bar for higher-quality scoring — requires an API key.

## Architecture

```
                          Claude Code / Desktop
                                 |
                                 | hooks (UserPrompt, Stop, Permission)
                                 v
    .------------- Duck Duck Duck Widget (SwiftUI) --------------.
    |                                                             |
    |   Eval Engine          Voice               UI              |
    |   Foundation Models    Apple Speech STT     Liquid glass    |
    |   (or Haiku/Gemini)    macOS TTS            duck face       |
    |                        Wildcard voices      expressions     |
    |                        Permission gate      menu bar        |
    |                                                             |
    |   HTTP+WS Server (:3333)          Serial (USB)             |
    '--------+--------------------+-----------+------------------'
             |                    |           |
             v                    v           ^  v
         Dashboard            Voice →     Physical duck
         localhost:3333       Claude CLI  mic + servo + speaker
                              (tmux)           |
                                               ^
                                          You (speaking)
```

### How it works

1. **Hooks** fire on Claude Code events (prompt, response, permission) and POST to the widget on `:3333`
2. **Eval engine** scores the text on-device via Apple Foundation Models (default, free, sub-second) — returns scores + a spoken reaction
3. **Widget** animates the duck face, speaks the reaction via TTS, and optionally sends scores to physical hardware via USB serial
4. **Voice permissions**: when Claude needs approval, the duck summarizes the action and asks. Say "yes", "always allow", "deny", etc. Foundation Models classifies ambiguous responses.
5. **Voice commands**: say "ducky [command]" to inject text into Claude Code via tmux
6. **Wildcard voice**: score-gated AI picks the best voice per reaction from 10 voices (normal, grave, cheerful, dramatic, whisper, etc.)

## Hardware

### Bill of Materials

| Component | Qty | Role | Notes |
|-----------|-----|------|-------|
| **Teensy 4.0** | 1 | Main controller | USB Type: Serial + MIDI + Audio |
| **MG90S micro servo** | 1 | Sentiment tilt | Pin 3 (PWM), 4.8V from USB |
| **MAX98357 I2S DAC** | 1 | Audio amplifier | BCLK=21, LRCLK=20, DIN=7 |
| **Mini oval speaker** 8Ω 1W | 1 | Chirps + TTS voice | [Adafruit 3923](https://www.adafruit.com/product/3923) |
| **Electret microphone** (with breakout/amp) | 1 | Voice input to Mac | Pin A0 (analog) → USB Audio |
| **Tactile button** | 1 | Mode toggle (critic/relay) | Pin 2 (internal pullup) |
| **JST PH 2-pin cable** (male, 20cm) | 1 | Speaker connector | [Adafruit 3814](https://www.adafruit.com/product/3814) |
| **JST PH 2-pin jack** (PCB mount) | 1 | Speaker receptacle | [Adafruit 4714](https://www.adafruit.com/product/4714) |
| **Breadboard** | 1 | Prototyping base | Half-size works |
| **Micro USB cable** | 1 | Power + data | Teensy to Mac |
| **Hookup wire** | — | Connections | 22 AWG solid core |

### Current Build

| Component | Role | Connection |
|-----------|------|------------|
| **Teensy 4.0** | Main controller | USB (Serial + MIDI + Audio) |
| **MG90S servo** | Sentiment tilt | Pin 3 (PWM) |
| **MAX98357 I2S DAC** | Audio amplifier | BCLK=21, LRCLK=20, DIN=7 |
| **Speaker** | Chirps + TTS voice | Wired to MAX98357 output |
| **Electret mic** | Voice input to Mac | Pin A0 (analog) → USB Audio |

### Firmware Configuration (`Config.h`)

```
ENABLE_SERVO_DUCK  true    // MG90S on pin 3
ENABLE_LED_DUCK    false   // No matching LED hardware yet
ENABLE_I2S_AUDIO   true    // MAX98357 I2S DAC
ENABLE_USB_AUDIO   true    // Teensy as USB mic + TTS receiver
```

### Audio Pipeline

The Teensy handles bidirectional audio over a single USB connection:

- **Mic out** (Teensy → Mac): `AudioInputAnalog(A0) → gain → AudioOutputUSB` — Mac sees "Teensy MIDI/Audio" as a mic input
- **TTS in** (Mac → Teensy): `AudioInputUSB → mixer(4.5x gain) → AudioOutputI2S` — mixed with chirp synthesis
- **Chirps**: `AudioSynthWaveform → mixer → AudioOutputI2S` — frequency-swept sine/sawtooth based on eval scores

### Arduino IDE Settings

- **Board**: Teensy 4.0
- **USB Type**: Serial + MIDI + Audio
- **CPU Speed**: 600 MHz (default)

### Serial Protocol

**Text mode** (newline-terminated, all boards):
```
I                              (identity request → "DUCK,ESP32S3,1.0" or "DUCK,TEENSY40,1.0")
U,0.20,0.70,0.00,0.60,-0.30   (user eval: creativity,soundness,ambition,elegance,risk)
C,-0.80,0.90,0.30,-0.50,0.80  (claude eval)
P,1                            (permission pending — duck awaits voice response)
P,0                            (permission resolved — back to normal)
A,16000,16,1                   (enter binary audio mode — ESP32 only)
M,1 / M,0                     (start/stop mic streaming — ESP32 only)
T / X / P                      (test positive / negative / ping)
```

**Binary audio mode** (ESP32 only, between `A,<rate>,<bits>,<ch>` and `A,0`):
```
0x01 [len_hi] [len_lo] [PCM bytes...]   audio frame
0x02 [len_hi] [len_lo] [text bytes...]   control message (evals during TTS)
0x04 [len_hi] [len_lo] [PCM bytes...]   mic frame (ESP32 → widget)
```

## Voice Interface

Say **"ducky"** followed by a command. The widget transcribes your speech and injects it into Claude Code via tmux.

| What you say | What happens |
|---|---|
| "ducky, refactor the auth module" | Command sent to Claude Code CLI |
| "ducky" (then silence for 3s) | Duck says "Hmm?" and resets |
| "yes" / "no" (during permission) | Approves or denies (varied responses: "Got it.", "Approved.", "Nope.", etc.) |
| "first" / "second" (during permission) | Selects a numbered suggestion |
| "ducky, quit" | Duck says "Quack! See you later." |

### Voice Reliability

- **TTSGate**: Mic input is muted while TTS plays to prevent speaker-to-mic feedback loops
- **Wake word timeout**: 3s after "ducky" with no follow-up text, resets and listens again
- **Command debounce**: 2.5s of silence after wake word before sending (prevents partial transcripts)
- **Recognition watchdog**: 10s timeout restarts speech recognition if it goes silent
- **TTS routing**: `say -a "Teensy MIDI_Audio"` sends voice directly to Teensy USB Audio, bypassing Mac speakers
- **Smart permission prompts**: Instead of bare tool names ("Bash. Allow?"), the duck summarizes the action ("Run git. Allow?", "Edit DuckServer. Allow?")
- **Response variety**: Acknowledgments rotate through phrase pools to avoid sounding robotic

## Evaluation Dimensions

Each prompt and response is scored from -1.0 to +1.0 on:

- **creativity** — novel/surprising vs boring/obvious
- **soundness** — technically solid vs flawed/naive
- **ambition** — bold undertaking vs trivial tweak
- **elegance** — clean/clear vs hacky/convoluted
- **risk** — could-go-wrong vs safe/predictable

Plus a short gut-reaction quote from the duck (max 10 words) and a one-line summary.

## Components

### Widget (`widget/`)
SwiftUI macOS app — the duck's brain. Self-contained: no external services needed. The widget is a borderless, always-on-top liquid-glass window using macOS Tahoe's `.glassEffect()` for real desktop refraction. The duck's face (eyes, beak, cheeks) floats on the glass surface with animated expressions driven by eval scores.

**Server (embedded):**
- **DuckServer** — zero-dependency HTTP + WebSocket server on `:3333` built on Network.framework (`MiniServer`)
- **LocalEvaluator** — on-device eval via Apple Foundation Models (~3B, free, default)
- **ClaudeEvaluator** — calls Anthropic Messages API directly via URLSession (Claude Haiku, optional)
- **GeminiEvaluator** — calls Google Generative Language API (Gemini Flash, optional)
- **GeminiExtensionInstaller** — copies Gemini CLI extension hooks to `~/.gemini/extensions/`
- **PermissionGate** — actor-based async blocking until voice response or 30s timeout
- **WebSocketBroadcaster** — fans out eval results and permission events to dashboard/viewer clients
- **TmuxBridge** — injects voice commands into Claude Code via `tmux send-keys`
- **LocalEvalTransport** — in-process delivery of eval results (no WebSocket round-trip for the widget itself)

**Speech:**
- **SpeechService** — orchestrates STT, TTS, wake word detection, and permission voice gate; protocol-based dispatch (STTBackend/TTSBackend) switches between local and serial audio paths
- **STTEngine** — Apple Speech framework recognition with Teensy mic input (CoreAudio)
- **SerialMicEngine** — ESP32 mic via serial binary frames → SFSpeechRecognizer (nonisolated frame handling)
- **TTSEngine** — `say -a` TTS routed to Teensy speaker (local path)
- **SerialTTSEngine** — AVSpeechSynthesizer → 16kHz PCM → serial binary stream to ESP32 speaker
- **RecognitionRestartController** — shared exponential-backoff restart + silence watchdog for both STT engines
- **WakeWordProcessor** — "ducky" detection and command extraction
- **PermissionVoiceGate** — yes/no/ordinal word matching for permission responses
- **AudioDeviceDiscovery** — CoreAudio enumeration, Teensy detection, hot-plug handling

**UI:**
- **DuckView** — liquid-glass duck with animated face, exclamation-mark eyes during permissions, darting eye thinking animation, context menu
- **ExpressionEngine** — reducer mapping eval dimensions to visual state (eye shape, beak, glow, hue shift)
- **DuckTheme** — colors, sizes, spring physics constants
- **DuckCoordinator** — orchestrates side effects (serial, TTS, expression updates, melody) in response to eval events
- **MelodyEngine** — pitch-shifts a vocal sample ("Mmmm") through the Jeopardy "Think!" melody via AVAudioEngine + AVAudioUnitTimePitch; ~10% chance easter egg while Claude is thinking

**Hardware bridge:**
- **SerialManager** — USB serial with identity handshake (supports Teensy and ESP32 boards)
- **SerialTransport** — event-driven /dev watch (DispatchSource) + binary framing for audio mode
- **EvalService** — transport-agnostic eval result handler (supports both local and WebSocket transports)

**App icon:**
- `assets/duckIcon.icon/` — Apple Icon Composer bundle (`.icon` format) with layered eyes + beak on yellow fill
- Compiled via `xcrun actool` in the Makefile → `.icns` + `Assets.car` in app bundle Resources

**Menu bar (🦆):** Intelligence picker (Foundation Models / Haiku / Gemini), voice mode (Off / Permissions Only / Wake Word), Launch Claude Code, Experimental submenu (Launch Gemini CLI, Install Gemini Extension), Install Claude Plugin, Launch at Login selector, Show/Hide Duck, Quit. All items have SF Symbol icons.

**Right-click menu:** Launch Claude Code, Experimental (Launch Gemini CLI), Mode selector (Critic / Relay), Voice selector (Off / Permissions Only / Wake Word), Quit.

### Server Routes (`:3333`)

| Route | Description |
|-------|-------------|
| `GET /` | Bar chart dashboard |
| `GET /viewer` | Three.js 3D duck viewer |
| `GET /ws` | WebSocket for live updates |
| `POST /evaluate` | Trigger evaluation (called by hooks) |
| `POST /permission` | Voice permission gate — blocks until response |
| `POST /permission-gemini` | Gemini CLI notification (speak-only, no relay) |
| `GET /health` | Server status JSON |

### Plugin (`plugin/`)
Claude Code plugin — installed via `claude plugin install duck-duck-duck`. Hooks fire on Claude Code events and POST to the widget's server.

| Hook | What it does |
|------|-------------|
| **SessionStart** | Health check — tells Claude if the duck is active |
| **UserPromptSubmit** | Sends your prompt to the duck for eval scoring |
| **Stop** | Sends Claude's response for eval scoring |
| **PermissionRequest** | Asks the duck (via voice) whether to allow the action |

### Gemini CLI Support (Experimental)

The duck can also watch [Gemini CLI](https://github.com/google-gemini/gemini-cli) sessions. Install via **Experimental → Install Gemini Extension** in the 🦆 menu bar, or manually copy `gemini-extension.json` to `~/.gemini/extensions/`.

**Limitations:** Gemini CLI hooks are observe-only — the duck scores prompts/responses and speaks notification alerts for permission requests, but cannot relay approval decisions back. You must approve permissions manually in the terminal.

| Hook | What it does |
|------|-------------|
| **OnNotification** | Scores eval text and speaks permission alerts (notification-only) |

### Scripts (`scripts/`)
- `duck-session` — tmux launcher for Claude Code (widget must be running)

### Firmware

Three firmware variants for different boards, all sharing the same serial protocol:

**`firmware/rubber_duck/`** — Teensy 4.0 (USB Audio path)

| File | Role |
|------|------|
| `rubber_duck.ino` | Main setup/loop, score parsing |
| `Config.h` | Pin assignments, feature flags, data structures |
| `ServoControl.ino` | MG90S servo with spring physics |
| `I2SAudio.ino` | Chirp synthesis + TTS mixer → MAX98357 I2S DAC |
| `AudioBridge.ino` | Bidirectional USB Audio (mic out + TTS in) |
| `SerialProtocol.ino` | Score parsing, test commands, ping |

**`firmware/rubber_duck_c3/`** — ESP32-C3/S3 (serial audio streaming path)

| File | Role |
|------|------|
| `rubber_duck_c3.ino` | Main setup/loop, permission state machine |
| `Config.h` | Pin assignments, I2S/ring buffer/mic config, data structures |
| `ServoControl.ino` | LEDC PWM servo with spring physics + idle clusters |
| `AudioStream.ino` | Ring buffer between serial input and I2S DMA output |
| `ChirpSynth.ino` | Software synth: sawtooth → Chamberlin SVF bandpass → I2S |
| `MicCapture.ino` | ADC mic (C3) or PDM mic (S3 Sense) → serial binary frames |
| `SerialProtocol.ino` | Text + binary audio framing parser |

**`firmware/rubber_duck_esp32/`** — XIAO ESP32 (LED bar variant)

### 3D Viewer (`widget/Sources/RubberDuckWidget/Resources/viewer.html`)
Three.js scene with both duck prototypes side by side:
- **Servo Duck** — yellow panel with rotating beak disc, spring physics
- **LED Duck** — green PCB with 10-segment bar graph, piezo sound

## Development

### Building from source

Requires Xcode with Swift 6.2+ (swift-tools-version: 6.2, Swift 5 language mode).

```bash
cd widget && make run       # release build + launch (unsandboxed, full features)
cd widget && make sandbox   # release build + re-sign with App Sandbox entitlements
cd widget && make debug     # debug build in terminal (mic may not work)
cd widget && make release   # notarize for GitHub distribution
```

`make run` and `make sandbox` use the same binary — the only difference is the codesign entitlements. Flip between them freely to test sandbox behavior.

**Two distribution tiers:**
- **App Store** (sandbox) — critic mode + eval + TTS + voice permissions
- **Developer Edition** (GitHub release, notarized) — everything + relay mode (tmux voice → CLI)

### Running

The widget starts an embedded HTTP+WebSocket server on `:3333`. Use the 🦆 menu bar to start a Claude Code terminal session (tmux), install the plugin, toggle voice, or change settings.

**Full session:** `./scripts/duck-session` starts a tmux session with Claude Code.

### Hardware (optional)

**Teensy 4.0** — Flash `firmware/rubber_duck/` via Arduino IDE. Board: Teensy 4.0, USB Type: Serial + MIDI + Audio.

**ESP32-C3/S3** — Flash `firmware/rubber_duck_c3/` via Arduino IDE. Board: XIAO ESP32-C3 or XIAO ESP32-S3 Sense. Streams TTS audio over serial (no USB Audio Class needed).

See [Hardware](#hardware) section for wiring.

## Reducer Pattern

The universal evaluation stays rich (5 dimensions). Each output target has its own **reducer** that maps dimensions to what that device can express:

| Dimension | Servo Duck | I2S Audio | Widget |
|-----------|-----------|-----------|--------|
| soundness | base angle | chirp direction | eye shape (round → squint) |
| elegance | easing smoothness | waveform (sine) | transition speed |
| creativity | angle weight | frequency range | hue shift + eye widening |
| ambition | speed | — | scale |
| risk | oscillation/wiggle | buzzy sawtooth | rotation angle |
| thinking | — | — | eye darting (6-pos grid) + Jeopardy hum (10%) |

**Permission state**: Eyes become `!` exclamation marks, subtle warm glow. Teensy receives `P,1` (pending) and `P,0` (resolved).

**Thinking state**: While Claude is working, the duck's eyes dart randomly between 6 positions (3 top, 3 bottom) with varied timing. ~10% of the time, the duck hums the Jeopardy "Think!" melody — pitch-shifted vocal sample played note-by-note through AVAudioEngine.

**Off state**: Turn Off from the 🦆 menu silences everything — no evals, no speech, no serial commands, no reactions. An X appears over the beak. Hardware receives nothing. Turn On resumes normal operation.

## License

Software (widget, plugin, scripts) is licensed under the [MIT License](LICENSE).

Hardware designs (firmware, PCB, enclosure) are licensed under the [CERN Open Hardware Licence Version 2 — Permissive](firmware/LICENSE).
