# ESP32-S3 Firmware Gap — What to Port from C3

The S3 firmware (`firmware/rubber_duck_esp32/`) is behind the C3 firmware (`firmware/rubber_duck_c3/`). This doc tracks what needs porting and what must NOT be ported.

## Context

The S3 has USB Audio Class (UAC) — its mic and speaker appear as native CoreAudio devices on the Mac. The widget handles TTS and STT through CoreAudio, not serial streaming. The C3 lacks UAC and does all audio over serial binary frames.

## MUST port (non-audio features)

### Identity handshake
- **C3 has**: `I` command → `DUCK,ESP32S3,1.0` / `DUCK,ESP32C3,1.0`
- **S3 missing**: No `I` command handler at all
- **Why needed**: Widget uses identity to determine audio path (UAC vs serial)
- **File**: `SerialProtocol.ino` — add `I` handler

### Chirp synth (plays through I2S, not serial)
- **C3 has**: `ChirpSynth.ino` — sentiment-mapped chirps on eval, permission chirps, startup chirp
- **S3 missing**: No audio output at all
- **Why needed**: Core personality — the duck chirps before speaking
- **Caveat**: On C3, chirps go through the same I2S + ring buffer as streamed TTS. On S3, chirps go through I2S but TTS goes through UAC. Need to ensure chirp I2S setup doesn't conflict with UAC audio path. May need a simpler I2S chirp path that coexists with USB Audio.
- **Files**: `ChirpSynth.ino`, `AudioStream.ino` (only `setupAudio()` and I2S init — NOT the streaming parts)

### Improved servo physics
- **C3 has**: idle cluster (bird-like micro-hops), ambient spring (nag kicks), ambient lerp (idle hops), TTS talking animation, permission nag servo offsets, `chirpServoOffset`
- **S3 missing**: basic idle hop only, no cluster, no ambient spring, no talking anim
- **Why needed**: Much more lifelike motion
- **Files**: `ServoControl.ino` — port the cluster, ambient, and TTS talking sections
- **Config**: Port `IDLE_CLUSTER_*`, `AMBIENT_SPRING_*`, `AMBIENT_LERP_*`, `TTS_*`, `PERMISSION_NAG_*` (servo) constants

### MODE button command
- **C3 has**: Button press sends `MODE\n` to widget (if wired — check)
- **S3 missing**: Button press only cycles demo presets locally
- **Status**: Check if C3 actually sends MODE — may need to verify

### Deferred chirp logic
- **C3 has**: If eval arrives during audio streaming, chirp is deferred until stream ends
- **S3 needs**: Similar but simpler — if chirp is playing when eval arrives, queue the new chirp

## MUST NOT port (streaming-specific)

### Serial audio streaming (`AudioStream.ino` streaming path)
- `audioStreamBegin()`, `audioStreamWrite()`, `audioStreamEnd()`, `audioFeedI2S()`, `isAudioStreaming()`
- Ring buffer (`RING_BUF_SAMPLES`, `RING_BUF_PREFILL`)
- Binary serial framing (`FRAME_MODE_AUDIO`, `FRAME_MODE_CONTROL`)
- The S3 gets TTS audio through UAC, not serial

### Serial mic capture (`MicCapture.ino`)
- ADC/I2S mic → serial binary frame streaming
- `micStreaming`, `micSetMuted()`, `updateMic()`
- The S3's mic appears in CoreAudio via UAC — widget reads from it directly

### Binary serial framing in SerialProtocol
- `readSerialBinary()`, audio mode state machine, `audioMode` flag
- `M,1`/`M,0` mic streaming commands
- `A,16000,16,1` audio mode entry
- The S3 stays in text-only serial mode

### Large serial RX buffer
- `Serial.setRxBufferSize(16384)` — compensates for streaming byte loss
- Not needed at 9600 baud text-only

### Mic-mute-during-TTS (serial path)
- `micSetMuted()` — mutes serial mic during serial TTS
- On S3, the widget's `TTSGate` handles this in CoreAudio

## Port carefully (needs adaptation)

### I2S audio init
- C3's `setupAudio()` configures I2S for the ring buffer + DMA streaming path
- S3 needs I2S for chirp playback only — simpler config, no ring buffer
- May conflict with USB Audio if both try to claim the I2S peripheral
- **Approach**: Set up I2S only for chirp output. USB Audio may use a different mechanism (TinyUSB handles USB audio descriptors and routing separately from I2S)

### USB Audio Class setup (NEW — not in either firmware)
- Neither firmware currently has TinyUSB UAC descriptor configuration
- The S3 needs USB Audio descriptors so macOS sees it as a mic + speaker
- Arduino ESP32 core supports this via `USB.h` + TinyUSB
- The USB product name MUST be "Duck Duck Duck" (widget matches this in CoreAudio)
- **This is the biggest firmware task** — enabling UAC on the S3

## S3 hardware differences to account for

- **Dual I2S ports**: I2S_NUM_0 for mic, I2S_NUM_1 for speaker (C3 has only one)
- **More RAM**: 512KB SRAM vs C3's 400KB — not a concern
- **USB**: Native USB via TinyUSB (C3 uses USB-serial bridge chip)
- **LED driver**: S3 has TLC59711 (12-ch PWM LEDs) — keep this, C3 doesn't have it

## Suggested porting order

1. **Identity handshake** — trivial, unblocks widget testing
2. **Servo improvements** — copy constants + code sections, test
3. **I2S chirp setup** — get basic I2S speaker output working
4. **ChirpSynth** — port the chirp engine, test with I2S
5. **UAC setup** — TinyUSB USB Audio descriptors (research needed)
6. **Integration test** — widget detects S3 UAC, routes audio correctly
