# Hardware Migration: Teensy 4.0 → ESP32-C3

## Status: Planned (not started)

## Why

The Teensy 4.0 works but it's overpowered and expensive for what the duck actually needs. The XIAO ESP32-C3 is $5, tiny, has USB-C, and covers every pin we use. The one catch — USB Audio class — is solved by streaming TTS audio from the widget over serial and playing it via I2S on the ESP32.

## What the Teensy currently does

| Function | Teensy feature | Pins |
|----------|---------------|------|
| Servo PWM | Hardware PWM | Pin 3 |
| I2S speaker output | I2S peripheral → MAX98357 DAC | BCLK=21, LRCLK=20, DIN=7 |
| USB Audio out (mic) | USB Audio class — appears as USB mic to macOS | USB (built-in) |
| USB Audio in (TTS) | USB Audio class — Mac routes `say` audio here | USB (built-in) |
| Chirp synthesis | Teensy Audio library (waveform + bandpass filter) | Internal (I2S output) |
| Serial comms | USB Serial (CDC) | USB (built-in) |
| Button input | Digital input with pullup | Pin 11 |
| Piezo (unused) | PWM | Pin 9 (wired but not driven) |
| Analog mic | ADC input → USB Audio output | A0 |

Active pins: 5 (servo, button, I2S BCLK/LRCLK/DIN) + USB

## Why ESP32-C3, not ESP32-S3

The S3 has USB OTG and could theoretically do USB Audio class via TinyUSB UAC2. But:

- TinyUSB UAC2 on ESP32-S3 is complex — manual descriptor setup, isochronous transfers, composite device config
- The Teensy Audio library made USB Audio trivial; there's no equivalent on ESP32
- The serial streaming approach is simpler and works on **both** C3 and S3
- C3 is cheaper, lower power, and has everything we need
- We already proved the XIAO ESP32-S3 works for the LED duck — the C3 is the same form factor, even simpler

The S3 stays in the LED duck. The C3 takes over from the Teensy.

## The big change: TTS audio streaming

### Current (Teensy)

```
macOS                          Teensy
  say -a "Teensy" "Hello" ───→ USB Audio In ──→ I2S mixer ──→ MAX98357 speaker
                                                      ↑
                                              chirp synthesis
```

macOS sees the Teensy as a USB sound card. `say` routes audio directly. Zero widget involvement.

### New (ESP32-C3)

```
Widget (macOS)                              ESP32-C3
  AVSpeechSynthesizer                         │
    → capture PCM samples                     │
    → stream over USB CDC serial  ──────────→ ring buffer ──→ I2S DMA ──→ MAX98357 speaker
                                                                   ↑
                                                           chirp synthesis
```

The widget renders TTS to audio samples using `AVSpeechSynthesizer.write(_:toBufferCallback:)`, then streams raw PCM over USB serial. The ESP32 buffers and plays via I2S.

### Why this works

**Bandwidth:** USB CDC serial on ESP32-C3 runs at USB Full Speed (12 Mbps). Speech audio at 16kHz 16-bit mono = 32 KB/s. That's 2.6% of available bandwidth. Even at 22kHz it's trivial.

**Latency:** The widget can start streaming as soon as the first audio buffer arrives from AVSpeechSynthesizer. With a ~100ms ring buffer on the ESP32, perceived latency is negligible — the duck starts talking almost immediately.

**Buffering:** ESP32-C3 has 400KB SRAM. A 200ms ring buffer at 16kHz/16-bit = 6.4KB. Plenty of room.

## Interruption handling

The critical question: what happens when a Claude event (eval score, permission request) arrives while TTS audio is streaming?

### Answer: the widget controls both streams, so it arbitrates

All serial data flows **widget → ESP32**. The widget is the single sender. It knows when it's streaming audio and when an eval arrives. Strategies, in order of preference:

**1. Interleave control messages in the audio stream**

The audio streaming protocol uses a binary mode with framing. Text-mode control messages (`C,0.72,...\n` or `P,1\n`) can be sent between audio frames during natural gaps:

```
[audio frame 1: 512 bytes PCM]
[audio frame 2: 512 bytes PCM]
C,0.72,0.85,0.40,0.61,-0.20\n     ← eval arrives, widget sends during frame gap
[audio frame 3: 512 bytes PCM]
```

The ESP32 parser knows whether it's in audio mode or text mode (based on the framing protocol). A text line during audio mode gets parsed as a control command and the audio ring buffer continues playing — no audible gap.

At 32 KB/s audio rate, a ~30-byte score message takes <1ms to send. The ring buffer covers it.

**2. Chirps preempt TTS**

When an eval triggers a chirp, the duck should react physically — chirp + servo move — even if it was mid-sentence. The widget can:

