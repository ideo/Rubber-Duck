# Reverted Changes — To Revisit

These were attempted by Jenna on 2026-04-08 and reverted because they caused regressions. The underlying issues they tried to solve are still valid and need to be addressed.

## 1. Race Condition in SerialTransport

**Commit:** `9361e3e` (reverted in `27e1ba6`)

**Problem being solved:** SerialTransport has race conditions — `fileDescriptor`, `inAudioMode`, and other state is accessed from multiple threads (MainActor, serial read thread, audio streaming thread) without synchronization.

**What Jenna tried:**
- Added `@MainActor` to the entire `SerialTransport` class
- Made `fileDescriptor` `nonisolated(unsafe)` for the real-time write path
- Made `writeBytes()` and `writeFrame()` `nonisolated` so audio streaming doesn't hop to MainActor
- Changed `startReading()` Task.detached to hop back to MainActor for state mutations
- Wrapped dev-watch reconnection handler in `Task { @MainActor }`

**Why it was reverted:** Unclear — may have caused deadlocks or mic streaming issues. The `@MainActor` annotation on the whole class forces all serial I/O through the main thread, which could cause latency in the audio streaming path.

**How to revisit:** The race conditions are real. A better approach might be:
- Use a dedicated serial dispatch queue instead of MainActor
- Or use `os_unfair_lock` for just `fileDescriptor` and `inAudioMode` (like TTSGate)
- Don't make the whole class MainActor — too coarse

**Files:** `SerialTransport.swift`, `SerialTTSEngine.swift`, `DuckProtocol.swift`

## 2. Audio Level Monitor for Dashboard

**Commit:** `2e94145` (reverted in `b9bd75a`)

**Problem being solved:** The debugging dashboard at `localhost:3333` has no way to verify the mic is working. Adding a real-time audio level meter would show mic input levels, audio path state, and listening status.

**What Jenna added:**
- `AudioState` struct in `DuckProtocol.swift` — mic device, speaker device, audio path, listen mode, level
- `onAudioLevel` callback on both `STTEngine` and `SerialMicEngine` — computes RMS from audio buffers
- `SpeechService.buildAudioState()` — snapshot of current audio state
- `startLevelBroadcast()` / `stopLevelBroadcast()` — 10Hz periodic broadcast via WebSocket
- Dashboard HTML updates to display the level meter

**Why it was reverted:** When a physical duck (ESP32) was plugged in, the audio monitor appeared to conflict with the serial mic path. Wake word and mic input stopped working. The STTEngine's audio tap (installed for level metering) may have been competing with the SerialMicEngine for the audio session, or the level broadcast task was interfering with the serial mic's SFSpeechRecognizer.

**How to revisit:**
- Only install the audio tap on whichever STT engine is currently active (not both)
- When `audioPath == .esp32Serial`, don't install a tap on the local STTEngine
- Or compute levels from the serial mic frames directly (no AVAudioEngine tap needed)
- The SerialMicEngine already receives PCM data — compute RMS from those frames instead of adding an audio tap
- Test thoroughly with hardware connected before merging

**Files:** `STTEngine.swift`, `SerialMicEngine.swift`, `SpeechService.swift`, `DuckProtocol.swift`, `RubberDuckWidgetApp.swift`, `Resources/dashboard.html`

## Note

Both issues involved the clean build cache problem discovered on 2026-04-09. After reverting, a stale `.build/` cache caused the old code to persist. `rm -rf .build && make run` was needed to clear it. Always clean build after reverts.
