#!/usr/bin/env python3
"""Capture mic audio that the Bambu duck firmware dumps over USB serial.

The firmware prints a 3-second mic capture as base64-encoded PCM lines
(`PCM:<b64>`) bracketed by `RECORDING START` / `RECORDING END` markers.
This script reads the serial port, decodes, saves as WAV, and (if afplay
is available) plays it back.

Usage:
    python3 capture_mic.py [/dev/cu.usbmodem101]

Resets the chip via DTR/RTS toggle so the capture runs from a fresh boot.
"""
import base64
import os
import subprocess
import sys
import time
import wave

import serial


PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/cu.usbmodem101"
SAMPLE_RATE = 16000
OUT_PATH = "mic.wav"


def main() -> int:
    s = serial.Serial(PORT, 115200, timeout=0.5)
    # Reset the chip so we start from boot.
    s.dtr = False
    s.rts = True
    time.sleep(0.05)
    s.rts = False

    pcm = bytearray()
    collecting = False
    deadline = time.time() + 20  # whole capture incl. countdown
    print(f"[capture] reset chip, listening on {PORT} ...")

    while time.time() < deadline:
        line = s.readline()
        if not line:
            continue
        try:
            d = line.decode(errors="replace").strip()
        except Exception:
            continue
        # Surface the firmware's countdown so user knows when to talk.
        if "MIC CAPTURE" in d or "RECORDING START" in d or "RECORDING END" in d:
            print(f"[duck] {d.split(']')[-1].strip()}")
        if "RECORDING START" in d:
            collecting = True
            pcm.clear()
            continue
        if "RECORDING END" in d:
            break
        if collecting and "PCM:" in d:
            try:
                payload = d.split("PCM:", 1)[1]
                pcm.extend(base64.b64decode(payload))
            except Exception as e:
                print(f"[capture] decode error: {e}")

    s.close()

    if not pcm:
        print("[capture] no PCM captured — did the chip reset cleanly?")
        return 1

    print(f"[capture] {len(pcm)} bytes PCM ({len(pcm)/2/SAMPLE_RATE:.2f}s) → {OUT_PATH}")
    with wave.open(OUT_PATH, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(pcm))

    if os.path.exists("/usr/bin/afplay"):
        print("[capture] playing back...")
        subprocess.run(["/usr/bin/afplay", OUT_PATH])
    return 0


if __name__ == "__main__":
    sys.exit(main())
