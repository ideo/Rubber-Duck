# Duck Hardware Reference

Three board variants. Same serial protocol, same widget, different audio paths.

## Board Comparison

| | Teensy 4.0 | XIAO ESP32-S3 Sense | XIAO ESP32-C3 |
|---|---|---|---|
| **Status** | Working (production) | Working (dev) | Pending (hardware on order) |
| **CPU** | 600MHz Cortex-M7 | 240MHz Xtensa dual-core | 160MHz RISC-V |
| **Cost** | ~$30 | ~$14 | ~$5 |
| **Speaker** | MAX98357 via I2S | MAX98357 via I2S | MAX98357 via I2S |
| **TTS audio path** | USB Audio Class (Mac → Teensy as sound card) | Serial PCM streaming (widget → ESP32) | Serial PCM streaming (widget → ESP32) |
| **Mic path** | USB Audio Class (Teensy appears as USB mic) | Onboard PDM mic → serial streaming | External INMP441 I2S mic or ADC analog mic → serial streaming |
| **Chirps** | Teensy Audio library (waveform + filter) | Software synth → ring buffer → I2S | Software synth → ring buffer → I2S |
| **Servo** | Hardware PWM (Servo library) | LEDC PWM | LEDC PWM |
| **I2S driver** | Teensy Audio library | New IDF (`driver/i2s_std.h` + `driver/i2s_pdm.h`) | New IDF (`driver/i2s_std.h`) |

## Teensy 4.0

Firmware: `firmware/rubber_duck_teensy40/`

The original. Mac sees it as a USB Audio device — `say -a "Teensy MIDI_Audio"` routes TTS directly, and the analog mic on A0 appears as a USB microphone. No widget involvement for audio.

### Wiring

| Function | Pin | Notes |
|---|---|---|
| Servo | 3 | Hardware PWM |
| Button | 11 | Internal pullup |
| I2S BCLK | 21 | → MAX98357 |
| I2S LRCLK | 20 | → MAX98357 |
| I2S DIN | 7 | → MAX98357 |
| Analog mic | A0 | → USB Audio out |
| USB | — | CDC serial + UAC audio (composite device) |

### Audio architecture

```
macOS                              Teensy 4.0
  say -a "Teensy" "Hello" ───────→ USB Audio In → I2S mixer → MAX98357 → speaker
  System mic (USB Audio) ←──────── Analog mic (A0) → USB Audio Out
                                                 ↑
                                         chirp synthesis (AudioSynthWaveform)
```

Mac handles noise cancellation on the mic path (UAC). Zero widget involvement for audio.

### What works
- Everything: servo, chirps, TTS, mic, button, permission nags
- Hot-unplug detection (widget falls back to Mac mic/speaker)

---

## XIAO ESP32-S3 Sense

Firmware: `firmware/rubber_duck_c3/` (shared codebase, board-selected at compile time)

Arduino IDE board: **"XIAO_ESP32S3"**

The S3 Sense has a built-in PDM microphone (MSM261D3526H1CPM) that requires the new IDF I2S PDM driver. This forced a full migration from the legacy `driver/i2s.h` to the new `driver/i2s_std.h` / `driver/i2s_pdm.h` API for the entire audio system.

### Wiring

| Function | Pin | GPIO | Notes |
|---|---|---|---|
| Servo | D0 | GPIO1 | LEDC PWM |
| I2S BCLK | D2 | GPIO3 | → MAX98357 |
| I2S LRCLK | D3 | GPIO4 | → MAX98357 |
| I2S DIN | D4 | GPIO5 | → MAX98357 |
| Mic | — | GPIO42 CLK, GPIO41 DATA | Onboard PDM, no wiring needed |
| Button | D8 | GPIO7 | Internal pullup |
| USB | — | USB CDC serial only |

Expansion board must be attached for the onboard PDM mic to work.

### Audio architecture

```
Widget (macOS)                              ESP32-S3
  AVSpeechSynthesizer                         │
    → capture PCM (22050Hz)                   │
    → binary frame: 0x01 [len] [PCM] ──────→ ring buffer → I2S DMA → MAX98357 → speaker
                                                               ↑
                                                       chirp synthesis
                                              │
  STT engine ←── 0x04 [len] [PCM] ─────────── PDM mic (I2S_NUM_0) → DC removal + gain
```

### I2S port assignment (critical)

