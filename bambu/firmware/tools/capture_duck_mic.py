#!/usr/bin/env python3
"""Capture mic audio from a duck running the canonical rubber_duck_s3 firmware.

Used for A/B mic comparison: flash a XIAO with `firmware/rubber_duck_s3/` (the
known-working Arduino firmware), run this script, get a WAV. Repeat with a
different duck and compare audio quality.

The rubber_duck_s3 mic protocol streams over USB-CDC as binary frames:
    header[0] = 0x04         (MIC_FRAME_TAG)
    header[1] = (len >> 8) & 0xFF
    header[2] =  len       & 0xFF
    payload   = `len` bytes of int16 LE PCM @ 16kHz

Usage:
    python3 capture_duck_mic.py [/dev/cu.usbmodem101] [--seconds 8] [--out duckA.wav]

The script ignores any non-tagged bytes (so log lines, chirps, etc don't
corrupt the capture).
"""
import argparse
import os
import subprocess
import sys
import time
import wave

import serial


MIC_FRAME_TAG = 0x04
SAMPLE_RATE = 16000


def capture(port: str, seconds: int, out_path: str) -> int:
    s = serial.Serial(port, 115200, timeout=0.1)
    pcm = bytearray()
    start = time.time()
    end = start + seconds + 1
    state = "scan"
    expected = 0
    bytes_so_far = 0

    print(f"[capture] listening on {port} for {seconds}s — talk now")
    while time.time() < end and bytes_so_far < SAMPLE_RATE * 2 * seconds:
        b = s.read(1)
        if not b:
            continue
        byte = b[0]
        if state == "scan":
            if byte == MIC_FRAME_TAG:
                state = "len_hi"
        elif state == "len_hi":
            expected = byte << 8
            state = "len_lo"
        elif state == "len_lo":
            expected |= byte
            if 1 <= expected <= 4096:
                state = "data"
                buf = bytearray()
            else:
                state = "scan"  # bogus length — go back to scanning
        elif state == "data":
            buf.append(byte)
            if len(buf) >= expected:
                pcm.extend(buf)
                bytes_so_far += len(buf)
                state = "scan"
    s.close()

    if not pcm:
        print("[capture] no PCM frames found — is the duck running rubber_duck_s3 firmware?")
        return 1

    print(f"[capture] {len(pcm)} bytes ({len(pcm)/2/SAMPLE_RATE:.2f}s) → {out_path}")
    with wave.open(out_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(pcm))

    if os.path.exists("/usr/bin/afplay"):
        print("[capture] playing back...")
        subprocess.run(["/usr/bin/afplay", out_path])
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", nargs="?", default="/dev/cu.usbmodem101")
    ap.add_argument("--seconds", type=int, default=8)
    ap.add_argument("--out", default="duck_mic.wav")
    args = ap.parse_args()
    return capture(args.port, args.seconds, args.out)


if __name__ == "__main__":
    sys.exit(main())
