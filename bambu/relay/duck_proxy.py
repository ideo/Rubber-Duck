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
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query

logger = logging.getLogger("duck_proxy")
logger.setLevel(logging.INFO)
# Ensure messages reach uvicorn's stdout — without this, default root level
# is WARNING and our INFO transcripts never appear in the log.
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:duck_proxy: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False

router = APIRouter()

# Persistent notification clients — every duck holds a /ws/notify connection
# and we push events here when the printer state transitions.
_notify_clients: set[WebSocket] = set()
_main_loop: Optional[asyncio.AbstractEventLoop] = None  # captured at startup


def _friendly_subtask(name: Optional[str]) -> str:
    """Turn the Bambu-provided subtask_name into something the agent can
    speak naturally. Bambu populates this with the slicer profile name
    (e.g. '0.16mm layer, 2 walls, 15% infill') when the gcode came from
    Studio's send-to-printer flow — sounds awkward read aloud. Fall back
    to a generic phrase in that case. Friendly names live in Bambu's
    cloud metadata; getting them requires the cloud API (see #31)."""
    if not name:
        return "your print"
    low = name.lower()
    if "layer" in low and ("walls" in low or "infill" in low):
        return "your print"
    return name


def _headline_for(event: dict) -> str:
    """Build the natural-language headline the agent should lead with."""
    t = event.get("type", "")
    subtask = _friendly_subtask(event.get("subtask"))
    if t == "start":
        return f"Nice — got your print started on {subtask}. I'll let you know when it's done."
    if t == "finish":
        return f"Hey, your {subtask} just finished printing!"
    if t == "failed":
        return f"Heads up, the {subtask} print failed. Want to take a look?"
    if t == "pause":
        return f"The print's paused — looks like {subtask} hit a snag. Want me to check?"
    if t == "resume":
        return f"Back at it — {subtask} is printing again."
    if t == "hms":
        return "The printer's flagging a problem. Want me to check what it says?"
    return f"Printer event: {t}"


async def _broadcast_notify(payload: str) -> None:
    dead = []
    for ws in list(_notify_clients):
        try:
            await ws.send_text(payload)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _notify_clients.discard(ws)


def fire_notification(event: dict) -> None:
    """Push an event to all connected /ws/notify clients. Safe from MQTT thread."""
    if _main_loop is None:
        return
    headline = _headline_for(event)
    payload = json.dumps({"type": "notify", "event": event.get("type"), "headline": headline})
    asyncio.run_coroutine_threadsafe(_broadcast_notify(payload), _main_loop)
    logger.info("notify fired: %s — %s", event.get("type"), headline)


def register_bambu_listener(state) -> None:
    """Wire the bambu_state event listener to fan out via WS. Capture the
    asyncio loop so the MQTT-thread listener can dispatch onto it."""
    global _main_loop
    _main_loop = asyncio.get_event_loop()
    state.add_listener(fire_notification)

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


async def _send_init(upstream: websockets.WebSocketClientProtocol,
                     first_message: Optional[str] = None) -> None:
    """ElevenAgents requires a conversation_initiation_client_data message
    before it streams audio. Audio formats are dashboard-only — both must
    be set to pcm_16000 in the agent config.

    For notification-triggered sessions we override `first_message` so the
    agent leads with the headline instead of its default greeting. The
    agent's **Security tab** must have `first_message` override enabled in
    the dashboard for this to work.
    """
    payload = {"type": "conversation_initiation_client_data"}
    if first_message:
        payload["conversation_config_override"] = {
            "agent": {"first_message": first_message}
        }
    await upstream.send(json.dumps(payload))


# 80ms of int16 silence at 16kHz = 1280 samples * 2 bytes = 2560 bytes.
# Pre-encoded to avoid recomputing base64 each tick.
_SILENCE_80MS_B64 = base64.b64encode(bytes(2560)).decode("ascii")


async def _duck_to_eleven(duck: WebSocket,
                          upstream: websockets.WebSocketClientProtocol,
                          mic_wav: Optional[wave.Wave_write],
                          last_sent: list) -> None:
    """Pump duck mic frames upstream as user_audio_chunk messages.
    Optionally tee to a local WAV for diagnostics. Updates last_sent[0]
    each time real audio is forwarded so the silence pump knows to back off.
    """
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
                try:
                    await upstream.send(json.dumps({"user_audio_chunk": b64}))
                    last_sent[0] = time.time()
                except websockets.ConnectionClosed:
                    return  # upstream gone — let outer task wait fall through
            elif "text" in msg and msg["text"]:
                logger.debug("duck text: %s", msg["text"])
    except WebSocketDisconnect:
        return


