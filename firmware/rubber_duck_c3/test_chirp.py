#!/usr/bin/env python3
"""
Chirp test: send test commands to the ESP32 duck and listen for responses.

Sends T (positive chirp), X (negative chirp), W (whistle), Q (permission)
and prints all serial output so you can hear and verify each chirp.

Requires: pyserial (pip install pyserial)
"""

import glob
import sys
import time

try:
    import serial
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)

def find_serial_port():
    patterns = ["/dev/tty.usbmodem*", "/dev/tty.usbserial*", "/dev/tty.wchusbserial*"]
    for pat in patterns:
        ports = glob.glob(pat)
        if ports:
            return sorted(ports)[0]
    return None

def drain(ser, timeout=0.5):
    """Read and print all available output."""
    end = time.time() + timeout
    while time.time() < end:
        if ser.in_waiting:
            try:
                line = ser.readline().decode("utf-8", errors="replace").strip()
                if line:
                    print(f"  {line}")
            except:
                pass
        else:
            time.sleep(0.02)

def main():
    port = find_serial_port()
    if not port:
        print("ERROR: No serial port found.")
        sys.exit(1)

    print(f"Connecting to {port}...")
    ser = serial.Serial(port, 921600, timeout=0.1)
    time.sleep(1)
    drain(ser, 1.0)

    tests = [
        ("T", "Positive chirp (single quack)"),
        ("X", "Negative chirp (uh-uh double)"),
        ("W", "Whistle chirp (long ascending)"),
        ("Q", "Permission chirp (uh-oh)"),
    ]

    for cmd, desc in tests:
        print(f"\n{'='*50}")
        print(f"  {desc}")
        print(f"  Sending: {cmd}")
        print(f"{'='*50}")
        ser.write(f"{cmd}\n".encode())

        # Wait for chirp to play + K signal
        drain(ser, 3.0)

        input("  Press Enter for next test...")

    print("\nDone!")
    ser.close()

if __name__ == "__main__":
    main()
