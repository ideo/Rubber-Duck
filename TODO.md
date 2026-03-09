# Rubber Duck — TODO

## ✅ Done

- [x] **PermissionRequest hook** — voice-gated permissions (say "yes" to approve)
- [x] **Unified speech engine** (`service/speech.py`) — swappable STT/TTS backend
- [x] **Voice → Claude Code bridge** — say "ducky [command]" → tmux send-keys
- [x] **tmux session launcher** (`scripts/duck-session`)
- [x] **USB Audio firmware** — Teensy mic (A0) → USB Audio → Mac, TTS playback via I2S
- [x] **macOS floating widget** — SwiftUI yellow cube with expression engine
- [x] **Mac `say` TTS** — Boing voice for duck reactions
- [x] **Plugin script structure** (`scripts/`) — portable hooks
- [x] **I2S chirp engine** — sawtooth → bandpass filter, sentiment-driven quacks
- [x] **Double-chirp patterns** — whistle (very positive) and uh-uh (very negative)
- [x] **Whistle-servo coupling** — head bobs synced to chirp pitch hills
- [x] **Expression decay** — poses spring back to center after 5s hold
- [x] **Idle heartbeat** — gentle ±5° random drift when duck is at rest
- [x] **Demo button presets** — 6 emotions (Impressed→Bored) cycled by button press
- [x] **Permission nag system** — "uh-oh" chirp with 3-tier backoff (urgent→lazy→rare)
- [x] **Widget ↔ Teensy permission wiring** — P,1/P,0 serial commands for nag lifecycle
- [x] **Critic/Relay voice modes** — toggle via Teensy button or widget menu

## 🔮 Next: Realtime API Migration

Replace Google STT + macOS `say` with a unified Realtime API backend:
- Implement `RealtimeBackend` in `speech.py` conforming to existing interface
- Bidirectional streaming: speak naturally, duck responds in real-time
- Tool use: duck takes actions (approve permissions, relay to Claude, control hardware)
- The duck becomes a conversational intermediary with its own agency
- Single config change swaps the backend

## 🔮 Next: ESP32-S3 Standalone

ESP32-S3 variant that connects to Realtime API directly over WiFi:
- No Mac needed — the duck IS the device
- Built-in mic + speaker + WiFi
- Serial still works for servo/LED/piezo control
- Could run alongside Teensy or replace it entirely

## Speech / Audio Output

### Option A: Talkie Library (on-device LPC synthesis)
- 1980s Speak & Spell style speech running directly on Teensy
- ~1000 word vocabulary (sp_GOOD, sp_BAD, sp_DANGER, etc.)
- Output through piezo or small speaker on PWM pin (pin 9)
- Lo-fi, robotic, charming — fits the rubber duck character
- Libraries: [PaulStoffregen/Talkie](https://github.com/PaulStoffregen/Talkie) or [ArminJo/Talkie](https://github.com/ArminJo/Talkie)
- Could map eval dimensions to word sequences: "GOOD CODE" / "DANGER" / "ERROR"

### Option C: Bluetooth audio from Mac → device
- Pipe Mac TTS audio over Bluetooth to a speaker on the duck
- Requires: BT receiver module + amplifier + speaker
- Most immersive result but more hardware complexity
- Alternative: USB audio bidirectional (Teensy receives audio from Mac)

## Three.js Viewer Refinement
- Improve beak geometry on servo duck
- Improve PCB details on LED duck
- Tune reducer mappings for more expressive animation
- Add sound to Three.js LED duck to match hardware chirps
- Add permission state visualization

## Widget Refinement
- Tooltip showing reaction text on hover
- Right-click context menu (settings, quit, toggle TTS)
- Menubar icon alternative mode
- Localization: add more languages to String Catalog
- Custom duck face expressions (more eye/beak states)

## Hardware
- Test Talkie library on Teensy 4.0 with piezo
- Consider upgrading piezo to small speaker + amp for better audio
- Test external 5V servo power with full eval loop
- Test USB Audio quality from Teensy mic
- Explore adding Bluetooth module for audio streaming
