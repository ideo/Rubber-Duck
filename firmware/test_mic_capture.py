#!/usr/bin/env python3
"""Capture mic audio from the ESP32 duck over serial and save as WAV.

Usage:
    python3 test_mic_capture.py [--port /dev/tty.usbmodem101] [--seconds 5]

Sends MIC,1 to start streaming, captures frames, sends MIC,0 to stop.
Saves to mic_capture.wav. Play with: afplay mic_capture.wav
"""

import serial
import struct
import wave
import argparse
import time
import sys

SAMPLE_RATE = 16000
MIC_FRAME_TAG = 0x04
MIC_FRAME_SAMPLES = 256

def capture(port="/dev/tty.usbmodem101", seconds=5, baud=921600):
    print(f"Opening {port}...")
    ser = serial.Serial(port, baud, timeout=1)
    time.sleep(0.5)  # let serial settle

    # Flush any pending data
    ser.reset_input_buffer()

    # Start mic streaming
    print("Sending MIC,1...")
    ser.write(b"MIC,1\n")
    time.sleep(0.2)

    samples = []
    frames_captured = 0
    target_frames = (SAMPLE_RATE * seconds) // MIC_FRAME_SAMPLES
    start = time.time()

    print(f"Capturing {seconds}s ({target_frames} frames)...")

    try:
        while frames_captured < target_frames and (time.time() - start) < seconds + 2:
            # Look for frame header: TAG LEN_HI LEN_LO
            b = ser.read(1)
            if not b:
                continue

            if b[0] == MIC_FRAME_TAG:
                # Read length (2 bytes, big-endian)
                len_bytes = ser.read(2)
                if len(len_bytes) < 2:
                    continue
                payload_len = (len_bytes[0] << 8) | len_bytes[1]

                # Read PCM payload
                pcm = ser.read(payload_len)
                if len(pcm) < payload_len:
                    print(f"  Short read: got {len(pcm)}/{payload_len}")
                    continue

                # Decode 16-bit signed PCM
                n_samples = payload_len // 2
                if len(pcm) >= n_samples * 2:
                    frame_samples = struct.unpack(f"<{n_samples}h", pcm[:n_samples * 2])
                    samples.extend(frame_samples)
                else:
                    continue  # skip short frame
                frames_captured += 1

                if frames_captured % 20 == 0:
                    # Show level meter
                    peak = max(abs(s) for s in frame_samples)
                    bar = "#" * min(40, peak // 800)
                    print(f"  Frame {frames_captured}/{target_frames}  peak={peak:5d}  |{bar}")

    except KeyboardInterrupt:
        print("\nInterrupted.")
    finally:
        # Stop mic streaming
        print("Sending MIC,0...")
        ser.write(b"MIC,0\n")
        ser.close()

    if not samples:
        print("No audio captured! Check wiring and firmware.")
        return

    # Save WAV
    filename = "mic_capture.wav"
    with wave.open(filename, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))

    duration = len(samples) / SAMPLE_RATE
    peak = max(abs(s) for s in samples)
    print(f"\nSaved {filename} — {duration:.1f}s, {len(samples)} samples, peak={peak}")
    print(f"Play: afplay {filename}")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--port", default="/dev/tty.usbmodem101")
    p.add_argument("--seconds", type=int, default=5)
    args = p.parse_args()
    capture(args.port, args.seconds)
