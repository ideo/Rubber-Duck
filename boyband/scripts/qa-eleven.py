#!/usr/bin/env python3
"""Generate one live Q&A panel answer and ElevenLabs line clips.

Input: an audience question.
Output: JSON with [{duck, speaker, text, path, duration_sec}, ...].

This intentionally keeps the live-show path simple: ElevenLabs Agents writes
the short panel script, then normal ElevenLabs TTS renders each duck line into
the same 16 kHz PCM WAV format Stage already knows how to play.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import os
import re
import subprocess
import sys
import time
import wave
from pathlib import Path

import httpx
import websockets

SAMPLE_RATE = 16000
OUTPUT_FORMAT = "pcm_16000"
TTS_MODEL = "eleven_flash_v2_5"
AGENT_TTS_MODEL = "eleven_flash_v2"
AGENT_LLM = "qwen3-30b-a3b"
PROMPT_VERSION = "2026-06-02-grounded-router-v2-no-spoken-ids"

ROOT = Path(__file__).resolve().parents[2]
LOCAL_AGENT_FILE = ROOT / "boyband" / "qa-agent.local.json"
OUT_DIR = ROOT / "boyband" / "qa-cache"

DUCKS = {
    "D1": {
        "speaker": "Classic",
        "voice": "ygoBNrnmTEdu5NtDTmAY",
        "persona": (
            "the frontman: bright, charismatic, myth-making, keeps the band moving, "
            "best for the big premise, boy-band framing, archetype-as-interface, and closing flourishes"
        ),
    },
    "D2": {
        "speaker": "Mallard",
        "voice": "U5UjeJMsOvyhYhXfZdvZ",
        "persona": (
            "the wild one: older, skeptical, bar-fight philosopher, loving but disappointed, "
            "best for critique, weak prompts, reliability, Lot Bot, permissions, failures, and hard truths"
        ),
    },
    "D3": {
        "speaker": "Pintail",
        "voice": "TX3LPaxmHKxFdv7VOQHJ",
        "persona": (
            "the mysterious one: calm, precise, ethics-and-systems duck, maybe has a motorcycle, "
            "best for anthropomorphism, stereotypes, the AI-character stack, Moby Duck, and compressed theory"
        ),
    },
    "D4": {
        "speaker": "Pekin",
        "voice": "Xb3zeLrTi6F4ziIcXdwk",
        "persona": (
            "the understated one: gentle, emotionally intelligent, brave enough to tell the truth softly, "
            "best for companionship, loneliness, care, human meaning, and plain-language explanations"
        ),
    },
}

GROUNDING = """
Duck Duck Duck project grounding:
- Duck Duck Duck is rubber duck debugging, but the duck talks back.
- It is a physical or desktop rubber duck companion for Claude Code sessions.
- It listens to coding work through hooks, evaluates prompts and responses, forms opinions, and reacts.
- It scores creativity, soundness, ambition, elegance, and risk, then maps those scores to voice, face, color, motion, servo/speaker behavior, and hardware reactions.
- It can handle Claude permission requests by asking out loud and accepting spoken yes/no/always-allow responses.
- It can support wake-word commands: say "ducky" and speak to the coding session; Relay mode can pipe voice commands into Claude Code through tmux.
- Default intelligence is local/on-device where possible; optional Claude Haiku or Gemini Flash can score in the cloud.
- Hardware includes ESP32-S3 paths with serial audio, servo, speaker, mic, LEDs, and USB-C for power/data/audio. A desktop-only widget can use the laptop mic and speakers.
- The public site frames the duck as embodied AI: most AI lives in a chat window, but this duck sits next to you, moves, reacts, and changes how people relate to the tool.
- The build happened fast at IDEO: a cross-disciplinary team built the first public Duck Duck Duck release in roughly three weeks, using AI tools as part of the process.

Performance/theory grounding:
- The stage ducks are not mascots and not Claude. They are a character system: a third presence beside the human and the tool.
- The larger argument: character is interface, not garnish. Personality changes how people ask for help, accept critique, keep going, and feel less alone.
- Anthropomorphism is not just user error; people relate socially to AI whether designers approve or not, and that can help them use tools better.
- Strong character design has power and risk. A stereotype can compress behavior quickly, but strong character choices need strong reasons.
- The boy-band frame makes broad archetypes legible and accountable: frontman, wild one, mysterious one, understated one.
- Two lineages feed the duck: companionship (encouragement, empowerment, creative confidence) and personality-as-social-permission (judgment, denial, social buffering, emotional labor).
- Lot Bot is an ancestor for Mallard: a parking Slack bot that carried awkward scarcity and refusal so humans did not have to.
- Moby Duck adds depth: service is not emptiness; there can be dignity in witnessing, helping, and checking human pride.
- Desired audience feeling: these ducks are funny; character design is serious interface design; AI work can feel less lonely; the duck is not a gimmick, it has a role.

