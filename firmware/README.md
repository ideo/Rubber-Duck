# Duck Duck Duck — Firmware

Open hardware firmware for the Duck Duck Duck physical companion. Connects to the macOS widget via USB serial, receives eval scores and TTS audio, drives servo + speaker + mic.

## Supported Boards

| Variant | Board | Status | Folder |
|---------|-------|--------|--------|
| **S3** | [Seeed XIAO ESP32-S3](https://www.seeedstudio.com/XIAO-ESP32S3-p-5627.html) | Verified | `rubber_duck_s3/` |
| **S3 Waveshare** | [Waveshare ESP32-S3-Zero](https://www.waveshare.com/esp32-s3-zero.htm) | Verified | `rubber_duck_s3_waveshare/` |
| **S3 LED** | Seeed XIAO ESP32-S3 + NeoPixel ring | Verified | `rubber_duck_s3_led/` |
| **S3 UAC** | Seeed XIAO ESP32-S3 (USB Audio Class) | Experimental | `rubber_duck_s3_uac/` |
| **Teensy 4.0** | [Teensy 4.0](https://www.pjrc.com/store/teensy40.html) | Verified | `rubber_duck_teensy4.0/` |

## Peripherals

All variants use the same core peripherals:

| Component | Part | Purpose |
|-----------|------|---------|
| **Speaker amp** | [MAX98357 I2S DAC](https://www.adafruit.com/product/3006) | TTS voice output |
| **Microphone** | [ICS-43434 I2S MEMS](https://www.adafruit.com/product/3421) | Voice commands |
| **Servo** | SG90 or similar | Head tilt |
| **Speaker** | 8 ohm, any wattage | Voice output |

## Wiring

### Seeed XIAO ESP32-S3

```
D0  (GPIO11) → Servo signal
D1  (GPIO2)  → Mic SD (data out)
D2  (GPIO3)  → MAX98357 BCLK
D3  (GPIO4)  → MAX98357 LRC
D4  (GPIO5)  → MAX98357 DIN
D8  (GPIO7)  → Button (optional, internal pullup)
D9  (GPIO8)  → Mic SCK
D10 (GPIO9)  → Mic WS
3V3          → MAX98357 VIN + SD (enable) + Mic VDD
GND          → All grounds + Mic L/R (left channel)
5V           → Servo VCC (or 3V3 if no 5V available)
```

### Waveshare ESP32-S3-Zero

```
GP1  → MAX98357 BCLK
GP2  → MAX98357 LRC
GP3  → MAX98357 DIN
GP4  → Mic SCK
GP5  → Mic WS
GP6  → Mic SD (data out)
GP7  → Button (optional, internal pullup)
GP9  → Servo signal
GP10 → Onboard WS2812 LED (no wiring needed)
3V3  → MAX98357 VIN + SD (enable) + Mic VDD
GND  → All grounds + Mic L/R (left channel)
5V   → Servo VCC (or 3V3 if no 5V available)
```

### Teensy 4.0

See `rubber_duck_teensy4.0/` for pin assignments. Uses USB Audio Class (UAC) for audio — the Teensy appears as a USB audio device to the Mac.

## Flashing

### ESP32-S3 (Seeed or Waveshare)

1. Install [Arduino IDE](https://www.arduino.cc/en/software) or `arduino-cli`
2. Add ESP32 board support: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
3. Select board: **ESP32S3 Dev Module**
4. Settings: USB CDC On Boot → **Enabled**, Upload Speed → **921600**
5. For Waveshare: hold BOOT, press RESET, release BOOT to enter download mode
6. Upload

### Teensy 4.0

1. Install [Teensyduino](https://www.pjrc.com/teensy/teensyduino.html)
2. Select board: **Teensy 4.0**
3. USB Type: **Serial + MIDI + Audio**
4. Upload

## Serial Protocol

All boards use the same serial protocol. The widget auto-detects the device.

**Text mode** (default):
```
C,0.72,0.85,0.40,0.61,-0.20\n    — Claude eval scores
U,0.50,0.30,0.10,-0.20,0.00\n    — User eval scores
P,1\n                              — Permission requested
P,0\n                              — Permission resolved
W,1\n                              — Wake word detected (attention)
W,0\n                              — Wake word resolved
VOL,0.65\n                         — Set volume (0.0-1.0)
```

**Audio mode** (between `A,16000,16,1\n` and `A,0\n`):
```
0x01 [len_hi] [len_lo] [PCM bytes...]   — Audio frame
0x02 [len bytes of text ending in \n]    — Control message
```

## Speaker Notes

The MAX98357 GAIN pin controls hardware volume:
- **Float** (not connected) = 15dB (default, recommended)
- **GND** = 12dB (quieter)
- **VDD** = 18dB (louder)

Software volume is controlled by the widget. A speaker of 8 ohm at any wattage works. Bigger cone = louder at the same power. A 28mm+ speaker sounds noticeably better than the tiny 13mm ones.

## License

Hardware designs are licensed under [CERN Open Hardware Licence v2 — Permissive](../firmware/LICENSE).
