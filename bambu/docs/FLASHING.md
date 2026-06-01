# Flashing a Bambu Duck

The single source of truth for getting firmware onto a Bambu Duck's
ESP32-S3. Three ways to do it, when to use each, what to expect after,
and the gotchas that have cost real time across sessions.

> **TL;DR for most people:** use the
> [web flasher](https://ideo.github.io/Rubber-Duck/flash/) (Chrome/Edge,
> "3D Printer Duck" tab). No toolchain, no install. Skip to
> [§1](#1-web-flasher-easiest).

---

## What you're flashing

A Bambu Duck is an **ESP32-S3** running ESP-IDF firmware. There are two
hardware variants — they take **different binaries** and you must know
which one you have:

| Variant | What it is | Binary |
|---|---|---|
| **Ducky PCB** | The custom IDEO WROOM-1 board (full-duplex I2S) | `bambu-duck-ducky.bin` |
| **XIAO Seeed S3** | A stock Seeed XIAO ESP32-S3 + cobbled mic/amp/servo | `bambu-duck-xiao.bin` |

There's a third build *flavor* (not a separate variant), **turnkey**,
which hides the ElevenLabs credential fields from the captive portal —
internal IDEO use only, never published. See
[Build flavors](../README.md#build-flavors).

**You cannot tell the two variants apart over USB** — both are ESP32-S3
with the same native USB-CDC descriptors (VID `0x303A`). You have to
know which board is in your hand. If you flash the wrong one, it'll
flash fine but the pin assignments will be wrong (mic/amp/servo on the
wrong GPIOs), so it just won't work right — reflash with the other
binary.

---

## 1. Web flasher (easiest)

For anyone who just wants a working duck. No toolchain.

1. Open <https://ideo.github.io/Rubber-Duck/flash/> in **Chrome or
   Edge** (Safari/Firefox don't support WebSerial; mobile can't do USB
   serial at all).
2. Click the **3D Printer Duck** tab.
3. Plug the duck into USB. Use a **data cable**, not charge-only — see
   [gotchas](#cable-is-charge-only).
4. *(Optional)* expand "Already have a duck plugged in? Identify it"
   and click **Identify connected duck** — confirms the chip is
   reachable and tells you what firmware (if any) is on it before you
   commit.
5. Click **Connect & Flash** under your variant (Ducky PCB or XIAO).
6. Pick the port from the browser popup (it'll be a `usbmodem` /
   `usbserial` device). Wait ~30s. Done.

After flash → see [What happens after a flash](#what-happens-after-a-flash).

The web flasher pulls binaries committed to
`docs/flash/firmware/bambu-duck-*.bin` on `main`, refreshed by CI on
every `bambu-v*` tag. See
[`docs/flash/firmware/README.md`](../../docs/flash/firmware/README.md)
for why they're served same-origin (CORS).

---

## 2. `make flash-*` (developers)

If you have the ESP-IDF toolchain and you're iterating on firmware.
This builds from source and flashes in one step.

```bash
cd bambu/firmware
source ~/esp/esp-idf/export.sh          # ESP-IDF v5.3.4

make flash-ducky   PORT=/dev/cu.usbmodem101   # custom WROOM-1 PCB
make flash-xiao    PORT=/dev/cu.usbmodem101   # XIAO Seeed S3
make flash-turnkey PORT=/dev/cu.usbmodem101   # ducky PCB, turnkey flavor

make monitor-ducky PORT=/dev/cu.usbmodem101   # tail serial logs after
```

Each variant builds into its own dir (`build_ducky` / `build_xiao` /
`build_turnkey`) so you can flip between them without a `fullclean`.
Full target list is documented at the top of
[`bambu/firmware/Makefile`](../firmware/Makefile).

**Find your port:** `ls /dev/cu.usbmodem*`. If several show up, the duck
is usually the lowest number (`...101`); the others (`...11101` etc.)
are often internal hubs. Plug/unplug and re-`ls` to see which one moves.

---

## 3. `esptool` (pre-built binary, no toolchain build)

When you have a `.bin` (downloaded from the web flasher's firmware dir,
or built elsewhere) and just want to write it, without a full IDF setup.
You only need `pip install esptool`.

```bash
# The web-flasher binaries are merged single-file images at offset 0:
python -m esptool --chip esp32s3 -p /dev/cu.usbmodem101 \
    write_flash 0x0 bambu-duck-ducky.bin
```

Grab the binary from
`https://github.com/ideo/Rubber-Duck/raw/main/docs/flash/firmware/bambu-duck-ducky.bin`
(or `-xiao`). These are esptool `merge_bin` outputs — bootloader +
partition table + app in one file at offset `0x0`, so a single
`write_flash 0x0` does everything.

> ⚠️ If instead you have the **separate** build artifacts
> (`bootloader.bin` / `partition-table.bin` / `bambu_duck.bin` from a
> raw `idf.py build`), they go at **different offsets**:
> ```
> write_flash 0x0 bootloader.bin  0x8000 partition-table.bin  0x10000 bambu_duck.bin
> ```
> Don't write a per-component `.bin` at `0x0` — it won't boot.

---

## What happens after a flash

A freshly-flashed duck has **no WiFi/Bambu credentials** — flashing
doesn't carry config. On first boot it comes up as a WiFi access point
for captive-portal onboarding:

1. Duck plays the embedded **"tap to start"** Opus phrase (pre-recorded
   ElevenLabs TTS, baked into flash).
2. It broadcasts a WiFi AP. Join it from a phone/laptop.
3. Captive portal auto-pops (or browse to `http://192.168.4.1`). Enter
   WiFi creds + Bambu cloud login, pick your printer. On the
   open-source build you also enter your ElevenLabs API key + agent ID;
   the turnkey build hides those.
4. Duck connects, plays **"connected"**, and you're live. Double-tap to
   start a conversation.

Re-onboard later via **long-press** (AP-on-demand without wiping creds).

Full onboarding/recovery detail lives in
[`bambu/DEPLOY.md`](../DEPLOY.md) (relay side) and
[`bambu/README.md`](../README.md) (product flow).

---

## Gotchas

These have each burned a session. Check here first.

### ESP-IDF Python env missing / wrong Python

Symptom (during `make flash-*` or `idf.py`):
```
/.../python_env/idf5.3_py3.X_env/bin/python doesn't exist!
Please run the install script or "idf_tools.py install-python-env"
```
Cause: your system Python was bumped (e.g. 3.9 → 3.14) and ESP-IDF's
matching virtualenv was never created. Fix:
```bash
cd ~/esp/esp-idf && ./install.sh esp32s3
```

### "configured with a different python" after the install

Symptom:
```
'...idf5.3_py3.14_env/bin/python' is currently active ... while the
project was configured with '...idf5.3_py3.9_env/bin/python'.
Run 'idf.py fullclean' to start again.
```
Cause: the build dir was CMake-configured against the old Python env.
Fix — clean just that variant's build dir and reflash:
```bash
source ~/esp/esp-idf/export.sh
idf.py -B build_turnkey fullclean    # or build_ducky / build_xiao
make flash-turnkey PORT=/dev/cu.usbmodem101
```

### Cable is charge-only

Symptom: no `/dev/cu.usbmodem*` appears; the web flasher's port popup is
empty. Many USB-C cables carry power but not data. Swap to a known data
cable. (Verify: `ls /dev/cu.usbmodem*` before and after plugging in —
nothing new = no data lines, or the chip isn't enumerating.)

### Port held by a serial monitor

Symptom: flash fails with the port busy, or `idf.py monitor` /
`make monitor-*` won't open. Something else has the port — Arduino IDE
serial monitor, a `screen` session, VS Code's serial monitor, anything.

```bash
lsof /dev/cu.usbmodem101    # see who holds it
```

**Do not kill that process.** Close the holding tool yourself (quit the
serial monitor). Killing it blind can take down a dev tool you have
open for a reason. This is a hard project rule.

### Web flasher: "Failed to fetch" / CORS error mid-flash

Symptom: chip detection succeeds ("Detected flash size: 8MB"), then a
red `Access to fetch ... blocked by CORS policy` and "Installation
failed". This was a real bug, now fixed: binaries are served
same-origin from `docs/flash/firmware/` instead of redirecting to
GitHub Releases. If you see it again, the manifest in
`docs/flash/manifests/*.json` has probably been pointed back at a
`github.com/.../releases/...` URL — it must use a relative
`../firmware/<name>.bin` path. See
[`docs/flash/firmware/README.md`](../../docs/flash/firmware/README.md).

### Web flasher: "port is already open"

Symptom: `InvalidStateError: Failed to execute 'open' on 'SerialPort':
The port is already open.` Another tab or app already claimed the port
(often a previous flasher attempt that didn't release). Close other
tabs talking to the duck, unplug/replug, retry.

### Chip won't enter download mode

The ESP32-S3's native USB-CDC normally auto-enters the ROM bootloader
when esptool/ESP Web Tools toggles DTR/RTS — no buttons needed. If a
board is wedged (bad firmware spinning, brownout), force it manually:
hold **BOOT**, tap **RESET** (or replug power) while holding BOOT,
release. Then retry the flash. The merged image overwrites everything
including the bootloader, so this recovers a soft-bricked chip.

---

## Why there's no over-the-air (OTA) update yet

The partition table ([`bambu/firmware/partitions.csv`](../firmware/partitions.csv))
has a single `factory` app slot and no OTA slots:

```
nvs       0x9000   0x6000
phy_init  0xf000   0x1000
factory   0x10000  0x600000
```

`esp_https_ota` needs two OTA app partitions to flip between. Adding
them is a partition-table change, which itself requires one USB reflash
to migrate (you can't repartition over the air). Until that lands,
**every firmware update is a USB reflash** via one of the three methods
above. On-device OTA via the captive portal is tracked as future work.

(The *Claude Code Duck* — the Mac companion, a different product — has a
separate firmware-update story via the desktop widget. That doesn't
apply here; the Bambu Duck has no companion app.)

---

## See also

- [`bambu/README.md`](../README.md) — product overview, build flavors
- [`bambu/firmware/README.md`](../firmware/README.md) — pinout, NVS
  provisioning, known scaffolding gaps
- [`bambu/DEPLOY.md`](../DEPLOY.md) — relay deploy + onboarding runbook
- [`docs/flash/firmware/README.md`](../../docs/flash/firmware/README.md)
  — how CI publishes the web-flasher binaries
