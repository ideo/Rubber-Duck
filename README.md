# Rubber Duck

A physical IoT companion for Claude Code. It watches your coding sessions, evaluates both your prompts and Claude's responses on multiple dimensions, then expresses its judgment through servo movements, audio chirps, voice, and a liquid-glass desktop widget. You can talk to it — say "ducky" to give voice commands that get injected directly into Claude Code via tmux.

## Architecture

```
                     You (speaking)
                          | voice (electret mic → Teensy USB → Mac)
                          v
               .--- Widget (SwiftUI) ---------.
               |  * Apple Speech STT          |
               |  * TTS via say -a            |--------> Teensy speaker
               |  * SerialManager             |  (USB Audio out → I2S DAC)
               |  * Embedded HTTP+WS Server   |
               |    (MiniServer :3333)         |
               '---+-------+-------+----------'
                   |       |       |
          voice/   |   WebSocket   |   serial (9600 baud)
       permission  |       |       |
                   v       v       v
Claude Code    Dashboard/    Teensy 4.0
  (tmux)       Viewer        servo + I2S audio + USB mic
  |-- hooks -----> |               |
  |  UserPrompt    |               | I2S (BCLK=21, LRCLK=20, DIN=7)
  |  Stop          |               v
  |  Permission    |           MAX98357 DAC → Speaker
  '<-- tmux -------'           (chirps + TTS mixed)
    (voice input)
```

### Data Flow

1. **Hooks** fire on Claude Code events (user prompt, response, permission request) and POST to the widget's embedded server on `:3333`
2. **ClaudeEvaluator** scores text via Claude Haiku on 5 dimensions, returns scores + reaction + summary
3. **Widget** receives scores in-process via `LocalEvalTransport`, animates the duck face, speaks reactions via TTS, sends scores to Teensy via serial
4. **WebSocketBroadcaster** fans out results to any connected dashboard/viewer clients
5. **Teensy** reacts physically: servo tilts based on sentiment, I2S chirps play through speaker (ascending = positive, descending = negative, buzzy = risky)
6. **Voice input**: say "ducky [command]" — widget transcribes, TmuxBridge injects into Claude Code via `tmux send-keys`
7. **Voice permissions**: when Claude needs approval, the duck summarizes the action and asks ("Run git. Allow?"). Say "yes", "no", "first", "second", etc.
8. **TTS output**: duck voice ("Boing") routes through Teensy USB Audio to the physical speaker via `say -a`, mixed with chirps through the I2S DAC

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

