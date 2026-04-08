# Dev Scripts

Developer tools for testing and debugging. Not for end users.

## clean-install.sh

Wipe all Duck Duck Duck traces from your machine for testing a fresh install.

**What it removes:**
- Plugin cache, marketplace, and installed_plugins.json entries
- settings.json enabledPlugins and extraKnownMarketplaces entries
- App data (`~/Library/Application Support/DuckDuckDuck/`)
- App from `/Applications/`

**What it does NOT touch:**
- Other Claude plugins or settings
- Claude Desktop or CLI itself
- Any non-duck files

**Usage:**
```bash
# Make sure Claude Desktop and the duck widget are closed first!

# Option 1: If you have the repo cloned
./scripts/dev/clean-install.sh

# Option 2: Download and run directly (no git needed)
curl -fsSL https://raw.githubusercontent.com/ideo/Rubber-Duck/main/scripts/dev/clean-install.sh | bash
```

Then install the DMG and test the full onboarding flow.

## Bootloader Entry

Three ways to put the ESP32-S3 into bootloader mode for flashing:

1. **Serial command:** Send `B\n` over the serial port
2. **Button hold:** Hold the button for 5 seconds
3. **Physical buttons:** Hold BOOT, press RESET, release BOOT (board-dependent)

After entering bootloader, the duck freezes and USB re-enumerates as a DFU device. Flash via Arduino IDE, then unplug/replug to return to normal.

## Serial Identity Check

Quick check if a USB device is a duck:
```bash
python3 -c "
import serial, time
ser = serial.Serial('/dev/cu.usbmodem1101', 921600, timeout=2)
time.sleep(0.5)
ser.write(b'I\n')
time.sleep(1)
print(repr(ser.read(200)))
ser.close()
"
```

Should print `b'DUCK,ESP32S3,1.0\r\n'` if it's a duck.