1. Pause the audio stream (stop sending PCM frames)
2. Send the eval score message
3. ESP32 plays its chirp (synthesized locally, same as today)
4. After chirp finishes (~300-1500ms), widget resumes streaming

This feels natural — the duck interrupts itself to react, then continues. Like someone going "wait, hold on — *chirp* — anyway, as I was saying..."

**3. Permission events stop TTS entirely**

If `P,1` arrives, the duck should stop talking and start its uh-oh nag loop. Widget cancels the current TTS stream, sends `P,1`, and the ESP32 takes over with permission chirps. When permission resolves, widget can restart TTS if needed.

### Summary of interrupt behavior

| Event | During TTS? | Behavior |
|-------|------------|----------|
| Eval score (no chirp) | Yes | Interleave — send score between audio frames, no audible gap |
| Eval score (with chirp) | Yes | Pause TTS, send score, ESP32 chirps, resume TTS |
| Permission request | Yes | Cancel TTS, send P,1, ESP32 nags |
| Permission resolve | N/A | Send P,0, optionally restart TTS |
| Serial score (no TTS playing) | No | Same as today — just a text line |

## Serial protocol changes

### Current protocol (text-only, 9600 baud)

```
U,0.20,0.70,0.00,0.60,-0.30\n    eval scores
P,1\n                              permission enter
P,0\n                              permission resolve
S,90\n                             servo command
G,2.5\n                            mic gain
T\n / X\n / D\n                    test commands
```

### New protocol (text + binary audio)

Keep all existing text commands unchanged. Add audio framing:

```
# Audio start — switches ESP32 to binary receive mode
A,16000,16,1\n                     sample rate, bit depth, channels

# Raw PCM frames (binary, length-prefixed)
[2 bytes: frame length (little-endian uint16)]
[N bytes: raw PCM samples]
...repeat...

# Audio stop — switches ESP32 back to text mode
A,0\n

# All existing text commands work identically
C,0.72,0.85,0.40,0.61,-0.20\n
P,1\n
```

**Frame size:** 512 samples × 2 bytes = 1024 bytes per frame at 16kHz = one frame every 32ms. This is a comfortable DMA-friendly chunk.

**Baud rate:** Bump from 9600 to USB CDC native speed. The USB CDC interface doesn't have a real baud rate — the `termios` baud setting is ignored for USB CDC devices. The actual throughput is governed by USB Full Speed framing. But we should set a high nominal value (921600) for compatibility with serial monitors and to signal that the link is fast.

**Mid-stream control messages:** During audio streaming, the widget can send a text line (ending in `\n`) between frames. The ESP32 parser checks each received chunk: if it starts with a printable ASCII character and contains `\n`, it's a text command. If it starts with the 2-byte length prefix (which will be a value like `0x00 0x04` — never a printable ASCII character for reasonable frame sizes), it's an audio frame.

Actually simpler: use a **mode byte** prefix for every chunk during audio mode:

```
0x01 [len_hi] [len_lo] [PCM data...]    → audio frame
0x02 [text line ending in \n]            → control message during audio
```

Outside of audio mode (before `A,...\n` or after `A,0\n`), everything is plain text like today.

## Pin mapping: Teensy → XIAO ESP32-C3

| Function | Teensy pin | ESP32-C3 pin | Notes |
|----------|-----------|-------------|-------|
| Servo PWM | 3 | D0 (GPIO2) | LEDC PWM, same as ESP32-S3 duck |
| Button | 11 | D1 (GPIO3) | Internal pullup |
| I2S BCLK | 21 | D2 (GPIO4) | |
| I2S LRCLK (WS) | 20 | D3 (GPIO5) | |
| I2S DIN (data out) | 7 | D4 (GPIO6) | |
| Serial | USB | USB | CDC, no change |
| Analog mic | A0 | — | Dropped (see below) |

**Mic input:** The Teensy's analog mic (A0) fed USB Audio output so macOS could use it as a microphone. With the serial streaming approach, there's no USB Audio device for macOS to use. The mic function moves entirely to the Mac (built-in mic or external). The hot-unplug fallback code already handles this — `SpeechService` falls back to the default mic when no Teensy audio device is detected. For the C3, this is just the permanent state.

If we ever want a duck-mounted mic, the C3 has an ADC — wire an analog mic and add a serial command to report levels. But the Mac mic works fine for voice commands.

## Chirp synthesis on ESP32

The Teensy uses its Audio library for chirp synthesis: `AudioSynthWaveform` → `AudioFilterStateVariable` → `AudioOutputI2S`. This is a fixed-function DSP pipeline with sample-level mixing.

On ESP32-C3, we reimplement chirps in a simpler way:

**Option A: Software synthesis into the I2S DMA buffer**

