#!/usr/bin/env python3
"""
Duck chirp synthesizer — Python port of ChirpSynth.ino
Generates the exact same waveform as the firmware:
  Sawtooth oscillator -> Chamberlin SVF bandpass -> 16-bit PCM

Usage:
  python3 test_chirp_synth.py              # play on laptop speakers
  python3 test_chirp_synth.py --serial     # stream to duck over serial
"""

import math
import struct
import sys
import wave
import subprocess
import tempfile
import os

SAMPLE_RATE = 16000

# ============================================================
# Chamberlin State Variable Filter (matches firmware exactly)
# ============================================================
class SVF:
    def __init__(self):
        self.low = 0.0
        self.band = 0.0
        self.prev_input = 0.0
        self.f = 0.0
        self.damp = 0.0

    def reset(self):
        self.low = 0.0
        self.band = 0.0
        self.prev_input = 0.0

    def set_frequency(self, center_freq, Q, sample_rate):
        if center_freq < 20.0:
            center_freq = 20.0
        max_freq = sample_rate / 2.5
        if center_freq > max_freq:
            center_freq = max_freq
        if Q < 0.7:
            Q = 0.7
        if Q > 5.0:
            Q = 5.0
        self.f = math.sin(math.pi * center_freq / (sample_rate * 2.0))
        self.damp = 1.0 / Q

    def process(self, inp):
        # Iteration 1: interpolated input
        mid = (inp + self.prev_input) * 0.5
        self.low += self.f * self.band
        high = mid - self.low - self.damp * self.band
        self.band += self.f * high

        # Iteration 2: current input directly
        self.low += self.f * self.band
        high = inp - self.low - self.damp * self.band
        self.band += self.f * high

        self.prev_input = inp
        return self.band  # bandpass output


# ============================================================
# Sawtooth oscillator
# ============================================================
class Saw:
    def __init__(self):
        self.phase = 0.0

    def sample(self, freq, sample_rate):
        self.phase += freq / sample_rate
        if self.phase >= 1.0:
            self.phase -= 1.0
        return 2.0 * self.phase - 1.0

    def sine_sample(self, freq, sample_rate):
        self.phase += freq / sample_rate
        if self.phase >= 1.0:
            self.phase -= 1.0
        return math.sin(2.0 * math.pi * self.phase)


# ============================================================
# Hill envelope: 40% rise, 60% fall
# ============================================================
def hill_envelope(t):
    if t < 0.4:
        return t / 0.4
    return 1.0 - (t - 0.4) / 0.6


# ============================================================
# Generate a single chirp note
# ============================================================
def generate_note(start_freq, end_freq, duration_ms, filter_start, filter_end,
                  filter_rise_rate, use_sine=False, filter_track_harmonic=False,
                  Q=5.0, amplitude=1.0):
    svf = SVF()
    saw = Saw()
    svf.reset()
    svf.set_frequency(filter_start, Q, SAMPLE_RATE)

    num_samples = int(SAMPLE_RATE * duration_ms / 1000.0)
    samples = []

    for i in range(num_samples):
        t = i / float(num_samples)

        # Frequency sweep (linear)
        freq = start_freq + (end_freq - start_freq) * t

        # Oscillator
        if use_sine:
            raw = saw.sine_sample(freq, SAMPLE_RATE)
        else:
            raw = saw.sample(freq, SAMPLE_RATE)

        # Filter envelope
        filter_t = min(t * filter_rise_rate, 1.0)
        current_filter = filter_start + (filter_end - filter_start) * filter_t
        if filter_track_harmonic:
            current_filter = freq * 3.0  # track 3rd harmonic
        svf.set_frequency(current_filter, Q, SAMPLE_RATE)

        # Apply filter
        filtered = svf.process(raw)

        # Amplitude envelope
        amp = hill_envelope(t) * amplitude

        # Scale to 16-bit with soft compression (matching firmware)
        sample = filtered * amp * 32767.0
        threshold = 13000.0
        if sample > threshold:
            sample = threshold + (32767.0 - threshold) * math.tanh((sample - threshold) / (32767.0 - threshold))
        elif sample < -threshold:
            sample = -threshold - (32767.0 - threshold) * math.tanh((-sample - threshold) / (32767.0 - threshold))

        sample = max(-32767, min(32767, int(sample)))
        samples.append(sample)

    return samples


