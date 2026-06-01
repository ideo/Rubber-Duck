#!/usr/bin/env python3
"""
gen-tts.py — Generate boy band audio via ElevenLabs TTS.

Outputs a WAV at the duck's NATIVE format (16 kHz mono int16), so the Stage
app's --play streams it with ZERO resampling — the cleanest path to the duck.

Reuses the existing ElevenLabs key from bambu/relay/.env (same key the bambu
duck's gen_phrases.py uses). No separate key needed.

Requests output_format=pcm_16000 directly from ElevenLabs, then wraps the raw
PCM in a WAV header. (ElevenLabs returns headerless PCM for pcm_* formats.)

Usage:
    # Single line → a named WAV
    python3 gen-tts.py "Yeah, we're the ducks." -o stems/test/intro.wav

    # Pick a voice + tune expressiveness
    python3 gen-tts.py "..." -o out.wav --voice ygoBNrnmTEdu5NtDTmAY \
        --stability 0.4 --similarity 0.8

    # List available voices on the account (id + name), then exit
    python3 gen-tts.py --list-voices

Dependencies: httpx (already in bambu/relay/.venv).

This writes FILES ONLY. It does not play audio out of any duck.
"""

import argparse
import os
import struct
import sys
import wave
from pathlib import Path

try:
    import httpx
except ImportError:
    print("error: httpx not installed. Use bambu/relay/.venv:\n"
          "  bambu/relay/.venv/bin/python boyband/scripts/gen-tts.py ...",
          file=sys.stderr)
    sys.exit(1)

# Default voice. Placeholder until the four boy-band voices are picked
# (see boyband/voices.json / docs). This is the bambu duck's canonical
# voice so test clips sound like a known duck.
DEFAULT_VOICE = "ygoBNrnmTEdu5NtDTmAY"

# eleven_multilingual_v2 is the solid general TTS model for the standalone
# /v1/text-to-speech endpoint (the conversational models are for the agent
# websocket). flash/turbo are lower-latency but we're generating offline so
# quality wins.
DEFAULT_MODEL = "eleven_multilingual_v2"

# pcm_16000 = raw 16-bit LE PCM @ 16 kHz mono — the duck's exact format.
OUTPUT_FORMAT = "pcm_16000"
SAMPLE_RATE = 16000


def load_env() -> None:
    """Pull ELEVENLABS_API_KEY from bambu/relay/.env (repo-relative)."""
    env_path = Path(__file__).resolve().parents[2] / "bambu" / "relay" / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def list_voices(api_key: str) -> None:
    r = httpx.get("https://api.elevenlabs.io/v1/voices",
                  headers={"xi-api-key": api_key}, timeout=30.0)
    r.raise_for_status()
    for v in r.json().get("voices", []):
        print(f"  {v.get('voice_id')}  {v.get('name')}")


def tts_to_wav(text: str, out_path: Path, api_key: str, voice: str,
               model: str, stability: float, similarity: float) -> float:
    """Generate speech, write a 16k mono WAV. Returns duration in seconds."""
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice}"
    params = {"output_format": OUTPUT_FORMAT}
    headers = {
        "xi-api-key": api_key,
        "accept": "audio/pcm",
        "content-type": "application/json",
    }
    body = {
        "text": text,
        "model_id": model,
        "voice_settings": {"stability": stability,
                           "similarity_boost": similarity},
    }
    r = httpx.post(url, headers=headers, params=params, json=body, timeout=120.0)
    if r.status_code != 200:
        raise RuntimeError(f"ElevenLabs TTS failed ({r.status_code}): "
                           f"{r.text[:300]}")
    pcm = r.content  # raw int16 LE @ 16 kHz, no header

    # Guard: pcm length should be even (whole int16 samples).
    if len(pcm) % 2 != 0:
        pcm = pcm[:-1]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    w = wave.open(str(out_path), "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SAMPLE_RATE)
    w.writeframes(pcm)
    w.close()
    return (len(pcm) // 2) / SAMPLE_RATE


def main() -> int:
    p = argparse.ArgumentParser(description="Generate boy band TTS audio (16k mono WAV).")
    p.add_argument("text", nargs="?", help="Text to speak")
    p.add_argument("-o", "--out", help="Output WAV path")
    p.add_argument("--voice", default=DEFAULT_VOICE, help=f"ElevenLabs voice_id (default {DEFAULT_VOICE})")
    p.add_argument("--model", default=DEFAULT_MODEL, help=f"model_id (default {DEFAULT_MODEL})")
    p.add_argument("--stability", type=float, default=0.45, help="0=expressive, 1=consistent (default 0.45)")
    p.add_argument("--similarity", type=float, default=0.8, help="voice similarity boost (default 0.8)")
    p.add_argument("--list-voices", action="store_true", help="List account voices and exit")
    args = p.parse_args()

    load_env()
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: ELEVENLABS_API_KEY not found in env or bambu/relay/.env",
              file=sys.stderr)
        return 1

    if args.list_voices:
        list_voices(api_key)
        return 0

    if not args.text or not args.out:
        p.error("text and -o/--out are required (unless --list-voices)")

    dur = tts_to_wav(args.text, Path(args.out), api_key, args.voice,
                     args.model, args.stability, args.similarity)
    print(f"wrote {args.out}  ({dur:.2f}s, 16k mono, voice={args.voice})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
