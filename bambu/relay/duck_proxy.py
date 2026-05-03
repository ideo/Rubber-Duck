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
# Live upstream ElevenAgents sessions — when a printer event fires and one of
# these is open, we inject the notice as a user_message into the running
# conversation instead of opening a new session. The agent naturally pivots
# (a fresh user_message ends the current agent turn), which is exactly the
# "interrupt" UX. /ws/notify only triggers a new session when nothing is live.
_active_upstreams: set = set()
_main_loop: Optional[asyncio.AbstractEventLoop] = None  # captured at startup


def _friendly_subtask(name: Optional[str]) -> str:
    """Turn the Bambu-provided subtask_name into something speakable.

    Bambu's `subtask_name` is sometimes the slicer profile string (e.g.
    '0.16mm layer, 2 walls, 15% infill') instead of a print's friendly
    name. Heuristic detects the profile shape and falls back to "your
    print" — sounds natural read aloud. By design: real friendly names
    only live in Bambu's cloud metadata, which requires the cloud API
    (tracked in #31). Until then, the heuristic is the right answer."""
    if not name:
        return "your print"
    low = name.lower()
    if "layer" in low and ("walls" in low or "infill" in low):
        return "your print"
    return name


async def _broadcast_notify(payload: str) -> None:
    dead = []
    for ws in list(_notify_clients):
        try:
            await ws.send_text(payload)
        except Exception:
            dead.append(ws)
    for ws in dead:
        _notify_clients.discard(ws)


# Per-upstream "has this session already announced a printer event?" flag.
# Drives notice-vs-update phrasing: the first event of a session uses
# "Printer notice:" so the agent announces fresh; subsequent events in the
# same session use "Printer update:" so the agent treats them as in-context
# continuations and weaves them into the conversation naturally rather than
# re-announcing from scratch.
_session_announced: set[int] = set()


async def _inject_into_active_sessions(event_type: str, friendly: Optional[str],
                                        printer_name: Optional[str] = None) -> int:
    """Push a printer event into any live upstream(s) immediately as a
    user_message. Returns the number of sessions injected into.

    A user_message landing mid-utterance cleanly interrupts the agent's
    current turn — same effect as a hard session interrupt, no audio glitch.
    The agent's response then naturally flows into addressing the new event."""
    if not _active_upstreams:
        return 0
    n = 0
    for upstream in list(_active_upstreams):
        key = id(upstream)
        header = "Printer update" if key in _session_announced else "Printer notice"
        text = _printer_text_for(event_type, friendly, header, printer_name)
        try:
            await _send_user_message(upstream, text)
            _session_announced.add(key)
            logger.info("notify injected: %s", text)
            n += 1
        except Exception as e:
            logger.warning("inject failed (upstream gone?): %s", e)
            _active_upstreams.discard(upstream)
            _session_announced.discard(key)
    return n


async def _dispatch_event(event_type: str, friendly: Optional[str],
                            printer_name: Optional[str] = None) -> None:
    """Route a printer event to either the live session (inject) or the
    notify channel (broadcast → chip opens new session).

    Two paths by design — they aren't redundant. Inject reuses an open
    upstream so the agent pivots mid-conversation with no audio glitch.
    Broadcast is the cold-start: the chip is idle, /ws/notify wakes it,
    chip dials /ws/duck?event=...&subtask=..., and ws_duck_endpoint
    sends the opening user_message right after init metadata."""
    injected = await _inject_into_active_sessions(event_type, friendly, printer_name)
    if injected:
        return
    # Note: printer_name not propagated to chip via /ws/notify yet —
    # chip's JSON parser only extracts event + subtask. The session-start
    # path (ws_duck_endpoint) reads printer_name from state directly.
    # Multi-printer (#41) will require chip to forward the printer_serial
    # from the notify push so the relay knows WHICH printer to read from.
    payload = json.dumps(
        {"type": "notify", "event": event_type, "subtask": friendly},
        ensure_ascii=False,
    )
    await _broadcast_notify(payload)
    logger.info("notify broadcast (no active session): %s — %s%s",
                event_type, friendly,
                f" ({printer_name})" if printer_name else "")


