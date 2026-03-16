# TBD — Open Items

## Working-state animation / "thinking" indicator
- When Claude is actively working (not idle), the duck should show it — head bob, whistle, eye animation, something
- Need to explore available plugin hooks to detect when Claude is mid-response vs idle
- Could use `SubAgentStart`/`SubAgentStop` or similar hooks if they exist
- The idle bird head makes sense when nothing is happening, but feels wrong during long tool runs

## UAC hot-swap test
- Need to test swapping in a Teensy (USB Audio Class device) while an ESP32 serial device is connected
- Verify the widget correctly detects the UAC device and switches audio paths
- Verify switching back to ESP32 when Teensy is unplugged

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
