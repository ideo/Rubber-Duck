# Rubber Duck

A physical IoT companion that watches your Claude Code conversations and reacts with opinions. It evaluates both your prompts and Claude's responses on multiple dimensions, then expresses its judgment through physical actuators — a rotating beak, LED bar graph, or piezo chirps.

## Architecture

```
Claude Code Hooks ──> Python Service ──> Claude API (Haiku eval)
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
                Dashboard   3D Viewer   Teensy/Serial
                (bars)     (Three.js)   (hardware)
```

## Evaluation Dimensions

Each prompt and response is scored from -1.0 to +1.0 on:

- **creativity** — novel/surprising vs boring/obvious
- **soundness** — technically solid vs flawed/naive
- **ambition** — bold undertaking vs trivial tweak
- **elegance** — clean/clear vs hacky/convoluted
- **risk** — could-go-wrong vs safe/predictable

Plus a short gut-reaction quote from the duck.

## Components

### Hooks (`.claude/hooks/`)
Shell scripts that fire on Claude Code events:
- `on-user-prompt.sh` — captures user input (UserPromptSubmit)
- `on-claude-stop.sh` — captures Claude's response (Stop)

Both POST to the local evaluation service asynchronously.

### Service (`service/`)
Python server on `localhost:3333`:
- Receives hook payloads, calls Claude Haiku for multi-dimensional eval
- Pushes results to browser dashboards via WebSocket
- Sends scores to Teensy over USB serial (auto-detected)

**Endpoints:**
| Route | Description |
|-------|-------------|
| `/` | Bar chart dashboard |
| `/viewer` | Three.js 3D duck viewer |
| `/ws` | WebSocket for live updates |
| `/evaluate` | POST endpoint for evals |
| `/health` | Service status |

### 3D Viewer (`service/viewer.html`)
Three.js scene with both duck prototypes side by side:
- **Servo Duck** — yellow panel with rotating beak disc, spring physics
- **LED Duck** — green PCB with 10-segment bar graph, piezo sound

Both react to the same evaluation data with different expression vocabularies.

### Firmware (`firmware/rubber_duck/`)
Teensy 4.0 / Arduino firmware:
- Receives evaluation scores over serial
- Drives servos, NeoPixel LEDs, and piezo via reducers
- Spring physics on servo, staggered LED fill, frequency-swept chirps
- Both duck types can run on a single Teensy (pins don't conflict)

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

# 2. Set API key
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env

# 3. Start the service
python3 server.py

# 4. Open dashboard or 3D viewer
open http://localhost:3333
open http://localhost:3333/viewer
```

The hooks fire automatically in any Claude Code session running in this project directory. Kill the service to disable — hooks fail silently with zero overhead.

## Hardware

- **Servo Duck**: MG90S servo on a rotating disc with rubber duck beak
- **LED Duck**: 10-segment LED bar graph on PCB with piezo speaker
- **Teensy 4.0** via USB (auto-detected by service)

Flash `firmware/rubber_duck/` via Arduino IDE / PlatformIO with Teensyduino.

## Reducer Pattern

The universal evaluation stays rich (5 dimensions). Each output target has its own **reducer** that maps dimensions to what that device can express:

| Dimension | Servo Duck | LED Duck |
|-----------|-----------|----------|
| soundness | base angle | fill level |
| elegance | easing smoothness | sweep style |
| creativity | angle weight | brightness |
| ambition | speed | intensity |
| risk | oscillation/wiggle | buzzy chirp |