def fire_notification(event: dict) -> None:
    """MQTT-thread entry point. Schedules _dispatch_event onto the asyncio
    loop captured at startup. Wire format on /ws/notify when broadcasting:
    {"type":"notify","event":"...","subtask":"..."} — chip extracts both."""
    if _main_loop is None:
        return
    asyncio.run_coroutine_threadsafe(
        _dispatch_event(
            event.get("type"),
            _friendly_subtask(event.get("subtask")),
            event.get("printer_name") or None,
        ),
        _main_loop,
    )


_bambu_state = None  # captured for ws_duck_endpoint's notify-session path


def register_bambu_listener(state) -> None:
    """Wire the bambu_state event listener to fan out via WS. Capture the
    running asyncio loop so the MQTT-thread listener can dispatch onto it.
    Also stash the state object so the /ws/duck endpoint can read its
    printer_name when handling notify-triggered session opens (the chip
    URL params don't carry printer_name yet — see the comment in
    _dispatch_event)."""
    global _main_loop, _bambu_state
    _main_loop = asyncio.get_running_loop()
    _bambu_state = state
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
                     suppress_first_message: bool = False) -> None:
    """ElevenAgents init. For notification-triggered sessions we suppress
    the agent's default greeting (so it doesn't say "Yeah?" then pivot)
    and inject a user_message right after init that tells the agent what
    the printer just did — agent improvises the announcement in voice.

    Suppressing first_message requires the agent's Security tab to have
    first_message override enabled.
    """
    payload = {"type": "conversation_initiation_client_data"}
    if suppress_first_message:
        payload["conversation_config_override"] = {
            "agent": {"first_message": ""}
        }
    await upstream.send(json.dumps(payload))


def _printer_text_for(event_type: str, subtask: Optional[str], header: str,
                       printer_name: Optional[str] = None) -> str:
    """Build the user_message body for a printer event. Caller passes header:
      'Printer notice' — first-in-session, agent announces fresh.
      'Printer update' — subsequent events in same session, agent treats
        them as in-context follow-ups and weaves them into the conversation
        rather than re-announcing from scratch.
    `printer_name` (when present) is the friendly name from Bambu cloud's
    device list so the agent can disambiguate which printer fired the
    event ("Work Bambu just started" vs "your printer just started").
    Empty string / None falls back to a generic phrasing — same shape as
    before this change, so LAN-mode installs are unchanged."""
    name = subtask or "your print"
    pname = (printer_name or "").strip()
    p = pname if pname else "the printer"
    if event_type == "start":
        return f"{header}: {p} just started a print, file is {name}."
    if event_type == "finish":
        return f"{header}: {p} just finished a print of {name}."
    if event_type == "failed":
        return f"{header}: print of {name} failed on {p}."
    if event_type == "pause":
        return f"{header}: print of {name} paused mid-job on {p}."
    if event_type == "resume":
        return f"{header}: print of {name} resumed on {p}."
    if event_type == "hms":
        return f"{header}: {p} is flagging an error."
    return f"{header}: event {event_type} on {p}, file {name}."


async def _send_user_message(upstream: websockets.WebSocketClientProtocol,
                              text: str) -> None:
    """Push text into the conversation as if the user spoke it. Agent will
    respond naturally — no override on its phrasing."""
    await upstream.send(json.dumps({"type": "user_message", "text": text},
                                    ensure_ascii=False))


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
    """Keep ElevenLabs' turn-timing clock fed when the chip is mute.

    By design — not a workaround. ElevenLabs Agents protocol expects a
    constant stream of user_audio_chunk; if it stops, the session ends
    as 'user disconnected / turn timed out'. The chip mutes mic during
    agent speech (acoustic-feedback mitigation), so SOMEONE has to keep
    pushing audio. We send 80ms of pre-encoded zero PCM whenever real
    audio hasn't arrived in the last 80ms. Mirrors the official SDK."""
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
    # When the chip opens a notification-triggered session it appends
    # ?event=<type>&subtask=<name>. Button-press sessions arrive bare.
    event_type = duck.query_params.get("event") or None
    subtask = duck.query_params.get("subtask") or None
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

    # WAV recording is opt-in (`RECORD=1`). Was always-on while we were
    # debugging audio cadence/quality on the chip; hardware moved past those
    # issues. Flip it back on if you change mic/amp wiring or chase a new
    # cadence regression — files land in ./recordings/.
    mic_wav = agent_wav = None
    if os.environ.get("RECORD") == "1":
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
    upstream_ref = None
    try:
        async with websockets.connect(signed, max_size=None) as upstream:
            upstream_ref = upstream
            _active_upstreams.add(upstream)
            # When opened from a notification, suppress the agent's default
            # greeting and immediately inject a "Printer notice: ..."
            # user_message so the LLM phrases the announcement in its own
            # voice. Otherwise (button press) let the agent open normally.
            await _send_init(upstream, suppress_first_message=bool(event_type))
            if event_type:
                # Pull printer_name from state — chip's URL params don't
                # carry it (see _dispatch_event comment about #41).
                pname = _bambu_state.printer_name if _bambu_state else None
                notice = _printer_text_for(event_type, subtask, "Printer notice", pname)
                logger.info("session opening from notify: event=%s subtask=%r printer=%r",
                            event_type, subtask, pname)
                await _send_user_message(upstream, notice)
                # Mark first announcement done — any further events that
                # arrive during this session use "Printer update:" phrasing.
                _session_announced.add(id(upstream))
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
        if upstream_ref is not None:
            _active_upstreams.discard(upstream_ref)
            _session_announced.discard(id(upstream_ref))
        if mic_wav is not None:
            mic_wav.close()
        if agent_wav is not None:
            agent_wav.close()
        try:
            await duck.close()
        except Exception:
            pass
        logger.info("duck disconnected")


