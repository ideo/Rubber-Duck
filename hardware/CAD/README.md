# Duck Duck Duck — Enclosure CAD

Mechanical design files for the Duck Duck Duck hardware enclosure. The geometry captures a custom PCB (see `../EE/`) and an SG90 micro servo inside a multi-part duck shell.

## Source Files (SolidWorks)

The master CAD is authored in **SolidWorks**:

| File | Description |
|------|-------------|
| `Ducky Final.SLDASM` | Top-level assembly |
| `DuckyFinal3D.SLDASM` | Assembly variant (3D export) |
| `DuckyV6.SLDPRT` / `DuckyV6Danny.SLDPRT` | Main duck body parts |
| `DuckLips.SLDPRT` | Beak / lips |
| `SG90_Servo_Motor.SLDPRT` | Servo reference geometry |
| `SP-3605.SLDPRT` | Speaker reference geometry |
| `95893A197_Flat Head Thread-Forming Screws for Plastic.SLDPRT` | Screw reference |

STEP exports (`*.step` / `*.stp`) are included for non-SolidWorks users.

## 3D Printable Files

Ready-to-print 3MF files are in the `3MF Files/` folder:

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
- **Supports:** May be needed for overhangs on the face and lips

### Assembly Notes

**Servo mount:** The servo fits snugly into the mount with the chamfer facing toward the duck's front. It may require a rubber mallet to seat fully — tap carefully to avoid cracking the print.

**Fasteners:** M2.5 x 16mm countersunk screws capture the servo mount and PCB to the enclosure.

**USB cable clearance:** The USB-C port opening is **12mm x 6.25mm**. Verify your cable's plug dimensions before ordering — some cables have oversized housings that won't fit.

## PCB

The custom PCB design files are in `../EE/`:
- `Ducky_Schematic.sch` — Eagle schematic
- `DuckyBRD.brd` — Eagle board layout
- `Ducky.f3z` — Fusion 360 project (board + enclosure integration)

## License

[CERN Open Hardware Licence v2 — Permissive](../../firmware/LICENSE)
