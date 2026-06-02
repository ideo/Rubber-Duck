#!/usr/bin/env python3
"""
gen-play-stems.py — Generate aligned four-duck stems from a markdown play.

Reads speaker-tagged markdown lines like:

    **CLASSIC:** Five minutes. Deep breaths.

Calls ElevenLabs once per spoken line, then assembles one WAV per duck where
the active speaker has audio and the other ducks have timeline-matched silence.
The resulting four files start together and stay aligned for Stage/DAW use.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import wave
from pathlib import Path

try:
    import httpx
except ImportError:
    print("error: httpx not installed; use bambu/relay/.venv or install httpx",
          file=sys.stderr)
    sys.exit(1)

SAMPLE_RATE = 16000
MODEL = "eleven_multilingual_v2"
OUTPUT_FORMAT = "pcm_16000"
GAP_MS = 300

SPEAKER_TO_DUCK = {
    "CLASSIC": "D1",
    "MALLARD": "D2",
    "PINTAIL": "D3",
    "PEKIN": "D4",
}

DUCK_NAMES = {
    "D1": "Classic",
    "D2": "Mallard",
    "D3": "Pintail",
    "D4": "Pekin",
}

# Known-good voices from prior hardware tests plus the canonical Bambu voice.
# Override with --voice D1=... etc once final four show voices are picked.
DEFAULT_VOICES = {
    "D1": "ygoBNrnmTEdu5NtDTmAY",
    "D2": "U5UjeJMsOvyhYhXfZdvZ",
    "D3": "TX3LPaxmHKxFdv7VOQHJ",
    "D4": "Xb3zeLrTi6F4ziIcXdwk",
}

LINE_RE = re.compile(r"^\*\*([A-Z][A-Z ]+):\*\*\s*(.+?)\s*$")


def load_env_files() -> None:
    repo = Path(__file__).resolve().parents[2]
    for env_path in [repo / "boyband" / ".env.local",
                     repo / "bambu" / "relay" / ".env"]:
        if not env_path.exists():
            continue
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def keychain_api_key() -> str | None:
    try:
        r = subprocess.run(
            ["security", "find-generic-password",
             "-s", "com.duckduckduck.boyband.elevenlabs", "-w"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None
    key = r.stdout.strip()
    return key if r.returncode == 0 and key else None


def api_key() -> str | None:
    load_env_files()
    return os.environ.get("ELEVENLABS_API_KEY") or keychain_api_key()


def parse_script(path: Path) -> list[dict]:
    turns = []
    for lineno, raw in enumerate(path.read_text().splitlines(), start=1):
        m = LINE_RE.match(raw.strip())
        if not m:
            continue
        speaker = m.group(1).strip()
        text = m.group(2).strip()
        duck = SPEAKER_TO_DUCK.get(speaker)
        if not duck:
            raise ValueError(f"{path}:{lineno}: unknown speaker {speaker!r}")
        turns.append({
            "index": len(turns) + 1,
            "line": lineno,
            "speaker": speaker.title(),
            "duck": duck,
            "text": text,
        })
    if not turns:
        raise ValueError(f"no speaker-tagged dialogue found in {path}")
    return turns


def list_voices(key: str) -> None:
    r = httpx.get("https://api.elevenlabs.io/v1/voices",
                  headers={"xi-api-key": key}, timeout=30.0)
    r.raise_for_status()
    for v in r.json().get("voices", []):
        print(f"{v.get('voice_id')}  {v.get('name')}")


def tts_pcm(text: str, voice: str, key: str, stability: float,
            similarity: float) -> bytes:
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice}"
    r = httpx.post(
        url,
        headers={
            "xi-api-key": key,
            "accept": "audio/pcm",
            "content-type": "application/json",
        },
        params={"output_format": OUTPUT_FORMAT},
        json={
            "text": text,
            "model_id": MODEL,
            "voice_settings": {
                "stability": stability,
                "similarity_boost": similarity,
            },
        },
        timeout=120.0,
    )
    if r.status_code != 200:
        raise RuntimeError(f"TTS failed ({r.status_code}) for voice {voice}: "
                           f"{r.text[:300]}")
    pcm = r.content
    return pcm[:-1] if len(pcm) % 2 else pcm


def write_wav(path: Path, pcm: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm)


def parse_voice_overrides(values: list[str]) -> dict[str, str]:
    voices = dict(DEFAULT_VOICES)
    for value in values:
        if "=" not in value:
            raise ValueError(f"--voice must look like D1=voice_id, got {value!r}")
        duck, voice = value.split("=", 1)
        duck = duck.strip().upper()
        if duck not in DUCK_NAMES:
            raise ValueError(f"unknown duck {duck!r}; expected D1..D4")
        voices[duck] = voice.strip()
    return voices


def main() -> int:
    p = argparse.ArgumentParser(
        description="Generate aligned four-duck play stems via ElevenLabs.")
    p.add_argument("script", nargs="?", type=Path,
                   help="Markdown play script to parse")
    p.add_argument("--out-dir", type=Path, required=False,
                   help="Directory for stems, line clips, and manifest")
    p.add_argument("--prefix", default=None,
                   help="Output file prefix (default: script filename stem)")
    p.add_argument("--gap-ms", type=int, default=GAP_MS,
                   help=f"Silence between lines (default {GAP_MS})")
    p.add_argument("--stability", type=float, default=0.42)
    p.add_argument("--similarity", type=float, default=0.82)
    p.add_argument("--voice", action="append", default=[],
                   help="Override a voice: --voice D1=voice_id")
    p.add_argument("--dry-run", action="store_true",
                   help="Parse and write no audio")
    p.add_argument("--list-voices", action="store_true",
                   help="List ElevenLabs voices and exit")
    args = p.parse_args()

    key = api_key()
    if args.list_voices:
        if not key:
            print("ERROR: ELEVENLABS_API_KEY not found in env/files/keychain",
                  file=sys.stderr)
            return 1
        list_voices(key)
        return 0

    if not args.script or not args.out_dir:
        p.error("script and --out-dir are required unless --list-voices")

    turns = parse_script(args.script)
    voices = parse_voice_overrides(args.voice)
    prefix = args.prefix or args.script.stem

    print(f"parsed {len(turns)} lines")
    for duck in sorted(DUCK_NAMES):
        count = sum(1 for t in turns if t["duck"] == duck)
        print(f"  {duck} {DUCK_NAMES[duck]}: {count} lines, voice={voices[duck]}")

    if args.dry_run:
        return 0
    if not key:
        print("ERROR: ELEVENLABS_API_KEY not found in env/files/keychain",
              file=sys.stderr)
        return 1

    args.out_dir.mkdir(parents=True, exist_ok=True)
    clips_dir = args.out_dir / "line-clips"
    gap = b"\x00\x00" * int(SAMPLE_RATE * args.gap_ms / 1000)
    tracks = {duck: bytearray() for duck in DUCK_NAMES}
    cursor_sec = 0.0

    for turn in turns:
        voice = voices[turn["duck"]]
        pcm = tts_pcm(turn["text"], voice, key, args.stability, args.similarity)
        dur = (len(pcm) // 2) / SAMPLE_RATE
        turn["start_sec"] = round(cursor_sec, 3)
        turn["duration_sec"] = round(dur, 3)
        clip_name = f"{turn['index']:02d}_{turn['duck']}_{turn['speaker'].lower()}.wav"
        write_wav(clips_dir / clip_name, pcm)
        turn["clip"] = f"line-clips/{clip_name}"

        for duck in DUCK_NAMES:
            samples = len(pcm) // 2
            tracks[duck].extend(pcm if duck == turn["duck"] else b"\x00\x00" * samples)
            tracks[duck].extend(gap)
        cursor_sec += dur + args.gap_ms / 1000
        print(f"{turn['index']:02d}/{len(turns):02d} {turn['duck']} "
              f"{turn['speaker']}: {dur:.2f}s")
        time.sleep(0.05)

    stems = {}
    for duck, pcm in tracks.items():
        stem_path = args.out_dir / f"{prefix}_{duck}_{DUCK_NAMES[duck].lower()}.wav"
        write_wav(stem_path, bytes(pcm))
        stems[duck] = stem_path.name

    lens = {len(pcm) for pcm in tracks.values()}
    total_sec = (next(iter(lens)) // 2) / SAMPLE_RATE
    manifest = {
        "source": str(args.script),
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "sample_rate": SAMPLE_RATE,
        "format": "16-bit PCM mono WAV",
        "model": MODEL,
        "gap_ms": args.gap_ms,
        "duck_names": DUCK_NAMES,
        "speaker_to_duck": SPEAKER_TO_DUCK,
        "voices": voices,
        "stems": stems,
        "aligned": len(lens) == 1,
        "total_duration_sec": round(total_sec, 3),
        "turns": turns,
    }
    (args.out_dir / f"{prefix}_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {args.out_dir}")
    print(f"tracks aligned: {'yes' if len(lens) == 1 else 'NO'}")
    print(f"total duration: {total_sec:.2f}s")
    return 0 if len(lens) == 1 else 2


if __name__ == "__main__":
    sys.exit(main())
