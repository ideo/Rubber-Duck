# Duck Duck Duck — S3 UAC Firmware

ESP32-S3 firmware with USB Audio Class (UAC). The duck appears as a CoreAudio
device named "Duck Duck Duck" on macOS — both mic and speaker.

This is an **ESP-IDF project with Arduino as a component**. Same Arduino code
(`setup()`/`loop()`), different build system. The original Arduino IDE `.ino`
files live in `../rubber_duck_esp32/` and are untouched.

## Why not Arduino IDE?

The Arduino ESP32 core doesn't compile TinyUSB's audio device class.
The headers exist but `audio_device.c` is not linked. Arduino core issue
[#12053](https://github.com/espressif/arduino-esp32/issues/12053) tracks
adding native UAC support — not shipped yet as of March 2026.

We use ESP-IDF's build system with Arduino as a component. UAC support
will be added via Espressif's `usb_device_uac` component once the base
firmware is solid.

## One-Time Setup

### 1. Install ESP-IDF v5.3.4

**Must be v5.3.x** — v5.4 has a broken setuptools/ruamel.yaml dependency chain.

```bash
# Build tools
brew install cmake ninja dfu-util

# Clone ESP-IDF
mkdir -p ~/esp && cd ~/esp
git clone -b v5.3.4 --recursive https://github.com/espressif/esp-idf.git
cd esp-idf
./install.sh esp32s3
```

### 2. Fix setuptools (required)

ESP-IDF's dep checker uses `pkg_resources` which was dropped in setuptools 82:

```bash
~/.espressif/python_env/idf5.3_py3.9_env/bin/python -m pip install "setuptools<81"
```

### 3. Activate ESP-IDF in your terminal

Run this once per terminal session (or add to your shell profile):

```bash
. ~/esp/esp-idf/export.sh
```

You'll see a banner confirming the version. The `idf.py` command is now available.

## Building

```bash
# From this directory (firmware/rubber_duck_s3_uac/)
. ~/esp/esp-idf/export.sh   # if not already done

# First time only — pulls Arduino component (~2 min)
idf.py set-target esp32s3
idf.py build

# Flash (quit the widget first — it holds the serial port)
idf.py -p /dev/cu.usbmodem* flash

# Monitor serial output
idf.py -p /dev/cu.usbmodem* monitor
# (Ctrl+] to exit monitor)

# Build + flash + monitor in one shot
idf.py -p /dev/cu.usbmodem* flash monitor
```

### If the port isn't found

The XIAO S3 may show up as `/dev/cu.usbmodemXXXX` or `/dev/tty.usbmodemXXXX`.
Check with `ls /dev/cu.usb*`. If nothing appears:

1. Hold BOOT button on the XIAO
2. Press RESET while holding BOOT
3. Release both — enters bootloader mode
4. Flash, then press RESET to run

## Project Structure

```
rubber_duck_s3_uac/
  CMakeLists.txt              # Top-level ESP-IDF project file
  main/
    CMakeLists.txt            # Component file listing sources
    idf_component.yml         # Dependency: arduino-esp32
    Config.h                  # Pin mappings, constants, forward declarations
    rubber_duck_s3_uac.cpp    # Main firmware (setup/loop)
    SerialProtocol.cpp        # Serial text protocol parser
    ServoControl.cpp          # Spring-physics servo with idle heartbeat
    StatusLED.cpp             # Built-in NeoPixel (GPIO 48) status indicator
    Easing.cpp                # Cubic/quartic/quintic easing helpers
```

## Differences from C3 Arduino Firmware

| Aspect | C3 Arduino (`rubber_duck_c3/`) | S3 ESP-IDF (`rubber_duck_s3_uac/`) |
|--------|-------------------------------|-------------------------------------|
| Build system | Arduino IDE | ESP-IDF + Arduino component |
| Audio path | Serial binary streaming | USB Audio Class (CoreAudio) |
| LED output | TLC59711 12-ch bar (SPI) | Built-in NeoPixel (GPIO 48) |
| Serial protocol | Text + binary audio frames | Text only |
| Chip identity | `DUCK,ESP32C3,1.0` | `DUCK,ESP32S3,1.0` |
| File extension | `.ino` | `.cpp` |

## C3 Firmware

The C3 firmware (`../rubber_duck_c3/`) stays in Arduino IDE — it uses serial
audio streaming, not UAC. No changes needed there.
