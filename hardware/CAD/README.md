# Duck Duck Duck — Enclosure (CAD)

Multi-part 3D-printed duck shell designed in SolidWorks. STEP exports are included for non-SolidWorks users.

## Source Files

| File | Description |
|------|-------------|
| `Ducky Final.SLDASM` | Top-level assembly |
| `DuckyFinal3D.step` | STEP export for universal CAD import |
| `DuckyV6.SLDPRT` / `DuckyV6Danny.SLDPRT` | Main duck body parts |
| `DuckLips.SLDPRT` | Beak / lips |
| `SG90_Servo_Motor.SLDPRT` | Servo reference geometry |
| `SP-3605.SLDPRT` | Speaker reference geometry |

## 3D Printing

Ready-to-print 3MF files in `3MF Files/`:

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

## Assembly

**Servo mount plate:** The mount plate press-fits into the enclosure with the chamfer facing toward the duck's front. It may require a rubber mallet to seat fully — tap carefully to avoid cracking the print. The servo itself screws onto the plate easily.

**Fasteners:** M2.5 x 16mm countersunk screws capture the mount plate and PCB to the enclosure.

**USB cable clearance:** The USB-C port opening is **12mm x 6.25mm**. Verify your cable's plug dimensions before ordering — some cables have oversized housings that won't fit.

## License

[CERN Open Hardware Licence v2 — Permissive](../../firmware/LICENSE)
