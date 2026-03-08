# Phase 2: Hardware — Handoff Doc

## Context

Phase 1 (this branch → merged to main) delivers the full software loop:
- Widget (SwiftUI) — visual duck, speech I/O, serial to Teensy
- Eval service (Python) — Haiku scoring, WebSocket hub, permission gate
- Hook scripts — Claude Code integration (user-prompt, claude-stop, permission)
- Firmware (Teensy 4.0) — serial protocol, servo, LED, piezo

Everything works end-to-end for the Tuesday demo. Phase 2 is about making the physical duck compelling for that demo.

---

## What exists in firmware today

```
firmware/rubber_duck/
├── rubber_duck.ino      # Main loop, serial read, command dispatch
├── SerialProtocol.ino   # Parse incoming serial commands (JSON)
├── ServoControl.ino     # Servo positioning + easing
├── LEDControl.ino       # NeoPixel/LED color control
├── AudioBridge.ino      # USB Audio (Teensy as mic — partial/untested)
└── Easing.ino           # Easing functions for smooth servo motion
```

### Serial protocol (what the widget sends)

The widget's `SerialManager` sends JSON commands over USB serial at 115200 baud:

```json
{"type": "servo", "angle": 45}
{"type": "led", "r": 255, "g": 200, "b": 0}
{"type": "piezo", "freq": 440, "duration": 100}
{"type": "mood", "creativity": 0.5, "soundness": -0.3, ...}
```

The `mood` command sends all five eval dimensions. Firmware maps these to physical behavior.

---

## What needs work for the demo

### 1. Mood-to-motion mapping
The duck receives eval scores but the mapping to physical behavior needs tuning. This is where the personality lives in hardware.

**Dimensions to map:**
| Dimension | Positive (→1.0) | Negative (→-1.0) |
|-----------|-----------------|-------------------|
| creativity | Excited wiggle, rainbow LED | Bored slouch, dim LED |
| soundness | Confident nod, green LED | Nervous shake, red LED |
| ambition | Big motion, bright LED | Small motion, dim |
| elegance | Smooth slow sweep, warm white | Jerky twitch, harsh color |
| risk | Alert posture, orange pulse | Relaxed, steady blue |

The firmware should combine these into a coherent physical reaction — not five independent animations. One "mood pose" per eval.

### 2. Permission wobble
When a permission request arrives, the duck should physically react:
- Servo: nervous wobble/shake
- LED: pulsing yellow/orange (attention needed)
- Piezo: questioning chirp

The widget already sends a distinct command for permission state. Firmware needs to handle it.

### 3. Reaction chirps
Short piezo sounds for key moments:
- Wake word detected: quick rising chirp
- Permission approved: happy double-beep
- Permission denied: sad descending tone
- Eval reaction: varies by mood (happy quack, disappointed buzz, etc.)

### 4. Physical build
- Mount servo(s) in the rubber duck body
- Route LED to be visible (through translucent body or as eyes)
- Position piezo for audible output
- Cable management — single USB to Teensy

---

## What NOT to touch

- **Widget** — working, don't change. It sends serial commands based on eval scores and permission state.
- **Service** — working, don't change. It scores and broadcasts.
- **Hook scripts** — working, don't change. They connect Claude Code to the service.
- **Speech** — working in the widget. Don't move to Teensy (that's phase 3 / ESP32).

---

## Hardware parts

- **Teensy 4.0** — already in use, programmed via Arduino IDE / PlatformIO
- **Servo(s)** — SG90 micro servo (head tilt, possibly body rotate)
- **NeoPixels** — WS2812B strip or ring (mood color)
- **Piezo buzzer** — passive piezo for tones
- **Rubber duck** — the physical enclosure. Needs hollow body for components.

---

## Dev workflow

```bash
# Open Arduino IDE with firmware
open firmware/rubber_duck/rubber_duck.ino

# Or use PlatformIO
cd firmware && pio run --target upload

# Monitor serial output (debug)
screen /dev/tty.usbmodem* 115200

# Test with widget running
cd widget && make run
# Widget auto-detects Teensy and sends commands
```

---

## Success criteria for Tuesday demo

The duck should:
1. **Visibly react** when Claude gives a response — head tilt + LED color change
2. **Wobble nervously** when permission is requested — unmistakable "it's asking you something"
3. **Chirp** on key events — wake word, approval, denial
4. **Feel alive** — smooth easing, not jerky. The motion should have character.

It does NOT need to:
- Be a polished product
- Have perfect mood mapping (we can tune post-demo)
- Support USB audio (phase 3)
- Be wireless (phase 3 / ESP32)
- Look beautiful (it's a prototype with wires showing — that's fine)