async def _silence_pump(upstream: websockets.WebSocketClientProtocol,
                        last_sent: list) -> None:
    """When the duck stops sending mic frames (because firmware muted itself
    while the agent talks), ElevenLabs sees zero user_audio_chunk traffic
    and ends the session as 'user disconnected / turn timed out'. Send 80ms
    of silence whenever real audio hasn't arrived in the last 80ms — keeps
    the server's turn-timing clock happy without triggering self-transcription.
    Mirrors what the official SDK does."""
    try:
        while True:
            await asyncio.sleep(0.08)
            if time.time() - last_sent[0] > 0.075:  # ~80ms with a tiny margin
                await upstream.send(json.dumps({"user_audio_chunk": _SILENCE_80MS_B64}))
                last_sent[0] = time.time()
    except (websockets.ConnectionClosed, asyncio.CancelledError):
        return


async def _eleven_to_duck(duck: WebSocket,
                          upstream: websockets.WebSocketClientProtocol,
                          agent_wav: Optional[wave.Wave_write]) -> None:
    """Pump server events back. Audio = binary frame; everything else = JSON text.
    Optionally tee agent audio to a WAV. Exits cleanly on connection close."""
    try:
        async for raw in upstream:
            try:
                event = json.loads(raw)
            except json.JSONDecodeError:
                logger.warning("upstream non-JSON: %s", str(raw)[:200])
                continue
            t = event.get("type", "")
            if t and t not in ("audio","ping","vad_score","internal_tentative_agent_response"):
                logger.info("upstream event: %s", t)

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
                inner_key = "agent_response_event" if t == "agent_response" else "user_transcription_event"
                text_key = "agent_response" if t == "agent_response" else "user_transcript"
                inner = event.get(inner_key) or {}
                logger.info("[%s] %s", t, inner.get(text_key, ""))
    except (websockets.ConnectionClosed, asyncio.CancelledError):
        return


@router.websocket("/ws/duck")
async def ws_duck_endpoint(duck: WebSocket) -> None:
    # FastAPI's Query() doesn't work on WebSocket endpoints — read directly.
    first_message = duck.query_params.get("first_message") or None
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
            await _send_init(upstream, first_message=first_message)
            if first_message:
                logger.info("session opening with first_message=%r", first_message)
            last_sent = [time.time()]
            up = asyncio.create_task(_duck_to_eleven(duck, upstream, mic_wav, last_sent))
            down = asyncio.create_task(_eleven_to_duck(duck, upstream, agent_wav))
            silence = asyncio.create_task(_silence_pump(upstream, last_sent))
            done, pending = await asyncio.wait({up, down, silence}, return_when=asyncio.FIRST_COMPLETED)
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


# ---------------------------------------------------------------------------
# Notification channel — long-lived WS the duck holds at boot.
# ---------------------------------------------------------------------------

@router.websocket("/ws/notify")
async def ws_notify_endpoint(duck: WebSocket) -> None:
    await duck.accept()
    _notify_clients.add(duck)
    logger.info("notify client connected (%d total)", len(_notify_clients))
    try:
        # Keep alive — receive nothing meaningful (the duck only listens here).
        while True:
            msg = await duck.receive()
            if msg.get("type") == "websocket.disconnect":
                break
    except WebSocketDisconnect:
        pass
    finally:
        _notify_clients.discard(duck)
        logger.info("notify client disconnected (%d remaining)", len(_notify_clients))


@router.post("/admin/test_notification")
async def admin_test_notification(event: str = "finish", subtask: str = "TestPrint"):
    """Manual trigger for testing the notification path without waiting for
    a real print to finish. Fires the same listener as a real Bambu event.
    Example: curl -X POST 'http://127.0.0.1:8088/admin/test_notification?event=finish&subtask=TestPrint'
    """
    fire_notification({"type": event, "subtask": subtask})
    return {"ok": True, "event": event, "subtask": subtask, "clients_notified": len(_notify_clients)}