The S3 has 2 I2S ports. The PDM mic driver **must** use I2S_NUM_0 on S3 (hardware limitation). Speaker goes on I2S_NUM_1.

```c
// Config.h
#define AUDIO_I2S_PORT   I2S_NUM_1  // Speaker on port 1
// Mic uses I2S_NUM_AUTO → gets port 0
```

**Init order matters:** `setupMic()` must run before `setupAudio()` so the PDM driver claims port 0 first.

### I2S driver: legacy vs new IDF (critical learning)

The legacy `driver/i2s.h` and new `driver/i2s_std.h` / `driver/i2s_pdm.h` **cannot coexist at runtime**. Even in separate `.cpp` files, IDF has a runtime check that aborts:

```
CONFLICT! The new i2s driver can't work along with the legacy i2s driver
```

Since the PDM mic requires the new driver, we migrated the speaker to the new driver too:

| Legacy API | New IDF API |
|---|---|
| `i2s_driver_install()` | `i2s_new_channel()` + `i2s_channel_init_std_mode()` + `i2s_channel_enable()` |
| `i2s_write()` | `i2s_channel_write(txHandle, ...)` |
| `i2s_read()` | `i2s_channel_read(rxHandle, ...)` |
| `i2s_set_sample_rates()` | `i2s_channel_disable()` + `i2s_channel_reconfig_std_clock()` + `i2s_channel_enable()` |
| `i2s_zero_dma_buffer()` | `chanCfg.auto_clear = true` (silence on underrun) |
| `tx_desc_auto_clear` | `auto_clear` in channel config |

### PDM mic signal processing

Raw PDM→PCM output has a large DC bias (~1300–2500 depending on board) with small AC signal. Processing chain:

1. **Calibration at boot:** Read 4 frames to measure DC offset, 1 frame for noise RMS
2. **DC removal:** Single-pole high-pass filter: `pdmDC += 0.001 * (raw - pdmDC)`
3. **Auto-gain:** `gain = constrain(1600.0 / noiseRMS, 16.0, 512.0)`
4. **Clamp:** ±32767

Typical calibration values: DC ~1300, noise RMS ~2087, gain hits floor at 16.0. Speech peaks reach ~25% of full range — adequate for STT but not loud. The onboard PDM mic has a high noise floor.

**Noise:** The serial mic path bypasses Mac's built-in noise cancellation (which the Teensy UAC path got for free). Denoise must happen widget-side before feeding STT. Not yet implemented.

### Auto-mute during TTS

When audio streaming begins (`A,16000,16,1`), mic is muted to prevent speaker→mic feedback loop. Unmuted when stream ends (`A,0`).

### Known issues

- Noise floor is high on onboard PDM mic — denoise needed widget-side
- `ADC_ATTEN_DB_11` was renamed to `ADC_ATTENDB_MAX` in ESP32 Arduino core 3.x
- Arduino IDE merges all `.ino` files into one translation unit — can't isolate driver includes via separate files

---

## XIAO ESP32-C3 (planned)

Firmware: `firmware/rubber_duck_c3/` (same codebase as S3, compile-time board selection)

Arduino IDE board: **"XIAO_ESP32C3"**

Hardware on order. The C3 has only 1 I2S port, so the speaker and mic can't both use I2S simultaneously. Speaker gets I2S; mic uses ADC + hardware timer.

### Wiring (planned)

| Function | Pin | GPIO | Notes |
|---|---|---|---|
| Servo | D0 | GPIO2 | LEDC PWM |
| I2S BCLK | D2 | GPIO4 | → MAX98357 |
| I2S LRCLK | D3 | GPIO5 | → MAX98357 |
| I2S DIN | D4 | GPIO6 | → MAX98357 |
| Mic | D5 | GPIO6/A5 | Analog MEMS mic (SPW2430) or I2S mic (INMP441, needs testing) |
| Button | D8 | GPIO7 | Internal pullup |

### Audio architecture (planned)

```
Widget (macOS)                              ESP32-C3
  AVSpeechSynthesizer                         │
    → binary frame: 0x01 [len] [PCM] ──────→ ring buffer → I2S DMA → MAX98357 → speaker
                                                               ↑
                                                       chirp synthesis
                                              │
  STT engine ←── 0x04 [len] [PCM] ─────────── ADC mic (hardware timer ISR) → DC removal + gain
```

### I2S port assignment

