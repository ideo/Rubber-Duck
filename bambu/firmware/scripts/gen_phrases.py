#!/usr/bin/env python3
"""Generate Bambu Duck onboarding phrases via ElevenLabs TTS, then
transcode to on-chip Opus format.

The duck's runtime conversational voice is also ElevenLabs (Liam,
voice_id TX3LPaxmHKxFdv7VOQHJ — see bambu/elevenlabs/agent-template.json
and bambu/agent/voice.md). Using the same voice for spoken onboarding
phrases means there's no jarring shift between "the duck explains
itself before WiFi" and "the duck answers your question after WiFi."

Output:
  bambu/firmware/main/phrases/<phrase>.opus  — embedded by CMakeLists
  bambu/firmware/main/phrases/<phrase>.txt   — the text, for grep
                                                review + diffing

Idempotent: skips phrases whose .opus is already present and newer
than the script. Re-generate one phrase by deleting its .opus first.

Requires:
  - ELEVENLABS_API_KEY in env or bambu/relay/.env
  - ffmpeg with libopus (brew install ffmpeg)
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import httpx


# Match the voice in bambu/elevenlabs/agent-template.json — the same
# voice the conversational agent uses, so the onboarding monologue
# and the live conversation sound like the same duck.
VOICE_ID = "ygoBNrnmTEdu5NtDTmAY"
# Use a non-conversational TTS model for the standalone /v1/text-to-speech
# endpoint. The conversational model_id (eleven_v3_conversational) is
# only valid via the agent's WS path.
MODEL_ID = "eleven_turbo_v2_5"
OUTPUT_FORMAT = "mp3_44100_128"

# Phrases the duck speaks during onboarding. Keep each under ~10s so
# the chip's flash budget stays reasonable. Use natural pauses
# ("Connect... and a setup page will open") rather than long run-on
# sentences — TTS pacing tracks punctuation.
PHRASES: dict[str, str] = {
    # Fresh chip, no WiFi creds. Plays at boot to tell the user how
    # to start the onboarding loop.
    "tap_to_start": (
        "Press my button when you're ready and I'll set up a "
        "WiFi network you can join."
    ),

    # Wizard's AP is up. Tells user the SSID name + how to join.
    "wifi_up": (
        "WiFi's up. Look for Duck Duck Duck and join it."
    ),

    # NOTE: there's no static "ready" phrase here. The post-onboarding
    # confirmation is generated dynamically by the relay (it knows the
    # bound printer names + has the ElevenLabs key), TTS'd, and pushed
    # to the chip as Opus bytes over /ws/notify. See phrase_play_blob.
}

# Opus encoding parameters. 24 kbps voip mode is the sweet spot for
# speech intelligibility at minimum size — preserves consonants and
# voice character while keeping each phrase under ~15 KB on the chip.
OPUS_BITRATE = "24k"
OPUS_SAMPLE_RATE = "16000"
OPUS_CHANNELS = "1"


def load_env() -> None:
    """Auto-load bambu/relay/.env so we can pick up ELEVENLABS_API_KEY
    without forcing the operator to copy it into another file."""
    env_path = Path(__file__).resolve().parents[2] / "relay" / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def tts_to_mp3(text: str, mp3_path: Path, api_key: str) -> None:
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    headers = {
        "xi-api-key": api_key,
        "accept": "audio/mpeg",
        "content-type": "application/json",
    }
    body = {
        "text": text,
        "model_id": MODEL_ID,
        "output_format": OUTPUT_FORMAT,
        # Slightly more expressive than the agent's runtime defaults
        # since these are pre-recorded one-shots, not turn-by-turn
        # conversation. Keep similarity_boost matching though so
        # voice character stays recognizable.
        # Match the agent's runtime voice settings so onboarding +
        # conversation feel like the same duck.
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.8,
        },
    }
    r = httpx.post(url, headers=headers, json=body, timeout=60.0)
    if r.status_code != 200:
        raise RuntimeError(f"ElevenLabs TTS failed ({r.status_code}): "
                           f"{r.text[:300]}")
    mp3_path.write_bytes(r.content)


def transcode(mp3_path: Path, opus_path: Path) -> int:
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(mp3_path),
        "-c:a", "libopus",
        "-b:a", OPUS_BITRATE,
        "-ar", OPUS_SAMPLE_RATE,
        "-ac", OPUS_CHANNELS,
        "-application", "voip",
        "-vbr", "on",
        "-compression_level", "10",
        str(opus_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr.strip()}")
    return opus_path.stat().st_size


def main() -> int:
    load_env()
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    if not api_key:
        print("ERROR: ELEVENLABS_API_KEY not set "
              "(checked env + bambu/relay/.env)", file=sys.stderr)
        return 1

    out_dir = Path(__file__).resolve().parents[1] / "main" / "phrases"
    out_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    generated = 0
    skipped = 0
    for name, text in PHRASES.items():
        opus_path = out_dir / f"{name}.opus"
        txt_path = out_dir / f"{name}.txt"

        # Always (re)write the txt sidecar — cheap, makes review
        # surface always match what was generated.
        txt_path.write_text(text + "\n")

        if opus_path.exists() and opus_path.stat().st_size > 0:
            print(f"  skip  {name:14s} ({opus_path.stat().st_size:5d} bytes — "
                  "delete to regenerate)")
            skipped += 1
            total += opus_path.stat().st_size
            continue

        with tempfile.TemporaryDirectory() as td:
            mp3 = Path(td) / f"{name}.mp3"
            print(f"  gen   {name:14s} -> ", end="", flush=True)
            try:
                tts_to_mp3(text, mp3, api_key)
                size = transcode(mp3, opus_path)
            except Exception as e:
                print(f"FAIL: {e}")
                continue
            print(f"OK ({size:5d} bytes)")
            total += size
            generated += 1

    print()
    print(f"Generated: {generated}  Skipped: {skipped}  "
          f"Total: {total:,} bytes ({total/1024:.1f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
