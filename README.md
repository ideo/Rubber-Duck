# Rubber Duck

A physical IoT companion for Claude Code. It watches your coding sessions, evaluates both your prompts and Claude's responses on multiple dimensions, then expresses its judgment through physical actuators, voice, and a desktop widget. You can talk to it — say "ducky" to give voice commands, and it'll approve or deny Claude's actions on your behalf.

## Architecture

```
                     You (speaking)
                          | voice
                          v
               .--- Widget (SwiftUI) ---.
               |  * Apple Speech STT    |
               |  * macOS say TTS       |
               |  * SerialManager       |
               |  * ServiceProcess      |
               '---+-------+-------+----'
                   |       |       |
          voice/   |   WebSocket   |   serial
       permission  |       |       |
                   v       v       v
Claude Code    Eval Service    Teensy 4.0
  |            (Python :3333)  servo/LED/piezo
  |-- hooks -----> |
  |  UserPrompt    |
  |  Stop          |
  |  Permission    |
  '<-- tmux -------'
    (voice input)
```

### Data Flow

1. **Hooks** fire on Claude Code events (user prompt, response, permission request) and POST to the eval service
2. **Eval service** scores text via Claude Haiku on 5 dimensions, broadcasts results via WebSocket
3. **Widget** receives scores, animates the duck face, speaks reactions via TTS, sends scores to Teensy via serial
4. **Voice input**: say "ducky [command]" — widget transcribes, sends to service, which injects into Claude Code via tmux
5. **Voice permissions**: when Claude needs approval, the duck asks you out loud. Say "yes" or "no".

## Voice Interface

Say **"ducky"** to activate voice input. Your speech is transcribed and sent into Claude Code via tmux. The duck is the intermediary — it listens, relays to Claude, evaluates the conversation, and reacts.

**Voice permissions**: When Claude wants to do something risky, the duck asks you out loud. Say "yes" or "no" to approve or deny. This works via the `PermissionRequest` hook — the hook blocks, the service broadcasts to the widget, the widget asks via voice, and the response flows back.

## Evaluation Dimensions

Each prompt and response is scored from -1.0 to +1.0 on:

- **creativity** — novel/surprising vs boring/obvious
- **soundness** — technically solid vs flawed/naive
- **ambition** — bold undertaking vs trivial tweak
- **elegance** — clean/clear vs hacky/convoluted
- **risk** — could-go-wrong vs safe/predictable

Plus a short gut-reaction quote from the duck.

## Components

### Widget (`widget/`)
SwiftUI macOS app — the duck's brain. Owns all I/O:
- **SpeechService** — Apple Speech STT + macOS `say` TTS (Boing voice)
- **SerialManager** — USB serial to Teensy for servo/LED/piezo
- **EvalService** — WebSocket client receiving eval scores
- **ServiceProcess** — auto-launches the Python eval service, health monitoring
- **DuckView** — animated yellow cube with expression engine, context menu
- Right-click menu: Start/Stop Listening, Start Claude Session, status info, Quit

Build and run:
```bash
cd widget && make run
```

### Scripts (`scripts/`)
- `duck-session` — tmux launcher: starts Claude Code + eval service together
- `on-user-prompt.sh` — hook: captures user input (UserPromptSubmit)
- `on-claude-stop.sh` — hook: captures Claude's response (Stop)
- `on-permission-request.sh` — hook: voice-gated permission approval (blocking)
- `start-service.sh` / `stop-service.sh` — service lifecycle management

### Service (`service/`)
Python server on `localhost:3333`. Stateless eval + broadcast — no speech, no serial (widget owns those):
- `server.py` — eval via Claude Haiku, WebSocket broadcast, permission gate, tmux bridge

**Endpoints:**
| Route | Description |
|-------|-------------|
| `/` | Bar chart dashboard |
| `/viewer` | Three.js 3D duck viewer |
| `/ws` | WebSocket for live updates |
| `/evaluate` | POST — trigger evaluation |
| `/permission` | POST — voice permission gate (blocking) |
| `/health` | Service status |

### 3D Viewer (`service/viewer.html`)
Three.js scene with both duck prototypes side by side:
- **Servo Duck** — yellow panel with rotating beak disc, spring physics
- **LED Duck** — green PCB with 10-segment bar graph, piezo sound

### Firmware (`firmware/rubber_duck/`)
Teensy 4.0 / Arduino firmware:
- Receives evaluation scores over serial
- Drives servos, NeoPixel LEDs, and piezo via reducers
- Spring physics on servo, staggered LED fill, frequency-swept chirps

**Pins:** Servo=3, NeoPixel=6, Piezo=9

**Serial protocol:**
```
U,0.20,0.70,0.00,0.60,-0.30   (user eval)
C,-0.80,0.90,0.30,-0.50,0.80  (claude eval)
T / X / P                      (test positive / negative / ping)
```

## Quick Start

```bash
# 1. Install dependencies
cd service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
brew install tmux  # for voice input bridge

# 2. Set API key
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env

# 3. Launch the widget (builds + runs, auto-starts eval service)
cd ../widget
make run

# 4. Or start a full duck session (tmux + Claude Code + service)
cd ..
./scripts/duck-session
```

### Widget only (recommended)
Launch the widget app — it auto-starts the eval service. Right-click the duck to start a Claude Code terminal session, toggle listening, or quit. Hooks fire automatically for any Claude Code session in this project directory.

### Without voice
The hooks fire automatically in any Claude Code session running in this project directory. Kill the service to disable — hooks fail silently with zero overhead.

## Hardware

- **Servo Duck**: MG90S servo on a rotating disc with rubber duck beak
- **LED Duck**: 10-segment LED bar graph on PCB with piezo speaker
- **Teensy 4.0** via USB (auto-detected by widget's SerialManager)

Flash `firmware/rubber_duck/` via Arduino IDE / PlatformIO with Teensyduino.

## Reducer Pattern

The universal evaluation stays rich (5 dimensions). Each output target has its own **reducer** that maps dimensions to what that device can express:

| Dimension | Servo Duck | LED Duck | Widget |
|-----------|-----------|----------|--------|
| soundness | base angle | fill level | eye shape |
| elegance | easing smoothness | sweep style | transition speed |
| creativity | angle weight | brightness | color shift |
| ambition | speed | intensity | breathing |
| risk | oscillation/wiggle | buzzy chirp | shake/wobble |