```
U,0.20,0.70,0.00,0.60,-0.30   (user eval: creativity,soundness,ambition,elegance,risk)
C,-0.80,0.90,0.30,-0.50,0.80  (claude eval)
P,1                            (permission pending — duck awaits voice response)
P,0                            (permission resolved — back to normal)
T / X / P                      (test positive / negative / ping)
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
- **ClaudeEvaluator** — calls Anthropic Messages API directly via URLSession (Claude Haiku)
- **PermissionGate** — actor-based async blocking until voice response or 30s timeout
- **WebSocketBroadcaster** — fans out eval results and permission events to dashboard/viewer clients
- **TmuxBridge** — injects voice commands into Claude Code via `tmux send-keys`
- **LocalEvalTransport** — in-process delivery of eval results (no WebSocket round-trip for the widget itself)

**Speech:**
- **SpeechService** — orchestrates STT, TTS, wake word detection, and permission voice gate
- **STTEngine** — Apple Speech framework recognition with Teensy mic input
- **TTSEngine** — `say -a` TTS routed to Teensy speaker (Boing voice)
- **WakeWordProcessor** — "ducky" detection and command extraction
- **PermissionVoiceGate** — yes/no/ordinal word matching for permission responses
- **AudioDeviceDiscovery** — CoreAudio enumeration, Teensy detection

**UI:**
- **DuckView** — liquid-glass duck with animated face, exclamation-mark eyes during permissions, context menu
- **ExpressionEngine** — reducer mapping eval dimensions to visual state (eye shape, beak, glow, hue shift)
- **DuckTheme** — colors, sizes, spring physics constants
- **DuckCoordinator** — orchestrates side effects (serial, TTS, expression updates) in response to eval events

**Hardware bridge:**
- **SerialManager** — USB serial to Teensy for eval scores
- **EvalService** — transport-agnostic eval result handler (supports both local and WebSocket transports)

**App icon:**
- `assets/duckIcon.icon/` — Apple Icon Composer bundle (`.icon` format) with layered eyes + beak on yellow fill
- Compiled via `xcrun actool` in the Makefile → `.icns` + `Assets.car` in app bundle Resources

Right-click menu: Start Claude Session, Start/Stop Listening, Mode Toggle, status info, Quit.

### Server Routes (`:3333`)

| Route | Description |
|-------|-------------|
| `GET /` | Bar chart dashboard |
| `GET /viewer` | Three.js 3D duck viewer |
| `GET /ws` | WebSocket for live updates |
| `POST /evaluate` | Trigger evaluation (called by hooks) |
| `POST /permission` | Voice permission gate — blocks until response |
| `GET /health` | Server status JSON |

### Scripts (`scripts/`)
- `duck-session` — tmux launcher for Claude Code (widget must be running)
- `on-user-prompt.sh` — hook: captures user input (UserPromptSubmit)
- `on-claude-stop.sh` — hook: captures Claude's response (Stop)
- `on-permission-request.sh` — hook: voice-gated permission approval (blocking)

### Firmware (`firmware/rubber_duck/`)
Teensy 4.0 Arduino firmware — multi-file sketch:

| File | Role |
|------|------|
| `rubber_duck.ino` | Main setup/loop, score parsing |
| `Config.h` | Pin assignments, feature flags, data structures |
| `ServoControl.ino` | MG90S servo with spring physics |
| `I2SAudio.ino` | Chirp synthesis + TTS mixer → MAX98357 I2S DAC |
| `AudioBridge.ino` | Bidirectional USB Audio (mic out + TTS in) |
| `LEDControl.ino` | NeoPixel LED bar (currently disabled) |
| `SerialProtocol.ino` | Score parsing, test commands, ping |
| `Easing.ino` | Quintic easing for servo smoothness |

### 3D Viewer (`widget/Sources/RubberDuckWidget/Resources/viewer.html`)
Three.js scene with both duck prototypes side by side:
- **Servo Duck** — yellow panel with rotating beak disc, spring physics
- **LED Duck** — green PCB with 10-segment bar graph, piezo sound

## Quick Start

### Prerequisites

- macOS Tahoe (26.0+) — required for `.glassEffect()` liquid glass
- Xcode with Swift 6.2+ (widget builds with `swift-tools-version: 6.2`, Swift 5 language mode)
- [Teensy 4.0](https://www.pjrc.com/store/teensy40.html) + [Teensyduino](https://www.pjrc.com/teensy/td_download.html) (for hardware)
- tmux (`brew install tmux`)
- Anthropic API key (prompted on first launch, stored in `~/.duck/api_key`)

### Setup

```bash
# 1. Clone and enter repo
git clone https://github.com/ideo/Rubber-Duck.git
cd Rubber-Duck

# 2. Set API key (pick one — or skip; the widget prompts on first launch)
export ANTHROPIC_API_KEY=sk-ant-...          # env var (session)
echo "sk-ant-..." > ~/.duck/api_key          # persistent file
echo "ANTHROPIC_API_KEY=sk-ant-..." > widget/.env    # .env in widget dir
# If none set, the widget opens a dialog on first launch and saves to ~/.duck/api_key

# 3. Flash Teensy firmware (Arduino IDE)
#    Board: Teensy 4.0
#    USB Type: Serial + MIDI + Audio
#    Open firmware/rubber_duck/rubber_duck.ino → Upload

# 4. Launch the widget (builds + runs, starts embedded server)
cd widget
make run
```

### Running

**Widget (recommended):** Launch with `cd widget && make run`. The widget starts an embedded HTTP+WebSocket server on `:3333`. Right-click the duck to start a Claude Code terminal session (tmux), toggle voice listening, or quit.

**Full session:** `./scripts/duck-session` starts a tmux session with Claude Code in the main pane.

**Debug mode:** `cd widget && make debug` runs in the terminal with full log output. Note: mic permissions may not work in this mode — use `make run` for full functionality.

**Without hardware:** Everything works except physical servo/audio. The widget still animates, speaks through Mac speakers, and bridges voice to Claude Code.

## Reducer Pattern

The universal evaluation stays rich (5 dimensions). Each output target has its own **reducer** that maps dimensions to what that device can express:

| Dimension | Servo Duck | I2S Audio | Widget |
|-----------|-----------|-----------|--------|
| soundness | base angle | chirp direction | eye shape (round → squint) |
| elegance | easing smoothness | waveform (sine) | transition speed |
| creativity | angle weight | frequency range | hue shift + eye widening |
| ambition | speed | — | scale |
| risk | oscillation/wiggle | buzzy sawtooth | rotation angle |

**Permission state**: Eyes become `!` exclamation marks, subtle warm glow. Teensy receives `P,1` (pending) and `P,0` (resolved).