Duck routing guide:
- Classic answers when the question is about the overall premise, why ducks, why a boy band, archetypes, demos, launch framing, or what the audience should remember.
- Mallard answers when the question is about critique, bad prompts, reliability, debugging, failures, permissions, Lot Bot, boundaries, or whether the duck is too mean.
- Pintail answers when the question is about ethics, anthropomorphism, stereotypes, AI personality layers, Moby Duck, theory, or how character can be powerful and risky.
- Pekin answers when the question is about companionship, loneliness, care, accessibility, emotional labor, why this matters to people, or a simple plain-language explanation.
""".strip()


def keychain(service: str) -> str | None:
    try:
        r = subprocess.run(
            ["security", "find-generic-password", "-s", service, "-w"],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    value = r.stdout.strip()
    return value if r.returncode == 0 and value else None


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY") or keychain("com.duckduckduck.boyband.elevenlabs")
    if not key:
        raise RuntimeError("missing ElevenLabs API key in env or Keychain")
    return key


def context_prompt() -> str:
    context_files = [
        ROOT / "boyband" / "README.md",
        ROOT / "boyband" / "docs" / "orchestrator.md",
        ROOT / "boyband" / "docs" / "stage-protocol.md",
        ROOT / "boyband" / "docs" / "duck-id-mapping.md",
    ]
    chunks = []
    for path in context_files:
        try:
            text = path.read_text()
        except OSError:
            continue
        chunks.append(f"## {path.relative_to(ROOT)}\n{text[:5000]}")
    return GROUNDING + "\n\n" + "\n\n".join(chunks)


def agent_prompt() -> str:
    duck_lines = "\n".join(
        f"- {meta['speaker']} (routing value {duck}): {meta['persona']}"
        for duck, meta in DUCKS.items()
    )
    return f"""
You are writing live audience Q&A answers for Duck Duck Duck's rubber-duck
boy band performance.

The ducks are physical rubber ducks on stage. Write a short answer to the
audience question using only the most relevant duck or ducks. This is not a
round-robin panel. Usually use one duck. Use two ducks only when a useful
contrast makes the answer better.

The ducks:
{duck_lines}

Facts/context about the project:
{context_prompt()}

Output ONLY compact JSON with this exact shape:
{{"lines":[{{"duck":"D1","text":"..."}}]}}

