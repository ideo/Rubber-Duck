# Phase 2: Hardware — Handoff Doc

## Context

The firmware has evolved significantly from Phase 1. The servo duck now has a full expression system with quacky chirps, spring physics, whistle-servo coupling, permission nagging, and an idle heartbeat. This doc describes the current state.

---

## Firmware architecture

```
firmware/rubber_duck_teensy40/
├── rubber_duck.ino      # Main loop, button handling, permission state machine
├── Config.h             # All config values, data structures, externs
├── SerialProtocol.ino   # CSV serial parser (evals, commands, audio, servo)
├── ServoControl.ino     # Servo reducer, spring physics, calibration, demo presets
├── I2SAudio.ino         # I2S chirp synthesis + TTS mixer + permission chirp
├── LEDControl.ino       # LED bar graph (disabled — no hardware yet)
├── AudioBridge.ino      # USB Audio bridge (mic → USB, USB TTS → speaker)
└── Easing.ino           # Cubic/quartic/quintic ease + lerp
```

### Serial protocol (CSV, newline-terminated, 9600 baud)

**Evaluation scores** (sent by widget):
```
U,0.20,0.70,0.00,0.60,-0.30    # user evaluation
C,0.20,0.70,0.00,0.60,-0.30    # claude evaluation
# Order: creativity, soundness, ambition, elegance, risk (each -1.0 to 1.0)
```

**Permission commands** (sent by widget):
```
P,1     # enter permission pending (starts uh-oh nag loop)
P,0     # permission resolved (stop nagging)
P       # ping (responds with PONG)
```

**Servo commands**:
```
S,90    # set servo to absolute angle (10-170)
S,C     # snap to center
S,?     # report current angle
CAL     # enter calibration mode
N       # advance calibration step
```

**Audio commands**:
```
G,2.5   # set mic gain (0.0-10.0)
M,1     # mute mic (M,0 to unmute)
V       # report audio level (responds with L,0.45)
```

**Test commands**:
```
T       # positive test eval
X       # negative test eval
D       # cycle demo emotion preset (same as button press)
```

---

## Expression system

### How evals become physical reactions

1. **Scores arrive** via serial → parsed into `EvalScores` struct
2. **Servo reducer** maps weighted approval to angle (±80° from center)
   - Approval = 0.35×soundness + 0.25×elegance + 0.20×creativity + 0.10×ambition - 0.10×risk
   - Risk drives oscillation/wiggle amplitude
3. **Chirp reducer** maps sentiment to frequency + chirp pattern
   - Sawtooth waveform → bandpass filter (Q=5) for quack formant
   - Positive: ascending, filter opens "ooo→ehhhh"
   - Negative: descending, filter stays grumbly
   - Very positive (>0.75): double-chirp whistle with servo head bob
   - Very negative (<-0.4): double-chirp "uh-uh" grumble
4. **Spring physics** drives servo smoothly to target (K=0.06, damping=0.82)
5. **Expression decay** — pose held 5s, then springs back to center
6. **Idle heartbeat** — gentle random ±5° hops every 3-8s when at rest

### Demo presets (button or serial `D`)

| # | Name | Feel |
|---|------|------|
| 0 | Impressed | Far right, ascending whistle |
| 1 | Excited | Right, warm chirp |
| 2 | Skeptical | Slight left, mild buzz |
| 3 | Nervous | Center, strong wiggle |
| 4 | Disgusted | Far left, descending grumble |
| 5 | Bored | Near center, flat quiet |

Short press cycles through. Long press (2s) snaps to center.

### Permission nag system

When permission is needed (`P,1`), the duck plays a two-note descending "uh-oh" quack and jiggles. Repeats with backoff:
- **Urgent** (0-30s): every 4-8 seconds
- **Lazy** (30s-2min): every 15-30 seconds
- **Rare** (2min+): every 5-10 minutes

Auto-resolves when any new eval arrives (means session moved on). Widget sends `P,0` on voice approval.

---

## Audio subsystem

### I2S output (MAX98357 DAC)

Chirps + TTS playback through a single speaker:
```
chirpWave (sawtooth) → bandpass filter → mixer ch0 → I2S out
USB TTS input                          → mixer ch1 →
```

### USB Audio (bidirectional)

Teensy appears as a USB microphone + speaker to the Mac:
- **Mic out**: Analog mic (A0) → gain stage → USB output
- **TTS in**: Mac sends speech audio → mixed with chirps → I2S speaker

Requires Arduino IDE USB Type: "Serial + MIDI + Audio"

---

## Config values (Config.h)

All tunable values are `#define`s at the top of Config.h. Key ones:

| Config | Value | What it does |
|--------|-------|-------------|
| `SERVO_CENTER` | 90° | Neutral position |
| `SERVO_RANGE` | ±80° | Max swing from center |
| `SPRING_K` | 0.06 | Spring stiffness |
| `SPRING_DAMPING` | 0.82 | Motion damping |
| `EXPRESSION_HOLD_MS` | 5000 | Hold pose before decay |
| `IDLE_HOP_RANGE` | ±5° | Heartbeat drift range |
| `IDLE_HOP_MIN_MS` / `MAX` | 3000 / 8000 | Time between hops |
| `CHIRP_BASE_FREQ` | 280 Hz | Base chirp pitch |
| `CHIRP_AMPLITUDE` | 0.6 | Chirp volume (0-1) |
| `WHISTLE_SERVO_KICK` | 15° | Head bob during whistle |
| `PERMISSION_NAG_BASE` | 6000 ms | Urgent nag interval |

---

## Widget integration

The widget (SwiftUI) owns serial communication via `SerialManager`:
- **Eval scores** → `sendScores()` on each eval event
- **Permission pending** → `sendCommand("P,1")` when permission arrives
- **Permission resolved** → `sendCommand("P,0")` via three paths:
  1. Direct voice approval → `handlePermissionDecision()`
  2. SwiftUI onChange → `handlePermissionResolved()`
  3. New eval arrives → `handleNewEval()` sends P,0 as safety net

---

## Dev workflow

```bash
# Flash firmware
# Open Arduino IDE, select Teensy 4.0, USB Type: Serial + MIDI + Audio
open firmware/rubber_duck_teensy40/rubber_duck.ino

# Run widget (builds + launches, auto-starts eval service)
cd widget && make run

# Test firmware standalone (Serial Monitor at 9600 baud)
# Send: T (positive eval), X (negative), D (demo cycle)
# Send: P,1 (start nag), P,0 (stop nag)
# Send: S,? (report angle), S,C (snap center)
```
