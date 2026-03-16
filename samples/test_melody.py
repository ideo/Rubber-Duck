#!/usr/bin/env python3
"""Test the Jeopardy "Think!" melody — rubberband for pitch, ffmpeg for concat."""

import subprocess, tempfile, os

SAMPLE = os.path.join(os.path.dirname(__file__), "mmmm.aiff")
BASE_MIDI = 53  # F3 — natural pitch of Ralph "Mmmm"
BPM = 90
BEAT = 60.0 / BPM

# Rest durations in beats
Q = 1    # quarter rest
H = 2    # half rest
W = 4    # whole rest

# Melody as a flat sequence of events:
#   int       = play note at that MIDI pitch (sample's natural ~0.58s length)
#   (int, s)  = play note trimmed to s seconds (for fast runs)
#   float     = rest for that many beats of silence
#
# Jeopardy "Think!" — C-F call-and-response with chromatic descent.
FAST = 0.29  # half the sample length — double speed for runs

MELODY = [
    # Bars 1-2: bum-bum-bum-bum-bum-bum-bum (rest)
    60, 65, 60, 53, 60, 65, 60, float(Q),

    # Bars 3-4: bum-bum-bum-bum-BUM (rest) bupbupbupbupbup (rest)
    60, 65, 60, 65, 69, float(0.5),
    (67, FAST), (65, FAST), (64, FAST), (62, FAST), (61, FAST), float(0.5),

    # Bars 5-6: repeat of 1-2
    60, 65, 60, 53, 60, 65, 60, float(Q),

    # Bars 7-8: resolving descent
    65, float(0.5), (62, FAST), 60, 58, 57, float(0.75), 55, float(0.75), 53, float(Q),
]

def note_name(midi):
    names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    return f"{names[midi % 12]}{midi // 12 - 1}"

def pitch_shift(semis, tmpdir, idx, trim=None):
    """Rubberband pitch-shift. Optionally trim for fast runs."""
    shifted = os.path.join(tmpdir, f"shifted_{idx}.wav")
    wav_in = os.path.join(tmpdir, f"input_{idx}.wav")
    subprocess.run(["ffmpeg", "-y", "-i", SAMPLE, "-ar", "44100", "-ac", "1", wav_in],
                   capture_output=True, check=True)
    subprocess.run(["rubberband", "-p", str(semis), wav_in, shifted],
                   capture_output=True, check=True)
    if trim is None:
        return shifted
    out = os.path.join(tmpdir, f"note_{idx}.wav")
    subprocess.run([
        "ffmpeg", "-y", "-i", shifted,
        "-af", f"atrim=0:{trim},afade=t=out:st={max(0, trim - 0.03)}:d=0.03",
        "-ar", "44100", "-ac", "1", out
    ], capture_output=True, check=True)
    return out

def make_silence(duration_sec, tmpdir, idx):
    """Generate silence segment."""
    outfile = os.path.join(tmpdir, f"silence_{idx}.wav")
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",
        "-t", str(duration_sec), "-ar", "44100", "-ac", "1", outfile
    ], capture_output=True, check=True)
    return outfile

def build(melody=None):
    if melody is None:
        melody = MELODY
    tmpdir = tempfile.mkdtemp(prefix="jeopardy_")
    print(f"Temp: {tmpdir}\n")

    segments = []
    seg_idx = 0

    for event in melody:
        if isinstance(event, float):
            dur = event * BEAT
            print(f"  {'':>4s}  rest ({dur:.2f}s)")
            segments.append(make_silence(dur, tmpdir, seg_idx))
        elif isinstance(event, tuple):
            midi, trim = event
            semis = midi - BASE_MIDI
            print(f"  {note_name(midi):>4s}  {semis:+3d} st  (fast {trim:.2f}s)")
            segments.append(pitch_shift(semis, tmpdir, seg_idx, trim=trim))
        else:
            semis = event - BASE_MIDI
            print(f"  {note_name(event):>4s}  {semis:+3d} st")
            segments.append(pitch_shift(semis, tmpdir, seg_idx))
        seg_idx += 1

    # Concat
    listfile = os.path.join(tmpdir, "concat.txt")
    with open(listfile, "w") as f:
        for seg in segments:
            f.write(f"file '{seg}'\n")

    outfile = os.path.join(tmpdir, "jeopardy_hum.wav")
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", listfile,
        "-c", "copy", outfile
    ], capture_output=True, check=True)

    notes = sum(1 for e in melody if isinstance(e, int) or isinstance(e, tuple))
    rests = sum(1 for e in melody if isinstance(e, float))
    print(f"\n✓ {outfile}")
    print(f"  {notes} notes, {rests} rests")
    print(f"  afplay {outfile}")

LAST_BARS = [
    # Bars 7-8 only — for quick iteration
    65, float(0.5), (62, FAST), 60, 58, 57, float(0.75), 55, float(0.75), 53, float(Q),
]

if __name__ == "__main__":
    import sys
    if "--last" in sys.argv:
        build(LAST_BARS)
    else:
        build(MELODY)
