#!/usr/bin/env python3
"""
gen-dialogue.py — Build time-aligned per-duck tracks for a call/response bit.

Given an ordered dialogue (who says what), generates each line via ElevenLabs
TTS and assembles ONE WAV per duck where each duck is SILENT while the others
talk. Play the resulting tracks together with Stage's synchronized multi-play
(`--play D1.wav D1 --play D2.wav D2`) and you get sequential call/response —
the seed of the Mode 1 multitrack "piano roll."

All tracks come out the same length (the full dialogue duration), 16k/mono/
int16 — the duck's native format, zero resampling downstream.

This is a baby sequencer: the timeline is the sum of each line's duration plus
a small inter-line gap; each line's audio is placed at its slot on the speaking
duck's track, silence everywhere else.

Reuses the ElevenLabs key from bambu/relay/.env. Writes files only — no duck
audio.

Usage:
    python3 gen-dialogue.py --out-dir stems/test
    # → stems/test/dialogue_D1.wav, dialogue_D2.wav
"""

import argparse
import os
import sys
import wave
from pathlib import Path

try:
    import httpx
except ImportError:
    print("error: httpx not installed; use bambu/relay/.venv", file=sys.stderr)
    sys.exit(1)

SAMPLE_RATE = 16000
MODEL = "eleven_multilingual_v2"

# Two distinct voices so Mallard and Pekin sound different. Both are known-
# valid IDs on this account (ygo… = bambu canonical; TX3… from gen_phrases.py).
VOICE = {
    "D1": "U5UjeJMsOvyhYhXfZdvZ",   # Mallard (picked 2026-06-01)
    "D2": "Xb3zeLrTi6F4ziIcXdwk",   # Pekin (picked 2026-06-01)
}

# Named bits. Alternating turns = clean call/response. Short + punchy.
# Pick with --script NAME; output files are prefixed with the name
# (e.g. moby_D1.wav, moby_D2.wav).
DIALOGUES = {
    "intro": [
        ("D1", "Pekin. Pekin! Are you ready for this?"),
        ("D2", "Mallard, I was born ready."),
        ("D1", "Then let's give 'em what they came for. On three."),
        ("D2", "A duck boy band?"),
        ("D1", "A duck. boy. BAND."),
        ("D2", "...okay yeah, that's pretty good."),
    ],
    # Both ducks realize they're reincarnations of the same Ishmael from
    # "Moby Duck" — one soul, split in two. 6 turns, punchy.
    "moby": [
        ("D1", "Pekin. Do you ever feel like you've... been here before?"),
        ("D2", "Call me Ishmael."),
        ("D1", "I was about to say that. I AM Ishmael."),
        ("D2", "Moby Duck. The white whale. The voyage. You were there."),
        ("D1", "We're the same soul, aren't we. One duck, split in two."),
        ("D2", "...so which of us gets the royalties?"),
    ],
}

GAP_MS = 350  # silence between turns, ms


def load_env() -> None:
    env_path = Path(__file__).resolve().parents[2] / "bambu" / "relay" / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def tts_pcm(text: str, voice: str, api_key: str) -> bytes:
    """Return raw int16 LE PCM @ 16 kHz mono for `text`."""
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice}"
    r = httpx.post(
        url,
        headers={"xi-api-key": api_key, "accept": "audio/pcm",
                 "content-type": "application/json"},
        params={"output_format": "pcm_16000"},
        json={"text": text, "model_id": MODEL,
              "voice_settings": {"stability": 0.4, "similarity_boost": 0.8}},
        timeout=120.0,
    )
    if r.status_code != 200:
        raise RuntimeError(f"TTS failed ({r.status_code}) for voice {voice}: {r.text[:200]}")
    pcm = r.content
    return pcm[:-1] if len(pcm) % 2 else pcm


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--script", default="intro", choices=sorted(DIALOGUES.keys()),
                   help="Which named dialogue to generate (default: intro)")
    p.add_argument("--out-dir", default="stems/test")
    args = p.parse_args()

    load_env()
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: ELEVENLABS_API_KEY not set", file=sys.stderr)
        return 1

    dialogue = DIALOGUES[args.script]
    ducks = sorted({d for d, _ in dialogue})
    gap = b"\x00\x00" * int(SAMPLE_RATE * GAP_MS / 1000)

    # Generate each turn, remember (duck, pcm).
    turns = []
    for i, (duck, text) in enumerate(dialogue):
        voice = VOICE.get(duck)
        if not voice:
            print(f"ERROR: no voice for {duck}", file=sys.stderr)
            return 1
        pcm = tts_pcm(text, voice, api_key)
        secs = (len(pcm) // 2) / SAMPLE_RATE
        print(f"  turn {i}: {duck} ({secs:.2f}s) “{text[:40]}”")
        turns.append((duck, pcm))

    # Assemble: walk the timeline; each turn occupies [now, now+len]. The
    # speaking duck gets the audio there; every other duck gets equal-length
    # silence. After each turn, all tracks get the gap silence.
    tracks = {d: bytearray() for d in ducks}
    for duck, pcm in turns:
        for d in ducks:
            tracks[d].extend(pcm if d == duck else b"\x00\x00" * (len(pcm) // 2))
        for d in ducks:
            tracks[d].extend(gap)

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for d in ducks:
        path = out_dir / f"{args.script}_{d}.wav"
        w = wave.open(str(path), "wb")
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(tracks[d]))
        w.close()
        dur = (len(tracks[d]) // 2) / SAMPLE_RATE
        print(f"wrote {path}  ({dur:.2f}s)")
    # Sanity: all tracks identical length (required for sync).
    lens = {len(tracks[d]) for d in ducks}
    print("tracks aligned ✓" if len(lens) == 1 else f"WARNING: track lengths differ {lens}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