Generate chirp samples directly in the I2S write callback. The ESP32 I2S driver uses DMA double-buffering — fill one buffer while the other plays. During TTS streaming, the ring buffer feeds the DMA. During chirps, a synthesis function writes directly to the DMA buffer instead.

Mixing chirps with TTS: same idea as the Teensy mixer — add chirp samples to TTS samples in the DMA callback. The chirp generator (sawtooth + filter) runs at the I2S sample rate.

**Option B: Pre-rendered chirp tables**

Pre-compute a few chirp waveforms (ascending, descending, uh-oh) as raw PCM arrays in flash. Play them by copying into the I2S DMA buffer. Much simpler than real-time synthesis but less expressive — no per-eval frequency variation.

**Recommendation: Option A.** The chirp reducer already computes start/end frequencies per eval. Real-time synthesis preserves the duck's personality. The bandpass filter is just a biquad — trivial to run on the C3's RISC-V core at 16kHz.

## Widget changes

### SerialTransport.swift

- Device discovery: scan for `tty.usbmodem*` (C3 shows up as USB CDC, same pattern)
  - May need to update `DuckConfig.serialDevicePrefix` if the C3 uses a different prefix (check with `ls /dev/tty.*` after plugging in)
- Add `sendAudio(samples:sampleRate:)` method
- Add audio streaming state management (start/stop/pause)

### TTSEngine.swift

Current: shells out to `/usr/bin/say -v Boing -a "Teensy MIDI_Audio"`. The `say` command routes audio directly to the Teensy's USB Audio device. Simple, reliable, supports all installed voices.

New: We need raw PCM samples to stream over serial.

**Winner: `AVSpeechSynthesizer.write(_:toBufferCallback:)`**

Tested on macOS Tahoe. Results:

| Approach | Latency to first audio | Streaming? | Boing voice? |
|----------|----------------------|-----------|-------------|
| `AVSpeechSynthesizer.write()` | ~200ms (first buffer) | Yes — 256-frame chunks arrive as rendered | Yes — `com.apple.speech.synthesis.voice.Boing` |
| `say -o file.wav` | ~560ms (must render entire file first) | No — file must complete before reading | Yes |
| `say -o /dev/stdout` | N/A | **Doesn't work** — `say` needs a seekable file (writes header, seeks back) | — |

