# Rubber Duck

A physical IoT companion that watches your Claude Code conversations and reacts with opinions. It evaluates both your prompts and Claude's responses on multiple dimensions, then expresses its judgment through physical actuators — a rotating beak, LED bar graph, or piezo chirps. You can also talk to it.

## Architecture

```
                     You (speaking)
                          │ voice
                          ▼
                    Teensy Mic (A0 → USB Audio)
                          │
Claude Code               │
  ├─ UserPromptSubmit ─┐  │
  ├─ Stop ─────────────┤  │
  └─ PermissionRequest ┤  │
                        ▼  ▼
              ┌─── Eval Service ───┐
              │  • Claude Haiku    │
              │  • Speech Engine   │
              │  • Permission Gate │
              └──┬──┬──┬──┬───────┘
                 │  │  │  │
              Widget │  │  Teensy (serial)
            (SwiftUI)│  │  servo/LED/piezo
                     │  │
              Dashboard  3D Viewer
              (browser)  (browser)
```

## Voice Interface

Say **"ducky"** to activate voice input. Your speech is transcribed and sent directly into Claude Code via tmux. The duck is the intermediary — it listens, relays to Claude, evaluates the conversation, and reacts.

**Voice permissions**: When Claude wants to do something risky, the duck asks you out loud. Say "yes" or "no" to approve or deny.

## Evaluation Dimensions

Each prompt and response is scored from -1.0 to +1.0 on:

- **creativity** — novel/surprising vs boring/obvious
- **soundness** — technically solid vs flawed/naive
- **ambition** — bold undertaking vs trivial tweak
- **elegance** — clean/clear vs hacky/convoluted
- **risk** — could-go-wrong vs safe/predictable

Plus a short gut-reaction quote from the duck.

## Components

### Scripts (`scripts/`)
- `duck-session` — tmux launcher: starts Claude Code + eval service together
- `on-user-prompt.sh` — hook: captures user input (UserPromptSubmit)
- `on-claude-stop.sh` — hook: captures Claude's response (Stop)
- `on-permission-request.sh` — hook: voice-gated permission approval
- `start-service.sh` / `stop-service.sh` — service lifecycle management

### Service (`service/`)
Python server on `localhost:3333`:
- `server.py` — eval service, WebSocket broadcast, serial, permission gate
- `speech.py` — unified speech engine (STT + TTS, swappable backend)
- `voice.py` — standalone voice chat mode (legacy, being merged into speech.py)

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
brew install portaudio tmux  # for voice + session management

# 2. Set API key
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env

# 3. Start a duck session (tmux + Claude Code + voice)
cd ..
./scripts/duck-session

# Or start the service alone (no voice, no tmux)
python3 service/server.py --no-speech
```

### Without voice
The hooks fire automatically in any Claude Code session running in this project directory. Kill the service to disable — hooks fail silently with zero overhead.

### With voice
Run `./scripts/duck-session` to get the full experience: tmux session with Claude Code in the top pane, eval service in the bottom. Say "ducky" to speak your prompts.

## Hardware

- **Servo Duck**: MG90S servo on a rotating disc with rubber duck beak
- **LED Duck**: 10-segment LED bar graph on PCB with piezo speaker
- **Teensy 4.0** via USB (auto-detected by service)

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

## Speech Engine

The speech engine (`service/speech.py`) has a swappable backend design:

| Backend | STT | TTS | Status |
|---------|-----|-----|--------|
| Local | Google STT | macOS `say` (Boing) | ✅ Current |
| Realtime API | Claude Realtime | Claude Realtime | 🔮 Future |
| ElevenLabs | — | ElevenLabs API | 🔮 Future |
