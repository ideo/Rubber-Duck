# Rubber Duck

A physical IoT companion for Claude Code. It watches your coding sessions, evaluates both your prompts and Claude's responses on multiple dimensions, then expresses its judgment through servo movements, audio chirps, voice, and a desktop widget. You can talk to it — say "ducky" to give voice commands that get injected directly into Claude Code via tmux.

## Architecture

```
                     You (speaking)
                          | voice (electret mic → Teensy USB → Mac)
                          v
               .--- Widget (SwiftUI) ---.
               |  * Apple Speech STT    |
               |  * TTS via say -a      |--------> Teensy speaker
               |  * SerialManager       |  (USB Audio out → I2S DAC)
               |  * ServiceProcess      |
               '---+-------+-------+----'
                   |       |       |
          voice/   |   WebSocket   |   serial (9600 baud)
       permission  |       |       |
                   v       v       v
Claude Code    Eval Service    Teensy 4.0
  (tmux)       (Python :3333)  servo + I2S audio + USB mic
  |-- hooks -----> |               |
  |  UserPrompt    |               | I2S (BCLK=21, LRCLK=20, DIN=7)
  |  Stop          |               v
  |  Permission    |           MAX98357 DAC → Speaker
  '<-- tmux -------'           (chirps + TTS mixed)
    (voice input)
```

### Data Flow

1. **Hooks** fire on Claude Code events (user prompt, response, permission request) and POST to the eval service
2. **Eval service** scores text via Claude Haiku on 5 dimensions, broadcasts results via WebSocket
3. **Widget** receives scores, animates the duck face, speaks reactions via TTS, sends scores to Teensy via serial
4. **Teensy** reacts physically: servo tilts based on sentiment, I2S chirps play through speaker (ascending = positive, descending = negative, buzzy = risky)
5. **Voice input**: say "ducky [command]" — widget transcribes, sends to service, which injects into Claude Code via `tmux send-keys`
6. **Voice permissions**: when Claude needs approval, the duck asks you out loud. Say "yes", "no", "first", "second", etc.
7. **TTS output**: duck voice ("Boing") routes through Teensy USB Audio to the physical speaker via `say -a`, mixed with chirps through the I2S DAC

## Hardware

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
T / X / P                      (test positive / negative / ping)
```

## Voice Interface

Say **"ducky"** followed by a command. The widget transcribes your speech and injects it into Claude Code via tmux.

| What you say | What happens |
|---|---|
| "ducky, refactor the auth module" | Command sent to Claude Code CLI |
| "ducky" (then silence for 3s) | Duck says "Hmm?" and resets |
| "yes" / "no" (during permission) | Approves or denies Claude's action |
| "first" / "second" (during permission) | Selects a numbered suggestion |
| "ducky, quit" | Duck says "See you later" |

### Voice Reliability

- **TTSGate**: Mic input is muted while TTS plays to prevent speaker-to-mic feedback loops
- **Wake word timeout**: 3s after "ducky" with no follow-up text, resets and listens again
- **Command debounce**: 2.5s of silence after wake word before sending (prevents partial transcripts)
- **Recognition watchdog**: 10s timeout restarts speech recognition if it goes silent
- **TTS routing**: `say -a "Teensy MIDI_Audio"` sends voice directly to Teensy USB Audio, bypassing Mac speakers

## Evaluation Dimensions

Each prompt and response is scored from -1.0 to +1.0 on:

- **creativity** — novel/surprising vs boring/obvious
- **soundness** — technically solid vs flawed/naive
- **ambition** — bold undertaking vs trivial tweak
- **elegance** — clean/clear vs hacky/convoluted
- **risk** — could-go-wrong vs safe/predictable

Plus a short gut-reaction quote from the duck (max 10 words).

## Components

### Widget (`widget/`)
SwiftUI macOS app — the duck's brain. Owns all I/O:
- **SpeechService** — Apple Speech STT + `say -a` TTS routed to Teensy speaker (Boing voice)
- **SerialManager** — USB serial to Teensy for eval scores
- **EvalService** — WebSocket client receiving eval scores from service
- **ServiceProcess** — auto-launches the Python eval service, health monitoring, tmux session management
- **DuckView** — animated yellow cube with expression engine, context menu

Right-click menu: Start/Stop Listening, Start Claude Session, status info, Quit.

### Service (`service/`)
Python server on `localhost:3333`. Stateless eval + broadcast:
- `server.py` — eval via Claude Haiku, WebSocket broadcast, permission gate, tmux voice bridge

| Route | Description |
|-------|-------------|
| `/` | Bar chart dashboard |
| `/viewer` | Three.js 3D duck viewer |
| `/ws` | WebSocket for live updates |
| `/evaluate` | POST — trigger evaluation |
| `/permission` | POST — voice permission gate (blocking) |
| `/health` | Service status |

### Scripts (`scripts/`)
- `duck-session` — tmux launcher: Claude Code + eval service in split panes
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

### 3D Viewer (`service/viewer.html`)
Three.js scene with both duck prototypes side by side:
- **Servo Duck** — yellow panel with rotating beak disc, spring physics
- **LED Duck** — green PCB with 10-segment bar graph, piezo sound

## Quick Start

### Prerequisites

- macOS (Apple Speech framework required)
- [Teensy 4.0](https://www.pjrc.com/store/teensy40.html) + [Teensyduino](https://www.pjrc.com/teensy/td_download.html) (for hardware)
- Python 3.10+
- Swift 5.9+ (ships with Xcode)
- tmux (`brew install tmux`)
- Anthropic API key

### Setup

```bash
# 1. Clone and enter repo
git clone https://github.com/ideo/Rubber-Duck.git
cd Rubber-Duck

# 2. Install Python dependencies
cd service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Set API key
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env

# 4. Flash Teensy firmware (Arduino IDE)
#    Board: Teensy 4.0
#    USB Type: Serial + MIDI + Audio
#    Open firmware/rubber_duck/rubber_duck.ino → Upload

# 5. Launch the widget (builds + runs, auto-starts eval service)
cd ../widget
make run
```

### Running

**Widget (recommended):** Launch with `cd widget && make run`. The widget auto-starts the eval service. Right-click the duck to start a Claude Code terminal session (tmux), toggle voice listening, or quit.

**Full session:** `./scripts/duck-session` starts a tmux session with Claude Code in the main pane and the eval service in a split below.

**Debug mode:** `cd widget && make debug` runs in the terminal with full log output (stdout).

**Without hardware:** Everything works except physical servo/audio. The widget still animates, speaks through Mac speakers, and bridges voice to Claude Code.

## Reducer Pattern

The universal evaluation stays rich (5 dimensions). Each output target has its own **reducer** that maps dimensions to what that device can express:

| Dimension | Servo Duck | I2S Audio | Widget |
|-----------|-----------|-----------|--------|
| soundness | base angle | chirp direction | eye shape |
| elegance | easing smoothness | waveform (sine) | transition speed |
| creativity | angle weight | frequency range | color shift |
| ambition | speed | — | breathing |
| risk | oscillation/wiggle | buzzy sawtooth | shake/wobble |
