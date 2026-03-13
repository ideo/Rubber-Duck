#!/usr/bin/env python3
"""
Test script: stream audio to the ESP32-C3 duck over serial.

Usage:
  python3 test_audio_stream.py                        # 440Hz tone (3 seconds)
  python3 test_audio_stream.py --say "Hello world"    # TTS via macOS say command
  python3 test_audio_stream.py --file audio.wav       # stream a WAV file
  python3 test_audio_stream.py --eval                 # send eval mid-stream

Requires: pyserial (pip install pyserial)
"""

import argparse
import glob
import math
import os
import struct
import subprocess
import sys
import tempfile
import time
import wave

try:
    import serial
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)


def find_serial_port():
    """Auto-detect the XIAO ESP32 serial port."""
    patterns = [
        "/dev/tty.usbmodem*",
        "/dev/tty.usbserial*",
        "/dev/tty.wchusbserial*",
    ]
    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    return None


def generate_tone(freq=440, duration=3.0, sample_rate=16000, amplitude=8000):
    """Generate a sine wave as 16-bit signed PCM samples."""
    num_samples = int(sample_rate * duration)
    samples = bytearray()
    for i in range(num_samples):
        t = i / sample_rate
        val = int(amplitude * math.sin(2 * math.pi * freq * t))
        samples += struct.pack("<h", val)
    return bytes(samples), sample_rate


