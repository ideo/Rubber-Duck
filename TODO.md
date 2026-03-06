# Rubber Duck — TODO

## Speech / Audio Output

Explore speech output from the duck device itself. Three approaches to evaluate:

### Option A: Talkie Library (on-device LPC synthesis)
- 1980s Speak & Spell style speech synthesis running directly on Teensy
- ~1000 word vocabulary (sp_GOOD, sp_BAD, sp_DANGER, etc.)
- Output through piezo or small speaker on PWM pin
- Lo-fi, robotic, extremely charming — fits the rubber duck character perfectly
- Teensy 4.0 has no DAC, must use PWM pin (pin 9 works)
- Libraries: [PaulStoffregen/Talkie](https://github.com/PaulStoffregen/Talkie) or [ArminJo/Talkie](https://github.com/ArminJo/Talkie)
- Limitation: fixed vocabulary, can't say arbitrary text
- Could map eval dimensions to word sequences: "GOOD CODE" / "DANGER" / "ERROR"

### Option B: Mac `say` command (host-side TTS)
- Full arbitrary text-to-speech via macOS
- Fun novelty voices: Boing, Zarvox, Whisper, Good News, Bad News, Jester
- Can speak the duck's reaction quote verbatim
- Plays through Mac speakers, not the duck device itself
- Zero latency, zero dependencies

### Option C: Bluetooth audio from Mac → device
- Pipe Mac TTS audio over Bluetooth to a speaker on the duck
- Would give arbitrary speech coming FROM the physical duck
- Requires: Bluetooth audio receiver module (e.g. BT board with I2S/analog out) + small amplifier + speaker
- Teensy 4.0 doesn't have native Bluetooth — would need an add-on module (HC-05, ESP32 as co-processor, or standalone BT audio receiver board)
- More hardware complexity but the most immersive result
- Alternative: USB audio gadget mode (Teensy as USB audio device receiving from Mac)

### Recommendation
Start with **Option A (Talkie) + Option B (Mac say) running simultaneously**. The duck speaks lo-fi keywords through its own speaker while the Mac provides the full reaction quote. Evaluate whether Bluetooth (Option C) is worth the added complexity later.

## Voice Input (Microphone)
- Teensy has mic on A0 (proven in metro_0.1 tuner mode)
- Could detect ambient audio energy, typing patterns, voice tone
- macOS dictation already works for voice → text → Claude Code input
- Explore: duck listens and reacts to audio environment independent of text eval

## Permission Hook
- Add `PermissionRequest` hook to capture when Claude asks for permissions
- Duck could react nervously / excitedly when Claude wants to do something risky

## Three.js Viewer Refinement
- Improve beak geometry on servo duck
- Improve PCB details on LED duck
- Tune reducer mappings for more expressive animation
- Add sound to Three.js LED duck to match hardware chirps

## Hardware
- Test Talkie library on Teensy 4.0 with piezo
- Consider upgrading piezo to small speaker + amp for better audio
- Test external 5V servo power with full eval loop
- Explore adding Bluetooth module for audio streaming