`AVSpeechSynthesizer.write()` benchmarks (tested):
- **20x realtime** render speed (4.69s of audio rendered in 233ms)
- **22050 Hz, mono, 16-bit** PCM buffers — ideal for serial streaming
- **203ms** to first buffer — ESP32 ring buffer covers this easily
- Boing voice confirmed available: identifier `com.apple.speech.synthesis.voice.Boing`
- Requires a running RunLoop (our app has one — it's a SwiftUI app)

Note: `write()` returns all buffers near-instantly (much faster than realtime). The widget paces serial transmission to match the ESP32's I2S playback rate, preventing buffer overrun.

```swift
let synth = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: text)
utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.speech.synthesis.voice.Boing")

synth.write(utterance) { buffer in
    guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
        // Done — end audio stream
        serialTransport.sendAudioEnd()
        return
    }
    // Stream 256-frame chunks to ESP32 over serial
    serialTransport.sendAudioFrames(pcm)
}
```

This replaces the `/usr/bin/say` process entirely. No more shelling out, no file I/O, proper framework API. The voice sounds identical — both use the same synthesis engine under the hood.

### SerialManager.swift

- Add `streamTTS(_ text: String)` method that coordinates TTSEngine + SerialTransport
- Add interruption logic: eval arrives → pause/cancel stream → send score → resume/restart
- Expose `isSpeaking` state for UI

### DuckConfig.swift

- `serialDevicePrefix`: may need updating for C3 device name
- `teensyAudioDeviceName`: remove or rename to generic `duckAudioDeviceName`
- Remove Teensy-specific audio device detection (no longer a USB Audio device)

### SpeechService.swift / AudioDeviceDiscovery

- Remove Teensy audio device switching logic — Mac mic is always the mic
- Remove hot-unplug fallback (or simplify: the "fallback" is now the only path for mic input)
- STT always uses Mac's default mic

## Firmware changes

### New: `firmware/rubber_duck_c3/`

Fork from `firmware/rubber_duck/`, adapted for ESP32-C3 + Arduino framework:

| File | Changes from Teensy version |
|------|---------------------------|
| `Config.h` | ESP32-C3 pin defines, LEDC config, remove USB Audio config |
| `rubber_duck_c3.ino` | ESP32 setup/loop, LEDC servo init, I2S init |
| `SerialProtocol.ino` | Add binary audio frame parsing, mode switching |
| `ServoControl.ino` | Replace Servo library with LEDC PWM (already proven on ESP32-S3 duck) |
| `I2SAudio.ino` | Replace Teensy Audio library with ESP-IDF I2S driver + software synthesis |
| `AudioBridge.ino` | **Delete** — no USB Audio bridge, replaced by serial streaming |
| `AudioStream.ino` | **New** — ring buffer, DMA feeding, TTS+chirp mixing |
| `Easing.ino` | No changes — pure math |
| `LEDControl.ino` | Drop (no LEDs on this duck) or keep stub |

### Key ESP32-C3 APIs

```c
// I2S output (ESP-IDF driver, Arduino-compatible)
#include <driver/i2s.h>

i2s_config_t i2s_config = {
    .mode = I2S_MODE_MASTER | I2S_MODE_TX,
    .sample_rate = 16000,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .dma_buf_count = 4,
    .dma_buf_len = 512,
};

// Servo via LEDC (already working on ESP32-S3 duck)
ledcAttach(SERVO_PIN, 50, 16);  // 50Hz, 16-bit resolution
ledcWrite(SERVO_PIN, pulseToDuty(angleToPulse(degrees)));
```

### Ring buffer design

```
           write ptr (widget serial data arrives here)
              ↓
┌─────────────────────────────────────┐
│ PCM samples │ PCM samples │ empty   │
└─────────────────────────────────────┘
              ↑
           read ptr (I2S DMA reads from here)

Size: 4096 samples (8KB) = 256ms at 16kHz
Underrun: play silence (brief gap, recovers on next frame)
Overrun: drop oldest (shouldn't happen — widget paces sends)
```

When a chirp plays, the chirp synthesizer writes directly to a separate buffer that gets mixed (sample-level add) with the ring buffer output before going to I2S DMA.

## Migration steps

### Phase 1: Proof of concept

1. Wire ESP32-C3 + MAX98357 + servo + button on breadboard
2. Write minimal firmware: I2S output plays a test tone, servo sweeps
3. Verify I2S pin mapping and audio quality

### Phase 2: Serial audio streaming

4. Implement ring buffer + I2S DMA feeding on ESP32
5. Add `A,...\n` audio mode to serial parser
6. Test: send raw PCM from Mac via `screen` or Python script → hear it on speaker
7. Implement chirp synthesis (sawtooth + biquad bandpass) mixed into I2S output

### Phase 3: Widget integration

8. Add `AVSpeechSynthesizer` PCM capture to TTSEngine
9. Add audio streaming to SerialTransport
10. Add interruption logic to SerialManager
11. Remove Teensy audio device detection from SpeechService
12. Test full loop: Claude event → eval → duck chirps + talks

### Phase 4: Cleanup

13. Update `DuckConfig.serialDevicePrefix` if needed
14. Update CLAUDE.md, HANDOFF.md, phase-2-hardware-handoff.md
15. Test permission flow (nag chirps interrupt TTS correctly)
16. Test hot-plug/unplug (SerialTransport reconnect loop)

## Bill of materials

| Part | Price | Notes |
|------|-------|-------|
| Seeed XIAO ESP32-C3 | ~$5 | USB-C, tiny, WiFi/BLE (unused but free) |
| MAX98357A I2S DAC | ~$4 | Same board as Teensy duck |
| Small speaker | ~$2 | Same as Teensy duck |
| Micro servo (SG90) | ~$3 | Same as Teensy duck |
| Momentary button | ~$0.50 | Same |
| **Total** | **~$15** | vs ~$30 for Teensy 4.0 alone |

## What we lose

- **USB Audio device** — macOS can't route arbitrary audio to the duck. TTS is widget-controlled only. If you want to play music through the duck speaker, that won't work anymore. (It barely worked before — the duck speaker is tiny.)
- **USB mic** — the duck can't act as a microphone for macOS. Voice input uses the Mac's mic exclusively. (This is already the fallback behavior.)
- **Teensy Audio library** — no declarative audio graph. Chirps are hand-rolled DSP. More code but more control.
- **Raw CPU power** — Teensy 4.0 is a 600MHz Cortex-M7. ESP32-C3 is a 160MHz RISC-V. More than enough for our workload (serial parsing, chirp synthesis, servo updates, I2S DMA) but no headroom for heavy DSP if we ever wanted it.

## What we gain

- **Half the cost**
- **Simpler USB** — one CDC serial device, no composite descriptors, no Audio class complexity
- **WiFi/BLE** — unused now but opens future possibilities (wireless duck, OTA firmware updates)
- **Same form factor** as the LED duck (XIAO) — could share enclosure designs
- **Consistent toolchain** — both ducks on ESP32/Arduino instead of mixed Teensy+ESP32