def generate_say(text, voice="Boing", sample_rate=16000):
    """Use macOS `say` to render TTS to a WAV file, then load it."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmppath = f.name

    try:
        # say outputs AIFF by default; use --file-format to get WAV
        # and --data-format to get 16-bit PCM at our target rate
        cmd = [
            "/usr/bin/say",
            "-v", voice,
            "-o", tmppath,
            "--file-format=WAVE",
            f"--data-format=LEI16@{sample_rate}",
            text,
        ]
        print(f"Rendering TTS: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"say failed: {result.stderr}")
            sys.exit(1)

        return load_wav(tmppath)
    finally:
        os.unlink(tmppath)


def load_wav(path):
    """Load a WAV file and return raw PCM bytes + sample rate."""
    with wave.open(path, "rb") as wf:
        assert wf.getsampwidth() == 2, f"Need 16-bit WAV, got {wf.getsampwidth() * 8}-bit"
        sr = wf.getframerate()
        ch = wf.getnchannels()
        frames = wf.readframes(wf.getnframes())

        # If stereo, mix down to mono
        if ch == 2:
            mono = bytearray()
            for i in range(0, len(frames), 4):
                l = struct.unpack_from("<h", frames, i)[0]
                r = struct.unpack_from("<h", frames, i + 2)[0]
                mono += struct.pack("<h", (l + r) // 2)
            frames = bytes(mono)

        return frames, sr


def amplify_pcm(pcm_data, gain=2.0):
    """Scale PCM samples by gain factor, clamping to 16-bit range."""
    out = bytearray()
    for i in range(0, len(pcm_data), 2):
        sample = struct.unpack_from("<h", pcm_data, i)[0]
        sample = int(sample * gain)
        sample = max(-32767, min(32767, sample))
        out += struct.pack("<h", sample)
    return bytes(out)


def send_audio_frame(ser, pcm_chunk):
    """Send one binary audio frame: 0x01 [len_hi] [len_lo] [data...]"""
    length = len(pcm_chunk)
    header = bytes([0x01, (length >> 8) & 0xFF, length & 0xFF])
    ser.write(header + pcm_chunk)


def send_control_message(ser, text):
    """Send a control message during audio mode: 0x02 [len_hi] [len_lo] [text]"""
    msg = text.encode("ascii")
    if not msg.endswith(b"\n"):
        msg += b"\n"
    length = len(msg)
    header = bytes([0x02, (length >> 8) & 0xFF, length & 0xFF])
    ser.write(header + msg)


def stream_audio(ser, pcm_data, sample_rate, send_eval=False):
    """Stream PCM data to the ESP32 with proper framing and pacing.

    Sends FASTER than realtime (2x) so the ring buffer stays full.
    The ESP32's ring buffer (4096 samples = 256ms @ 16kHz) absorbs
    the burst, and I2S DMA drains it at the correct rate.
    """
    frame_samples = 128
    frame_bytes = frame_samples * 2
    frame_duration = frame_samples / sample_rate

    total_frames = (len(pcm_data) + frame_bytes - 1) // frame_bytes
    total_duration = len(pcm_data) / 2 / sample_rate

    # Ring buffer capacity in seconds (must not overflow)
    ring_buf_samples = 8192
    ring_buf_seconds = ring_buf_samples / sample_rate  # 0.256s @ 16kHz

    print(f"Streaming {total_duration:.1f}s of audio ({total_frames} frames)")
    print(f"  Frame: {frame_samples} samples = {frame_duration * 1000:.1f}ms")
    print(f"  Ring buffer: {ring_buf_seconds * 1000:.0f}ms")

    # Enter audio mode
    ser.write(f"A,{sample_rate},16,1\n".encode())
    time.sleep(0.3)

    eval_sent = False
    start = time.time()
    samples_sent = 0

    for i in range(total_frames):
        offset = i * frame_bytes
        chunk = pcm_data[offset : offset + frame_bytes]
        send_audio_frame(ser, chunk)
        samples_sent += len(chunk) // 2

        # Send eval mid-stream
        if send_eval and not eval_sent and i == total_frames // 2:
            send_control_message(ser, "C,0.72,0.85,0.40,0.61,-0.20")
            print("  → Sent eval mid-stream")
            eval_sent = True

        # Pace: allow up to ring_buf_seconds of buffer ahead of playback.
        # This keeps the ring buffer fed without overflowing it.
        elapsed = time.time() - start
        playback_pos = elapsed  # how far I2S has played
        send_pos = samples_sent / sample_rate  # how far we've sent
        ahead = send_pos - playback_pos  # how far ahead of playback

        # If we're more than half the ring buffer ahead, slow down
        if ahead > ring_buf_seconds * 0.5:
            time.sleep(ahead - ring_buf_seconds * 0.25)

        # Progress
        if (i + 1) % 200 == 0 or i == total_frames - 1:
            pct = (i + 1) / total_frames * 100
            print(f"  [{pct:5.1f}%] Frame {i + 1}/{total_frames}")

    # Wait for the ESP32 to play out the remaining buffer
    remaining_seconds = (samples_sent / sample_rate) - (time.time() - start)
    if remaining_seconds > 0:
        print(f"  Waiting {remaining_seconds:.1f}s for playback to finish...")
        time.sleep(remaining_seconds + 0.1)

    # Exit audio mode
    send_control_message(ser, "A,0")
    print("Done.")


def main():
    parser = argparse.ArgumentParser(description="Stream audio to ESP32-C3 duck")
    parser.add_argument("--port", help="Serial port (auto-detected if omitted)")
    parser.add_argument("--file", help="WAV file to stream")
    parser.add_argument("--say", help="Text to speak via macOS say command")
    parser.add_argument("--voice", default="Boing", help="TTS voice (default: Boing)")
    parser.add_argument("--freq", type=int, default=440, help="Tone frequency (default: 440)")
    parser.add_argument("--duration", type=float, default=3.0, help="Tone duration (default: 3)")
    parser.add_argument("--rate", type=int, default=16000, help="Sample rate (default: 16000)")
    parser.add_argument("--gain", type=float, default=2.0, help="Audio gain multiplier (default: 2.0)")
    parser.add_argument("--eval", action="store_true", help="Send test eval mid-stream")
    args = parser.parse_args()

    # Find port
    port = args.port or find_serial_port()
    if not port:
        print("ERROR: No serial port found. Plug in the ESP32 or specify --port")
        sys.exit(1)
    print(f"Port: {port}")

    # Open serial — wait for ESP32 to boot after DTR reset
    ser = serial.Serial(port, 921600, timeout=1)
    print("Waiting for ESP32 boot...")
    time.sleep(4)

    # Drain boot messages
    while ser.in_waiting:
        line = ser.readline().decode("ascii", errors="replace").strip()
        if line:
            print(f"  ESP32: {line}")

    # Confirm comms
    ser.write(b"P\n")
    time.sleep(0.3)
    while ser.in_waiting:
        line = ser.readline().decode("ascii", errors="replace").strip()
        if line:
            print(f"  ESP32: {line}")

    # Load or generate audio
    if args.say:
        pcm_data, sr = generate_say(args.say, voice=args.voice, sample_rate=args.rate)
        print(f"TTS rendered: {sr}Hz, {len(pcm_data) / 2 / sr:.1f}s")
    elif args.file:
        pcm_data, sr = load_wav(args.file)
        print(f"Loaded {args.file}: {sr}Hz, {len(pcm_data) / 2 / sr:.1f}s")
    else:
        pcm_data, sr = generate_tone(args.freq, args.duration, sample_rate=args.rate)
        print(f"Generated {args.freq}Hz tone, {args.duration}s")

    # Apply gain
    if args.gain != 1.0:
        pcm_data = amplify_pcm(pcm_data, args.gain)
        print(f"Applied {args.gain}x gain")

    # Stream
    stream_audio(ser, pcm_data, sr, send_eval=args.eval)

    # Read final output
    time.sleep(0.5)
    while ser.in_waiting:
        line = ser.readline().decode("ascii", errors="replace").strip()
        if line:
            print(f"  ESP32: {line}")

    ser.close()


if __name__ == "__main__":
    main()
