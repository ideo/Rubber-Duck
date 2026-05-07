# Variant photos for the flasher

Drop product photos here, one per board:

- `ducky-pcb.jpg` — official IDEO Ducky PCB (custom WROOM-1 board)
- `xiao-s3.jpg` — Seeed XIAO ESP32-S3
- `waveshare-s3.jpg` — Waveshare ESP32-S3 (if/when added as a card)
- `telyart-s3.jpg` — Telyart ESP32-S3 (if/when added as a card)

The flasher's variant cards reference these by exact filename. If the
file is missing, the card falls back to `placeholder-board.svg` (a
generic silhouette). No code changes needed when you add a real photo
— just drop the file in here with the right name.

**Specs:**
- Square aspect, ~400×400 minimum, jpg or png
- Plain background (white / studio gray) preferred so the photo sits
  cleanly inside the rounded thumbnail container
- Compress to <100 KB each — these load on every flasher visit
