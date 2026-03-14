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

## Wildcard voice — Foundation Models support
- Currently Haiku-only (voice key returned in eval JSON)
- Foundation Models needs a separate second-pass call after eval (can't modify the fragile 3B eval prompt)
- Requires Xcode Playground iteration to tune the voice picker prompt for the 3B model
