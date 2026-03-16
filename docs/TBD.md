# TBD — Open Items

## ~~Working-state animation / "thinking" indicator~~ ✓ DONE
- Eyes dart randomly between 6 positions (3×2 grid) while Claude is thinking
- ~10% chance: hums Jeopardy "Think!" melody (pitch-shifted "Mmmm" sample via AVAudioEngine)
- 120s timeout safety net auto-clears if session crashes
- Triggered by user eval → cleared by Claude eval

## ~~Duck off = truly off~~ ✓ DONE
- Turn Off from menu silences everything: no evals, no speech, no serial, no reactions
- X indicator over beak mouth when off
- Hardware (Teensy/ESP32) gets nothing when off — fully silent

## UAC audio — S3 launch readiness
- S3 boards are the likely launch hardware — UAC audio path needs to be rock solid
- Test USB Audio Class mic input from S3 (not just Teensy) — verify sample rate, format, latency
- Test TTS output via `say -a` to S3 UAC device — verify routing, volume, no clipping
- Test hot-plug behavior: S3 plugged in mid-session → widget detects and switches audio paths
- Test hot-unplug: S3 removed mid-session → falls back to local Mac mic + speakers cleanly
- Test swap: S3 connected while ESP32 serial device is also connected → correct device wins
- Verify `AudioDeviceDiscovery.findTeensy()` naming works for S3 (device name may differ)
- Test MelodyEngine routing to S3 UAC device (outputDeviceID)

## Wildcard voice — tuning
- Two-pass Foundation Models implementation works (LocalEvaluator: score → LocalVoicePick)
- Currently defaults to Superstar for almost everything — only switches on extreme scores
- Could use more Playground iteration to make voice picks more expressive/varied
- Whisper might work well for skepticism — "I'm not sure about this..." inner-doubt moments
- Removed bubbles (too weird). Now 10 wildcard voices.

## Wake word in critic mode
- "Ducky" wake word works in relay mode (sends commands to Claude via tmux)
- In critic mode there's no tmux session — wake word triggers but has nothing to do
- Options: disable wake word in critic, or give it a critic-specific role
- Could speak last eval summary on demand: "ducky, how am I doing?" → recap scores
- Could speak a verbal status: "I'm watching. Things are looking rough."

## 3D duck viewer
- Three.js viewer at localhost:3333/viewer exists but was never fully dialed in
- Both duck prototypes (servo + LED) render but need polish
- Could become a fun showpiece if the models and animations get proper attention
