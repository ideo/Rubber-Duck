"""WebSocket proxy: duck (LAN, binary PCM) ↔ ElevenAgents (TLS, JSON+b64).

The ESP32-S3 cannot reliably do TLS + JSON + base64 + fragment reassembly at
real-time audio rates without falling behind cadence (see bambu/STATE.md).
This proxy moves that work to a Mac/server. The duck connects to ws://<host>:8088/ws/duck
and exchanges raw int16 LE PCM @ 16 kHz mono in WS binary frames. The proxy
holds the ElevenAgents WS upstream and translates.

Protocol (duck ↔ proxy):
- Binary frame, dock → proxy: raw int16 LE PCM mic audio
- Binary frame, proxy → duck: raw int16 LE PCM agent audio
- Text frame, proxy → duck: JSON control events (interruption, ready, etc.)
- Text frame, duck → proxy: JSON control (currently unused but reserved)
"""
from __future__ import annotations

import asyncio
import base64
import json
import logging
import os
import time
import wave
from pathlib import Path
from typing import Optional

import httpx
import websockets
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger("duck_proxy")

router = APIRouter()

ELEVENLABS_HOST = "api.elevenlabs.io"
SIGNED_URL_PATH = "/v1/convai/conversation/get-signed-url"


async def _fetch_signed_url(api_key: str, agent_id: str) -> str:
    """Get a short-lived wss:// URL for the configured ElevenAgents agent."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        r = await client.get(
            f"https://{ELEVENLABS_HOST}{SIGNED_URL_PATH}",
            params={"agent_id": agent_id},
            headers={"xi-api-key": api_key},
        )
        r.raise_for_status()
        return r.json()["signed_url"]


async def _send_init(upstream: websockets.WebSocketClientProtocol) -> None:
    """ElevenAgents requires a conversation_initiation_client_data message
    before it streams audio. Audio formats are dashboard-only — both must
    be set to pcm_16000 in the agent config.
    """
    await upstream.send(
        json.dumps({
            "type": "conversation_initiation_client_data",
            "conversation_config_override": {
                "agent": {"language": "en"},
            },
        })
    )


async def _duck_to_eleven(duck: WebSocket,
                          upstream: websockets.WebSocketClientProtocol,
                          mic_wav: Optional[wave.Wave_write]) -> None:
    """Pump duck mic frames upstream as user_audio_chunk messages.
    Optionally tee to a local WAV for diagnostics."""
    try:
        while True:
            msg = await duck.receive()
            if msg.get("type") == "websocket.disconnect":
                return
            if "bytes" in msg and msg["bytes"] is not None:
                pcm = msg["bytes"]
                if mic_wav is not None:
                    mic_wav.writeframes(pcm)
                b64 = base64.b64encode(pcm).decode("ascii")
                await upstream.send(json.dumps({"user_audio_chunk": b64}))
            elif "text" in msg and msg["text"]:
                logger.debug("duck text: %s", msg["text"])
    except WebSocketDisconnect:
        return


async def _eleven_to_duck(duck: WebSocket,
                          upstream: websockets.WebSocketClientProtocol,
                          agent_wav: Optional[wave.Wave_write]) -> None:
    """Pump server events back. Audio = binary frame; everything else = JSON text.
    Optionally tee agent audio to a WAV."""
    async for raw in upstream:
        try:
            event = json.loads(raw)
        except json.JSONDecodeError:
            continue
        t = event.get("type", "")

        if t == "audio":
            ae = event.get("audio_event") or {}
            b64 = ae.get("audio_base_64")
            if b64:
                pcm = base64.b64decode(b64)
                if agent_wav is not None:
                    agent_wav.writeframes(pcm)
                await duck.send_bytes(pcm)
        elif t == "ping":
            evt = event.get("ping_event") or {}
            await upstream.send(json.dumps({"type": "pong",
                                            "event_id": evt.get("event_id", 0)}))
        elif t == "interruption":
            await duck.send_text(json.dumps({"type": "interruption"}))
        elif t == "conversation_initiation_metadata":
            await duck.send_text(json.dumps({"type": "ready"}))
        elif t in ("agent_response", "user_transcript"):
            # Useful to log but no action for the duck.
            inner_key = "agent_response_event" if t == "agent_response" else "user_transcription_event"
            text_key = "agent_response" if t == "agent_response" else "user_transcript"
            inner = event.get(inner_key) or {}
            logger.info("[%s] %s", t, inner.get(text_key, ""))


@router.websocket("/ws/duck")
async def ws_duck_endpoint(duck: WebSocket) -> None:
    await duck.accept()
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    agent_id = os.environ.get("BAMBU_DUCK_AGENT_ID")
    if not api_key or not agent_id:
        logger.error("ELEVENLABS_API_KEY or BAMBU_DUCK_AGENT_ID not set")
        await duck.close(code=1011)
        return

    try:
        signed = await _fetch_signed_url(api_key, agent_id)
    except Exception as e:
        logger.error("signed-url fetch failed: %s", e)
        await duck.close(code=1011)
        return

    # Open per-session WAV files for diagnostic playback. Saved next to relay.
    rec_dir = Path(__file__).parent / "recordings"
    rec_dir.mkdir(exist_ok=True)
    ts = time.strftime("%Y%m%d-%H%M%S")
    mic_path = rec_dir / f"{ts}_mic.wav"
    agent_path = rec_dir / f"{ts}_agent.wav"
    mic_wav = wave.open(str(mic_path), "wb")
    mic_wav.setnchannels(1); mic_wav.setsampwidth(2); mic_wav.setframerate(16000)
    agent_wav = wave.open(str(agent_path), "wb")
    agent_wav.setnchannels(1); agent_wav.setsampwidth(2); agent_wav.setframerate(16000)
    logger.info("recording mic → %s and agent → %s", mic_path.name, agent_path.name)

    logger.info("duck connected, opening upstream WS")
    try:
        async with websockets.connect(signed, max_size=None) as upstream:
            await _send_init(upstream)
            up = asyncio.create_task(_duck_to_eleven(duck, upstream, mic_wav))
            down = asyncio.create_task(_eleven_to_duck(duck, upstream, agent_wav))
            done, pending = await asyncio.wait({up, down}, return_when=asyncio.FIRST_COMPLETED)
            for task in pending:
                task.cancel()
    except Exception as e:
        logger.exception("upstream session error: %s", e)
    finally:
        mic_wav.close(); agent_wav.close()
        try:
            await duck.close()
        except Exception:
            pass
        logger.info("duck disconnected; recordings saved")