C3 has 1 I2S port. Speaker uses it. Mic uses ADC + timer (no I2S conflict).

```c
// Config.h
#define AUDIO_I2S_PORT   I2S_NUM_0  // Only port available
```

### ADC mic path (implemented, untested on C3)

Hardware timer fires at 16kHz, reads `analogRead(MIC_PIN)` in ISR, writes to double buffer. Main loop applies DC removal + gain, sends serial frames. No I2S involvement.

```c
// ISR — runs at MIC_SAMPLE_RATE (16kHz)
void IRAM_ATTR micTimerISR() {
    rawWriteBuf[rawWritePos++] = (uint16_t)analogRead(MIC_PIN);
    if (rawWritePos >= MIC_FRAME_SAMPLES) {
        // Swap buffers
        rawWriteBuf ↔ rawSendBuf;
        rawWritePos = 0;
        micFrameReady = true;
    }
}
```

### INMP441 I2S mic option

An INMP441 I2S digital mic has been ordered. If it works on C3, it would share the I2S port with the speaker via time-division (mic when listening, speaker when talking) — but this needs investigation. The ADC path is the safe fallback.

---

## Serial Protocol (all boards)

Same protocol on all three boards. Text mode by default, binary framing during audio streaming.

### Text commands

```
U,0.20,0.70,0.00,0.60,-0.30\n    # User eval scores
C,0.72,0.85,0.40,0.61,-0.20\n    # Claude eval scores
P,1\n                              # Permission requested
P,0\n                              # Permission resolved
M,1\n                              # Start mic streaming (ESP32 only)
M,0\n                              # Stop mic streaming
A,16000,16,1\n                     # Enter audio mode (rate, bits, channels)
S,90\n                             # Direct servo angle
D\n                                # Demo preset
T\n / X\n                          # Test evals (positive/negative)
W\n / Q\n                          # Test chirps (whistle/permission)
V\n                                # Servo sweep test
```

### Binary audio framing (during audio mode)

After `A,<rate>,<bits>,<ch>\n`, all data uses binary framing:

```
0x01 [len_hi] [len_lo] [PCM bytes...]     # Audio frame
0x02 [len_hi] [len_lo] [text bytes...]     # Control message (e.g., eval during TTS)
0x04 [len_hi] [len_lo] [PCM bytes...]      # Mic audio frame (ESP32 → widget)
```

End audio mode by sending `A,0` as a control frame (0x02), **not** raw text.

### Mic streaming

Teensy: mic goes through USB Audio Class — Mac sees it as a USB microphone. No serial involvement.

ESP32: `M,1` starts mic streaming. Firmware sends 0x04-tagged binary frames at 16kHz/16-bit/mono. Widget receives and feeds to STT. `M,0` stops.

### Baud rate

- Teensy: 9600 (USB CDC, nominal — actual speed is USB Full Speed)
- ESP32: 921600 (USB CDC, nominal — same deal, signals fast link to serial monitors)

---

## Widget Integration Status

| Feature | Teensy | ESP32 |
|---|---|---|
| Serial device discovery | Working (`tty.usbmodem*`) | Working (same pattern) |
| Score/permission commands | Working | Working |
| TTS via USB Audio (`say -a`) | Working | N/A (no UAC) |
| TTS via serial streaming | N/A | Working (tested with Python + afplay) |
| TTS via `AVSpeechSynthesizer.write()` | N/A | Not yet integrated (API tested, 22050Hz) |
| Mic via USB Audio | Working (Mac sees USB mic) | N/A |
| Mic via serial streaming | N/A | Working (tested with Python) |
| Widget STT from serial mic | N/A | Not yet implemented |
| Denoise on serial mic | N/A | Not yet implemented |
| Hot-unplug detection | Working | Not yet tested |
| Chirps | Working | Working |
| Servo + spring physics | Working | Working |

## TODO

- [ ] Widget: `AVSpeechSynthesizer.write()` → serial audio streaming integration
- [ ] Widget: receive serial mic frames (0x04 tag) → denoise → feed STT
- [ ] Widget: auto-detect Teensy (UAC audio) vs ESP32 (serial audio) and route accordingly
- [ ] Test C3 hardware when it arrives (ADC mic, single I2S port)
- [ ] Test INMP441 I2S mic on C3
- [ ] Firmware noise gate (attempted, caused crash — revisit or keep denoise widget-side)
