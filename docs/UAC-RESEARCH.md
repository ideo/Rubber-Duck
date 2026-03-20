# ESP32-S3 USB Audio Class (UAC) Research

**Date:** 2026-03-20

## The Problem

We need the XIAO ESP32S3 to appear as a USB audio device named "Duck Duck Duck" in macOS CoreAudio — both mic and speaker, 16kHz/16-bit/mono. It must coexist with CDC serial (text commands).

## Key Finding: Arduino ESP32 Core Does NOT Support UAC

The Arduino ESP32 core (v3.3.7) ships TinyUSB headers for audio (`audio.h`, `audio_device.h`) but **does not compile `audio_device.c` into the precompiled library** (`libarduino_tinyusb.a`). The shipped `tusb_config.h` defines CDC, MSC, HID, MIDI, Video, DFU, Vendor, NCM — **no audio**.

**You cannot just `#define CFG_TUD_AUDIO 1`** from a sketch or `build_opt.h` — the audio device driver object code is simply not linked.

## Arduino IDE USB Mode Setting

In Arduino IDE, for XIAO ESP32S3, set **Tools → USB Mode → "USB-OTG (TinyUSB)"**. This enables the TinyUSB stack (vs. hardware CDC). Required for any custom USB class. The serial port still works via TinyUSB CDC.

## Three Approaches (Ranked)

### Approach 1: ESP-IDF `usb_device_uac` Component + Arduino-as-Component (RECOMMENDED)

Espressif's official UAC component ([v1.2.3](https://components.espressif.com/components/espressif/usb_device_uac)) wraps TinyUSB audio with a clean callback API:

```c
uac_device_config_t config = {
    .output_cb = speaker_data_cb,    // Host → duck (speaker)
    .input_cb  = mic_data_cb,        // Duck → host (mic)
    .set_mute_cb = mute_cb,
    .set_volume_cb = volume_cb,
};
uac_device_init(&config);
```

**Key Kconfig options:**
- `CONFIG_UAC_SAMPLE_RATE` = 16000
- `CONFIG_UAC_MIC_CHANNEL_NUM` = 1
- `CONFIG_UAC_SPEAKER_CHANNEL_NUM` = 1
- `CONFIG_UAC_SUPPORT_MACOS` = y ← **critical** (macOS mode and Windows/Linux are mutually exclusive)
- `CONFIG_UAC_MIC_INTERVAL_MS` = 10
- `CONFIG_UAC_SPK_INTERVAL_MS` = 10

**How to use with Arduino code:** "Arduino as ESP-IDF component" approach:
```bash
idf.py create-project duck-uac
cd duck-uac
idf.py add-dependency "espressif/arduino-esp32^3.3.7"
idf.py add-dependency "espressif/usb_device_uac^1.2.3"
idf.py set-target esp32s3
idf.py menuconfig  # Enable Arduino autostart, set UAC config
```

**Custom product name:** Set `CONFIG_TUSB_PRODUCT` = "Duck Duck Duck" in menuconfig.

**Composite CDC + UAC:** The component has a `skip_tinyusb_init` flag. Initialize TinyUSB yourself with composite descriptor (CDC + UAC interfaces), then pass `skip_tinyusb_init = true`.

**Trade-off:** Moves build from Arduino IDE to `idf.py` or PlatformIO. Arduino `setup()`/`loop()` still work.

### Approach 2: Raw TinyUSB UAC2 (Arduino-as-IDF-component)

Port TinyUSB's `uac2_headset` example directly. More control, more code.

Required `tusb_config.h` defines:
```c
#define CFG_TUD_AUDIO                1
#define CFG_TUD_CDC                  1
#define CFG_TUD_AUDIO_ENABLE_EP_IN   1  // Mic
#define CFG_TUD_AUDIO_ENABLE_EP_OUT  1  // Speaker
#define CFG_TUD_AUDIO_FUNC_1_N_CHANNELS_TX  1
#define CFG_TUD_AUDIO_FUNC_1_N_CHANNELS_RX  1
#define CFG_TUD_AUDIO_FUNC_1_N_BYTES_PER_SAMPLE_TX  2
#define CFG_TUD_AUDIO_FUNC_1_N_BYTES_PER_SAMPLE_RX  2
#define CFG_TUD_AUDIO_FUNC_1_SAMPLE_RATE  16000
```

Data flow:
- Mic: call `tud_audio_write(buf, len)` every ~1ms
- Speaker: call `tud_audio_read(buf, sizeof(buf))` to get host audio

Requires compiling `audio_device.c` from TinyUSB source yourself.

### Approach 3: Wait for Native Arduino Support

GitHub issue [espressif/arduino-esp32#12053](https://github.com/espressif/arduino-esp32/issues/12053) — @me-no-dev committed March 10, 2026: "I will try to add initial support this week." No PR exists 10 days later. Could land in Arduino ESP32 core 3.4.x. ETA unknown.

## Libraries That Do NOT Work

| Library | Why |
|---------|-----|
| EspTinyUSB (chegewara) | No audio support. ESP32-S2 only. Abandoned. |
| esp32-usb-v2 (chegewara) | No audio support. Only CDC/MSC/HID/DFU/WebUSB. |
| `build_opt.h` trick | `audio_device.c` not in precompiled `.a` — symbols missing at link time. |

## Decision

**Use Approach 1** — ESP-IDF `usb_device_uac` component with Arduino-as-component. Gives us:
- Official Espressif component with macOS support flag
- Clean callback API (no raw descriptor wrangling)
- Composite USB (CDC serial + UAC audio)
- Arduino `setup()`/`loop()` still works
- 16kHz/16-bit/mono supported
- Custom product name via menuconfig

The trade-off is moving from Arduino IDE to `idf.py`/PlatformIO for the S3 firmware build only. C3 firmware stays in Arduino IDE.

## What This Means for Our Build

The S3 firmware will become an ESP-IDF project with Arduino as a component. Our existing `.ino` files become `.cpp` files inside `main/`. The `setup()`/`loop()` pattern is preserved — it's still Arduino code, just built with `idf.py` instead of Arduino IDE.

Directory structure would look like:
```
firmware/rubber_duck_esp32/
  CMakeLists.txt              ← ESP-IDF project
  sdkconfig.defaults          ← UAC + Arduino config
  main/
    CMakeLists.txt
    idf_component.yml         ← arduino-esp32 + usb_device_uac deps
    rubber_duck_esp32.cpp     ← was .ino
    SerialProtocol.cpp
    ServoControl.cpp
    LEDDriver.cpp
    Easing.cpp
    Config.h
```