Rules:
- Use duck IDs D1, D2, D3, D4 only in the JSON "duck" field.
- Never say D1, D2, D3, D4, "dee one", "dee two", "dee three", or "dee four" in the spoken text.
- In spoken text, use character names only: Classic, Mallard, Pintail, Pekin.
- Pick the best duck(s) for the question from the routing guide. Do not make everyone answer.
- Return 1 or 2 lines total. Never return more than 2 lines.
- Each text line is one or two spoken sentences, 8 to 26 words.
- Do not include markdown, stage directions, speaker labels, or sound effects.
- Answer the question with real project context when possible.
- If you are unsure, say so in character instead of inventing details.
- Keep the total answer under 45 spoken words.
""".strip()


def sanitize_spoken_text(text: str) -> str:
    replacements = {
        "1": "Classic",
        "2": "Mallard",
        "3": "Pintail",
        "4": "Pekin",
    }

    def replace_numeric(match: re.Match) -> str:
        return replacements[match.group(1)]

    cleaned = re.sub(r"(?<![A-Za-z0-9])D[\s-]*([1-4])(?![A-Za-z0-9])", replace_numeric, text, flags=re.I)

    word_numbers = {
        "one": "Classic",
        "two": "Mallard",
        "three": "Pintail",
        "four": "Pekin",
    }
    for word, speaker in word_numbers.items():
        cleaned = re.sub(rf"\bdee[\s-]+{word}\b", speaker, cleaned, flags=re.I)
    return cleaned


def load_agent_id() -> str | None:
    if not LOCAL_AGENT_FILE.exists():
        return None
    try:
        data = json.loads(LOCAL_AGENT_FILE.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    if data.get("prompt_version") != PROMPT_VERSION:
        return None
    return data.get("agent_id")


def save_agent_id(agent_id: str) -> None:
    LOCAL_AGENT_FILE.write_text(json.dumps({
        "agent_id": agent_id,
        "prompt_version": PROMPT_VERSION,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }, indent=2) + "\n")


def create_agent(key: str) -> str:
    body = {
        "name": "Duck Duck Duck Boy Band Q&A",
        "conversation_config": {
            "agent": {
                "first_message": "",
                "language": "en",
                "prompt": {
                    "prompt": agent_prompt(),
                    "llm": AGENT_LLM,
                    "temperature": 0.75,
                    "max_tokens": 700,
                    "tools": [],
                    "knowledge_base": [],
                    "mcp_server_ids": [],
                    "native_mcp_server_ids": [],
                },
            },
            "tts": {
                "model_id": AGENT_TTS_MODEL,
                "voice_id": DUCKS["D1"]["voice"],
                "stability": 0.48,
                "similarity_boost": 0.82,
            },
            "asr": {
                "quality": "high",
                "provider": "elevenlabs",
                "user_input_audio_format": "pcm_16000",
            },
            "turn": {
                "turn_timeout": 7,
                "mode": "silence",
                "silence_end_call_timeout": -1,
            },
            "conversation": {
                "max_duration_seconds": 120,
                "client_events": ["agent_response", "ping", "conversation_initiation_metadata"],
            },
        },
        "platform_settings": {
            "auth": {"enable_auth": False, "allowlist": []},
            "evaluation": {"criteria": []},
        },
        "tags": ["duck-duck-duck", "boy-band", "qa"],
    }
    r = httpx.post(
        "https://api.elevenlabs.io/v1/convai/agents/create",
        headers={"xi-api-key": key, "content-type": "application/json"},
        json=body,
        timeout=60,
    )
    if r.status_code != 200:
        raise RuntimeError(f"create agent failed {r.status_code}: {r.text[:800]}")
    agent_id = r.json()["agent_id"]
    save_agent_id(agent_id)
    return agent_id


def signed_url(key: str, agent_id: str) -> str:
    r = httpx.get(
        "https://api.elevenlabs.io/v1/convai/conversation/get-signed-url",
        headers={"xi-api-key": key},
        params={"agent_id": agent_id},
        timeout=20,
    )
    if r.status_code != 200:
        raise RuntimeError(f"signed url failed {r.status_code}: {r.text[:500]}")
    return r.json()["signed_url"]


def extract_json(text: str) -> dict:
    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{.*\}", text, flags=re.S)
    if not match:
        raise RuntimeError(f"agent did not return JSON: {text[:500]}")
    return json.loads(match.group(0))


async def ask_agent(key: str, agent_id: str, question: str) -> list[dict]:
    url = signed_url(key, agent_id)
    async with websockets.connect(url, max_size=None) as ws:
        await ws.send(json.dumps({
            "type": "conversation_initiation_client_data",
            "conversation_config_override": {"agent": {"first_message": ""}},
        }))
        await ws.send(json.dumps({
            "type": "user_message",
            "text": f"Audience question: {question}",
        }, ensure_ascii=False))

        parts: list[str] = []
        deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            raw = await asyncio.wait_for(ws.recv(), timeout=max(0.1, deadline - time.monotonic()))
            event = json.loads(raw)
            t = event.get("type")
            if t == "ping":
                ping = event.get("ping_event") or {}
                await ws.send(json.dumps({"type": "pong", "event_id": ping.get("event_id", 0)}))
            elif t == "agent_response":
                inner = event.get("agent_response_event") or {}
                text = inner.get("agent_response") or ""
                if text:
                    parts.append(text)
                    break
        if not parts:
            raise RuntimeError("agent timed out without a text response")

    data = extract_json("\n".join(parts))
    lines = data.get("lines") or []
    clean = []
    for item in lines:
        duck = str(item.get("duck", "")).upper()
        text = sanitize_spoken_text(str(item.get("text", "")).strip())
        if duck in DUCKS and text:
            clean.append({"duck": duck, "speaker": DUCKS[duck]["speaker"], "text": text})
    if not clean:
        raise RuntimeError(f"agent returned no usable lines: {data}")
    return clean[:2]


def tts_pcm(key: str, duck: str, text: str) -> bytes:
    r = httpx.post(
        f"https://api.elevenlabs.io/v1/text-to-speech/{DUCKS[duck]['voice']}",
        headers={
            "xi-api-key": key,
            "accept": "audio/pcm",
            "content-type": "application/json",
        },
        params={"output_format": OUTPUT_FORMAT},
        json={
            "text": text,
            "model_id": TTS_MODEL,
            "voice_settings": {
                "stability": 0.44,
                "similarity_boost": 0.82,
            },
        },
        timeout=120,
    )
    if r.status_code != 200:
        raise RuntimeError(f"TTS failed {r.status_code} for {duck}: {r.text[:500]}")
    pcm = r.content
    return pcm[:-1] if len(pcm) % 2 else pcm


def write_wav(path: Path, pcm: bytes) -> float:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(pcm)
    return (len(pcm) // 2) / SAMPLE_RATE


async def run(question: str) -> dict:
    key = api_key()
    agent_id = load_agent_id() or create_agent(key)
    lines = await ask_agent(key, agent_id, question)
    ts = time.strftime("%Y%m%d-%H%M%S")
    slug = re.sub(r"[^a-z0-9]+", "-", question.lower()).strip("-")[:32] or "question"
    out = OUT_DIR / f"{ts}-{slug}"
    rendered = []
    for idx, line in enumerate(lines, start=1):
        pcm = tts_pcm(key, line["duck"], line["text"])
        path = out / f"{idx:02d}_{line['duck']}_{line['speaker'].lower()}.wav"
        duration = write_wav(path, pcm)
        rendered.append({**line, "path": str(path), "duration_sec": round(duration, 3)})
    return {"question": question, "agent_id": agent_id, "lines": rendered}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("question")
    args = parser.parse_args()
    try:
        result = asyncio.run(run(args.question))
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
