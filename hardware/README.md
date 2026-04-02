# Duck Duck Duck — Hardware

Mechanical and electrical design files for the Duck Duck Duck hardware. The enclosure captures a custom PCB and an SG90 micro servo inside a multi-part 3D-printed duck shell.

```
hardware/
  CAD/              SolidWorks source + STEP exports + 3MF print files
  EE/               Eagle schematic + board layout + Fusion 360 project
```

## Enclosure (CAD)

The master CAD is authored in **SolidWorks**. STEP exports are included for non-SolidWorks users.

| File | Description |
|------|-------------|
| `CAD/Ducky Final.SLDASM` | Top-level assembly |
| `CAD/DuckyFinal3D.step` | STEP export for universal CAD import |
| `CAD/DuckyV6.SLDPRT` / `DuckyV6Danny.SLDPRT` | Main duck body parts |
| `CAD/DuckLips.SLDPRT` | Beak / lips |
| `CAD/SG90_Servo_Motor.SLDPRT` | Servo reference geometry |
| `CAD/SP-3605.SLDPRT` | Speaker reference geometry |

## 3D Printing

Ready-to-print 3MF files in `CAD/3MF Files/`:

| File | Description |
|------|-------------|
| `duck-face.3mf` | Front face shell |
| `duck-back.3mf` | Rear shell |
| `duck-front.3mf` | Front inner structure |
| `duck-lips.3mf` | Beak |
| `duck-feet.3mf` | Base / feet |
| `duck-servo-mount.3mf` | Servo mounting bracket |

### Print Settings

- **Material:** Bambu Matte PLA (recommended) or standard PLA
- **Nozzle:** 0.4mm
- **Layer height:** 0.2mm works well for all parts
- **Supports:** None — all parts are designed to print without supports. Pop off the bed and assemble.

### Assembly

**Servo mount plate:** The mount plate press-fits into the enclosure with the chamfer facing toward the duck's front. It may require a rubber mallet to seat fully — tap carefully to avoid cracking the print. The servo itself screws onto the plate easily.

**Fasteners:** M2.5 x 16mm countersunk screws capture the mount plate and PCB to the enclosure.

**USB cable clearance:** The USB-C port opening is **12mm x 6.25mm**. Verify your cable's plug dimensions before ordering — some cables have oversized housings that won't fit.

## PCB (EE)

Custom PCB designed in Eagle / Fusion 360:

| File | Description |
|------|-------------|
| `EE/Ducky_Schematic.sch` | Eagle schematic |
| `EE/DuckyBRD.brd` | Eagle board layout |
| `EE/Ducky.f3z` | Fusion 360 project (board + enclosure integration) |

## Firmware

Firmware for the ESP32-S3 (and Teensy 4.0 legacy) lives in [`../firmware/`](../firmware/).

## License

[CERN Open Hardware Licence v2 — Permissive](../firmware/LICENSE)