# ============================================================
# Chirp presets (matching firmware)
# ============================================================
def chirp_expression(sentiment=0.5):
    """Standard quack — swept sawtooth + opening bandpass"""
    base = 400 + int(sentiment * 200)
    end = int(base * 1.4) if sentiment > 0 else int(base * 0.6)

    if sentiment > 0:
        fs, fe, fr = 300.0, 2200.0, 5.0
    else:
        fs, fe, fr = 250.0, 1200.0, 8.0

    return generate_note(base, end, 250, fs, fe, fr, amplitude=2.0)


def chirp_startup():
    """Ascending two-note sine: 400Hz -> 600Hz"""
    note1 = generate_note(400, 400, 120, 800, 3000, 10.0, use_sine=True, amplitude=0.5)
    gap = [0] * int(SAMPLE_RATE * 30 / 1000.0)
    note2 = generate_note(600, 600, 120, 800, 3000, 10.0, use_sine=True, amplitude=0.5)
    return note1 + gap + note2


def chirp_whistle(sentiment=0.8):
    """Two-note ascending whistle"""
    base = 400 + int(sentiment * 200)
    end = int(base * 1.68)

    note1 = generate_note(base, end, 500, 300, 2200, 5.0, amplitude=2.0)
    gap = [0] * int(SAMPLE_RATE * 120 / 1000.0)
    note2 = generate_note(base, end, 1200, 300, 2200, 5.0,
                          filter_track_harmonic=True, amplitude=2.0)
    return note1 + gap + note2


def chirp_uh_uh(sentiment=-0.5):
    """Two-note descending uh-uh"""
    base = 400 + int(sentiment * 200)
    end = int(base * 1.5)

    note1 = generate_note(base, end, 200, 250, 1200, 8.0, amplitude=2.0)
    gap = [0] * int(SAMPLE_RATE * 50 / 1000.0)

    n2_start = int(base * 0.9)
    n2_end = int(base * 0.45)
    note2 = generate_note(n2_start, n2_end, 400, 1200, 300, 3.0, amplitude=2.0)
    return note1 + gap + note2


def chirp_permission():
    """Permission uh-oh"""
    import random
    root = 220 + random.randint(0, 60)
    lower = int(root * 0.70)

    note1 = generate_note(root, root, 120, 1400, 300, 4.0, amplitude=2.0)
    gap = [0] * int(SAMPLE_RATE * 70 / 1000.0)
    note2 = generate_note(lower, lower, 180, 1400, 300, 4.0, amplitude=2.0)
    return note1 + gap + note2


# ============================================================
# Output
# ============================================================
def play_samples(samples):
    """Write to temp WAV and play via afplay"""
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        path = f.name
        w = wave.open(f, 'w')
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(struct.pack(f'<{len(samples)}h', *samples))
        w.close()

    print(f"Playing {len(samples)} samples ({len(samples)/SAMPLE_RATE:.2f}s) ...")
    subprocess.run(['afplay', path])
    os.unlink(path)


def stream_to_serial(samples, port='/dev/cu.usbmodem101'):
    """Stream as binary frames to duck (same as widget TTS path)"""
    import serial
    ser = serial.Serial(port, 9600)

    # Binary frame header: 0xAA 0x55 + 2-byte length
    chunk_size = 128  # samples per frame
    data = struct.pack(f'<{len(samples)}h', *samples)

    for i in range(0, len(data), chunk_size * 2):
        chunk = data[i:i + chunk_size * 2]
        header = bytes([0xAA, 0x55]) + struct.pack('<H', len(chunk))
        ser.write(header + chunk)

    ser.close()
    print(f"Streamed {len(samples)} samples to {port}")


if __name__ == '__main__':
    serial_mode = '--serial' in sys.argv

    print("=== Duck Chirp Synth Test ===\n")

    chirps = [
        ("Startup", chirp_startup()),
        ("Expression (happy)", chirp_expression(0.7)),
        ("Expression (sad)", chirp_expression(-0.3)),
        ("Whistle", chirp_whistle(0.8)),
        ("Uh-uh", chirp_uh_uh(-0.5)),
        ("Permission", chirp_permission()),
    ]

    for name, samples in chirps:
        print(f"\n--- {name} ---")
        if serial_mode:
            stream_to_serial(samples)
        else:
            play_samples(samples)