# ---------------------------------------------------------------------------
# Notification channel — long-lived WS the duck holds at boot.
# ---------------------------------------------------------------------------

_bambu_login_handler = None  # set by main.py at startup so we don't import-cycle


def register_bambu_login_handler(fn):
    """main.py wires its bambu_login_endpoint logic in here so /ws/notify
    can dispatch chip-originated `bambu_login` messages to the same code
    path as the HTTP endpoint."""
    global _bambu_login_handler
    _bambu_login_handler = fn


@router.websocket("/ws/notify")
async def ws_notify_endpoint(duck: WebSocket) -> None:
    await duck.accept()
    _notify_clients.add(duck)
    logger.info("notify client connected (%d total)", len(_notify_clients))
    try:
        while True:
            msg = await duck.receive()
            if msg.get("type") == "websocket.disconnect":
                break
            # Chip-originated text messages — the captive-portal APSTA
            # wizard sends `bambu_login` here so we handle the cloud
            # login on the chip's behalf (chip can't do TLS to ngrok's
            # edge reliably; relay's Python httpx works perfectly).
            text = msg.get("text")
            if not text:
                continue
            try:
                payload = json.loads(text)
            except json.JSONDecodeError:
                logger.warning("notify rx non-JSON: %s", text[:100])
                continue
            mtype = payload.get("type")
            if mtype == "bambu_login" and _bambu_login_handler is not None:
                # Run the handler off the main loop — it's an async fn
                # that calls Bambu's API + reconfigures MQTT. Reply via
                # the same WebSocket with the result so the chip wizard
                # can advance its state machine.
                logger.info("notify rx bambu_login (email=%s)",
                            payload.get("email", "?"))
                try:
                    result = await _bambu_login_handler(payload)
                    reply = {"type": "bambu_login_result", "ok": True, **result}
                except Exception as e:
                    code = "login_failed"
                    msg_text = str(e)
                    # Pull through structured fields if HTTPException-shaped
                    detail = getattr(e, "detail", None)
                    if isinstance(detail, dict):
                        code = detail.get("code", code)
                        msg_text = detail.get("message", msg_text)
                    reply = {"type": "bambu_login_result", "ok": False,
                             "code": code, "message": msg_text}
                    logger.warning("bambu_login failed: %s", reply)
                await duck.send_text(json.dumps(reply, ensure_ascii=False))
                continue
            # Unknown message types — silently ignore.
    except WebSocketDisconnect:
        pass
    finally:
        _notify_clients.discard(duck)
        logger.info("notify client disconnected (%d remaining)", len(_notify_clients))


@router.post("/admin/test_notification")
async def admin_test_notification(event: str = "finish", subtask: str = "TestPrint"):
    """Manual trigger for testing the notification path without waiting for
    a real print to finish. Stamps printer_name from the live state so the
    synthetic event matches the shape of a real bambu_state._fire event."""
    pname = _bambu_state.printer_name if _bambu_state else ""
    fire_notification({"type": event, "subtask": subtask, "printer_name": pname})
    return {
        "ok": True, "event": event, "subtask": subtask,
        "printer_name": pname,
        "clients_notified": len(_notify_clients),
    }
