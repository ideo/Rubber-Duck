#!/usr/bin/env python3
"""
Test script: read mic audio from the ESP32 duck over serial.

Sends M,1 to start mic streaming, reads binary frames (0x04 tag),
displays live audio levels. Ctrl+C to stop.

Optional: --save output.wav to save captured audio.

Requires: pyserial (pip install pyserial)
"""

import argparse
import glob
import math
import struct
import sys
import time
import wave

try:
    import serial
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)

MIC_FRAME_TAG = 0x04
SAMPLE_RATE = 16000

def find_serial_port():
    """Find the ESP32 serial port."""
    patterns = ["/dev/tty.usbmodem*", "/dev/tty.usbserial*", "/dev/tty.wchusbserial*"]
    for pat in patterns:
        ports = glob.glob(pat)
        if ports:
            return sorted(ports)[0]
    return None

def rms(samples):
    """Compute RMS of int16 samples."""
    if not samples:
        return 0
    sq_sum = sum(s * s for s in samples)
    return math.sqrt(sq_sum / len(samples))

def peak(samples):
    """Peak absolute value."""
    if not samples:
        return 0
    return max(abs(s) for s in samples)

def level_bar(val, max_val=32767, width=50):
    """ASCII level meter."""
    frac = min(val / max_val, 1.0)
    filled = int(frac * width)
    return "█" * filled + "░" * (width - filled)

def main():
    parser = argparse.ArgumentParser(description="Test ESP32 duck mic streaming")
    parser.add_argument("--port", help="Serial port (auto-detect if omitted)")
    parser.add_argument("--save", help="Save captured audio to WAV file")
    parser.add_argument("--duration", type=float, default=0, help="Record for N seconds (0=until Ctrl+C)")
    args = parser.parse_args()

    port = args.port or find_serial_port()
    if not port:
        print("ERROR: No serial port found. Is the ESP32 plugged in?")
        sys.exit(1)

    print(f"Connecting to {port}...")
    ser = serial.Serial(port, 921600, timeout=0.1)
    time.sleep(0.5)  # Wait for boot messages

    # Drain any boot output
    while ser.in_waiting:
        line = ser.readline()
        if line:
            try:
                print(f"  [boot] {line.decode('utf-8', errors='replace').strip()}")
            except:
                pass

    # Start mic streaming
    print("\nSending M,1 to start mic streaming...")
    ser.write(b"M,1\n")
    time.sleep(0.1)

    # Read response
    while ser.in_waiting:
        line = ser.readline()
        if line:
            try:
                print(f"  {line.decode('utf-8', errors='replace').strip()}")
            except:
                pass

    print("\nListening for mic frames (Ctrl+C to stop)...\n")

    all_samples = []
    frame_count = 0
    start_time = time.time()
    last_print = 0

    try:
        while True:
            if args.duration > 0 and (time.time() - start_time) > args.duration:
                break

            # Look for frame header: [0x04] [len_hi] [len_lo]
            b = ser.read(1)
            if not b:
                continue

            if b[0] == MIC_FRAME_TAG:
                # Read 2-byte length
                hdr = ser.read(2)
                if len(hdr) < 2:
                    continue

                byte_len = (hdr[0] << 8) | hdr[1]
                if byte_len == 0 or byte_len > 2048:
                    continue  # Sanity check

                # Read payload
                payload = b""
                while len(payload) < byte_len:
                    chunk = ser.read(byte_len - len(payload))
                    if chunk:
                        payload += chunk

                if len(payload) != byte_len:
                    continue

                # Decode int16 samples
                num_samples = byte_len // 2
                samples = list(struct.unpack(f"<{num_samples}h", payload))

                all_samples.extend(samples)
                frame_count += 1

                # Print level meter every ~100ms
                now = time.time()
                if now - last_print >= 0.1:
                    r = rms(samples)
                    p = peak(samples)
                    elapsed = now - start_time
                    bar = level_bar(p)
                    print(f"\r  [{elapsed:6.1f}s] frames:{frame_count:5d}  "
                          f"rms:{r:6.0f}  peak:{p:5d}  {bar}", end="", flush=True)
                    last_print = now

            elif b[0] >= 0x20:
                # Text line — read until newline
                line = b + ser.readline()
                try:
                    text = line.decode("utf-8", errors="replace").strip()
                    if text:
                        print(f"\n  [text] {text}")
                except:
                    pass

    except KeyboardInterrupt:
        pass

    elapsed = time.time() - start_time
    print(f"\n\nStopping mic stream...")
    ser.write(b"M,0\n")
    time.sleep(0.1)

    # Drain
    while ser.in_waiting:
        ser.read(ser.in_waiting)

    ser.close()

    print(f"\nCaptured {frame_count} frames, {len(all_samples)} samples ({elapsed:.1f}s)")
    if elapsed > 0:
        actual_rate = len(all_samples) / elapsed
        print(f"Effective sample rate: {actual_rate:.0f} Hz (target: {SAMPLE_RATE})")

    # Save to WAV if requested
    if args.save and all_samples:
        with wave.open(args.save, "w") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(SAMPLE_RATE)
            wf.writeframes(struct.pack(f"<{len(all_samples)}h", *all_samples))
        print(f"Saved to {args.save}")

if __name__ == "__main__":
    main()
