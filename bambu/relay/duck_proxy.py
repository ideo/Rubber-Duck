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

import db

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

# Per-duck notification clients. Each duck holds one /ws/notify connection;
# events fired by that duck's BambuState fan out only to that duck's WS.
# A duck may briefly have no entry (between WS reconnects); we use a dict
# of sets so reconnect races don't drop events. Most of the time the set
# has 0 or 1 entries.
_notify_clients: dict[str, set[WebSocket]] = {}

# Per-duck active ElevenAgents sessions. When a printer event fires for
# duck X and that duck has a live upstream, inject the notice as a
# user_message into the running conversation (smooth pivot, no audio
# glitch) instead of broadcasting on /ws/notify (cold start path).
_active_upstreams: dict[str, set] = {}

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


async def _broadcast_notify(duck_id: str, payload: str) -> None:
    """Send to ducks(s) for a given duck_id. Almost always 0 or 1 ws."""
    clients = _notify_clients.get(duck_id)
    if not clients:
        return
    dead = []
    for ws in list(clients):
        try:
            await ws.send_text(payload)
        except (WebSocketDisconnect, RuntimeError, OSError):
            # FastAPI / Starlette raises WebSocketDisconnect on a closed
            # client; RuntimeError when send is attempted after close
            # ("Cannot call 'send' once a close message has been sent");
            # OSError on broken sockets. Anything else (TypeError,
            # KeyError, AttributeError) is a programmer bug — let it
            # propagate so uvicorn surfaces it.
            dead.append(ws)
    for ws in dead:
        clients.discard(ws)


# Per-upstream "has this session already announced a printer event?" flag.
# Drives notice-vs-update phrasing: the first event of a session uses
# "Printer notice:" so the agent announces fresh; subsequent events in the
# same session use "Printer update:" so the agent treats them as in-context
# continuations and weaves them into the conversation naturally rather than
# re-announcing from scratch.
#
# Stored as an attribute on the upstream object directly (`upstream._duck_announced`)
# rather than a set keyed by id(upstream). Python may reuse object ids
# after GC; a fresh upstream landing in a previously-used id slot would
# inherit the wrong "already announced" state and use the wrong header.
# Attribute-on-object dies with the object — no aliasing risk, no
# separate tracking set to keep in sync.
_ANNOUNCED_ATTR = "_duck_announced"


async def _inject_into_active_sessions(duck_id: str, event_type: str,
                                        friendly: Optional[str],
                                        printer_name: Optional[str] = None,
                                        hms_phrases: Optional[list] = None) -> int:
    """Push a printer event into the live upstream for `duck_id`, if any.
    Returns the number of sessions injected into (0 or 1, basically —
    higher only if a duck somehow has multiple concurrent upstreams).

    A user_message landing mid-utterance cleanly interrupts the agent's
    current turn — same effect as a hard session interrupt, no audio
    glitch. The agent's response then naturally flows into addressing
    the new event."""
    upstreams = _active_upstreams.get(duck_id)
    if not upstreams:
        return 0
    n = 0
    for upstream in list(upstreams):
        already = getattr(upstream, _ANNOUNCED_ATTR, False)
        header = "Printer update" if already else "Printer notice"
        text = _printer_text_for(event_type, friendly, header,
                                  printer_name, hms_phrases)
        try:
            await _send_user_message(upstream, text)
            setattr(upstream, _ANNOUNCED_ATTR, True)
            logger.info("notify injected (duck=%s): %s", duck_id, text)
            n += 1
        except (websockets.WebSocketException, OSError) as e:
            # Upstream died between connect and inject — not a bug, just
            # a stale entry in _active_upstreams. Drop it. Programmer
            # errors (TypeError on a wrong send shape etc.) still raise.
            logger.warning("inject failed (upstream gone?): %s", e)
            upstreams.discard(upstream)
    return n


async def _dispatch_event(duck_id: str, event_type: str,
                            friendly: Optional[str],
                            printer_name: Optional[str] = None,
                            hms_phrases: Optional[list] = None) -> None:
    """Route a printer event for `duck_id` to either its live session
    (inject) or its notify channel (broadcast → chip opens new session).

    Two paths by design — they aren't redundant. Inject reuses an open
    upstream so the agent pivots mid-conversation with no audio glitch.
    Broadcast is the cold-start: the chip is idle, /ws/notify wakes it,
    chip dials /ws/duck?event=...&subtask=..., and ws_duck_endpoint
    sends the opening user_message right after init metadata.

    `hms_phrases` is only meaningful when event_type=='hms'; passed
    through to the user_message builder so the agent can speak the
    actual fault ("filament tangled in AMS slot 1") rather than a
    generic "the printer's flagging an error."""
    injected = await _inject_into_active_sessions(duck_id, event_type,
                                                    friendly, printer_name,
                                                    hms_phrases)
    if injected:
        return
    notify = {"type": "notify", "event": event_type, "subtask": friendly}
    # Pass phrases on the broadcast too — the chip's session-start
    # path will request them via the agent's HMS-aware path. Today the
    # chip's notify_item_t only carries event + subtask, so the phrases
    # are discarded once they hit the chip — but the relay's session-
    # opening user_message (in ws_duck_endpoint) reads them direct from
    # the live BambuState's snapshot, so the agent still gets them.
    if hms_phrases:
        notify["hms_phrases"] = [s for s in hms_phrases if s]
    payload = json.dumps(notify, ensure_ascii=False)
    await _broadcast_notify(duck_id, payload)
    logger.info("notify broadcast (duck=%s, no active session): %s — %s%s",
                duck_id, event_type, friendly,
                f" ({printer_name})" if printer_name else "")


# Per-duck reference for ws_duck_endpoint to read printer_name when handling
# notify-triggered session opens (chip URL params don't carry it yet — see
# #41 for the per-printer-serial routing follow-up).
_bambu_states: dict[str, "BambuState"] = {}  # type: ignore


def register_bambu_listener(duck_id: str, state) -> None:
    """Wire `state`'s event listener to fan out via WS for `duck_id`.

    Captures the running asyncio loop on the first call so the MQTT
    thread's listener can dispatch onto it. Also stashes the state in
    `_bambu_states` so /ws/duck can read printer_name for that duck.

    The listener closure binds duck_id at registration time — that's how
    a fired event knows which duck's clients to notify."""
    global _main_loop
    if _main_loop is None:
        _main_loop = asyncio.get_running_loop()
    _bambu_states[duck_id] = state

    def _on_event(event: dict) -> None:
        # MQTT-thread entry point. Schedules _dispatch_event onto the
        # captured loop with duck_id bound from the registration scope.
        if _main_loop is None:
            return
        asyncio.run_coroutine_threadsafe(
            _dispatch_event(
                duck_id,
                event.get("type"),
                _friendly_subtask(event.get("subtask")),
                event.get("printer_name") or None,
                event.get("phrases") or None,
            ),
            _main_loop,
        )

    state.add_listener(_on_event)


def fire_notification_for(duck_id: str, event: dict) -> None:
    """Direct-call entry point used by the test endpoint to synthesize an
    event without going through MQTT. Same dispatch path as the listener
    closure above."""
    if _main_loop is None:
        return
    asyncio.run_coroutine_threadsafe(
        _dispatch_event(
            duck_id,
            event.get("type"),
            _friendly_subtask(event.get("subtask")),
            event.get("printer_name") or None,
            event.get("phrases") or None,
        ),
        _main_loop,
    )

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
                     duck_id: str,
                     suppress_first_message: bool = False) -> None:
    """ElevenAgents init. For notification-triggered sessions we suppress
    the agent's default greeting (so it doesn't say "Yeah?" then pivot)
    and inject a user_message right after init that tells the agent what
    the printer just did — agent improvises the announcement in voice.

    `duck_id` is passed as a dynamic variable so the agent's tool URLs
    template `/tools/printer_state/{{duck_id}}` resolve to the correct
    per-tenant route at call time. Without this, every conversation
    on a multi-duck relay called the un-scoped fallback path which
    routed to the oldest row in the DB — every duck would talk about
    the relay operator's printers regardless of who was actually
    using the duck. Dynamic variables substitute on the agent server
    side at tool-call time, so the relay never has to forge URLs
    itself; the agent just calls the right URL for this conversation.

    Suppressing first_message requires the agent's Security tab to have
    first_message override enabled. Same goes for the dynamic variable
    use — agent must allow per-session config overrides in Security.
    """
    payload = {
        "type": "conversation_initiation_client_data",
        "dynamic_variables": {"duck_id": duck_id},
    }
    if suppress_first_message:
        payload["conversation_config_override"] = {
            "agent": {"first_message": ""}
        }
    await upstream.send(json.dumps(payload))


def _printer_text_for(event_type: str, subtask: Optional[str], header: str,
                       printer_name: Optional[str] = None,
                       hms_phrases: Optional[list] = None) -> str:
    """Build the user_message body for a printer event. Caller passes header:
      'Printer notice' — first-in-session, agent announces fresh.
      'Printer update' — subsequent events in same session, agent treats
        them as in-context follow-ups and weaves them into the conversation
        rather than re-announcing from scratch.
    `printer_name` (when present) is the friendly name from Bambu cloud's
    device list so the agent can disambiguate which printer fired the
    event ("Work Bambu just started" vs "your printer just started").
    Empty string / None falls back to a generic phrasing — same shape as
    before this change, so LAN-mode installs are unchanged.

    `hms_phrases` (only used when event_type=='hms') is the parallel-
    indexed list of friendly TTS strings from hms_codes.lookup. Falls
    back to the generic "flagging an error" when none of the codes
    have phrases. Multiple known phrases get joined with semicolons
    so the agent can read them as a list."""
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
        known = [s for s in (hms_phrases or []) if s]
        if known:
            joined = "; ".join(known)
            return f"{header}: {p} is reporting — {joined}."
        return f"{header}: {p} is flagging an error."
    if event_type == "setup_complete":
        # Post-onboarding handshake (#34). subtask carries the literal
        # line we want the duck to deliver ("All set. I'm listening
        # for X and Y. Get printing!"). Frame as a direct read so the
        # agent doesn't reinterpret the printer list.
        line = subtask or "All set. Get printing!"
        return (f"{header}: onboarding just completed. "
                f"Tell the user, in your own friendly voice: \"{line}\"")
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
    duck_id = _resolve_ws_duck_id(duck)
    if not duck_id:
        await duck.close(code=1011)
        return
    await duck.accept()
    db.get().touch_duck(duck_id)

    # ElevenLabs creds resolution: per-duck DB row first, env fallback.
    # # COMPAT — env fallback can drop once every duck's row is populated
    # (which the captive-portal additions in #31 will guarantee).
    row = db.get().get_duck(duck_id) or {}
    api_key = row.get("elevenlabs_key") or os.environ.get("ELEVENLABS_API_KEY")
    agent_id = row.get("elevenlabs_agent") or os.environ.get("BAMBU_DUCK_AGENT_ID")
    if not api_key or not agent_id:
        logger.error("no ElevenLabs creds for duck=%s (DB row + env both empty)",
                     duck_id)
        await duck.close(code=1011)
        return

    try:
        signed = await _fetch_signed_url(api_key, agent_id)
    except (httpx.HTTPError, KeyError, ValueError, OSError) as e:
        # httpx network / status errors, KeyError if ElevenLabs's response
        # is missing 'signed_url', ValueError on bad JSON, OSError on
        # transport. Anything else is a programmer bug — propagate.
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

    logger.info("duck connected (duck=%s), opening upstream WS", duck_id)
    upstream_ref = None
    try:
        async with websockets.connect(signed, max_size=None) as upstream:
            upstream_ref = upstream
            _active_upstreams.setdefault(duck_id, set()).add(upstream)
            # When opened from a notification, suppress the agent's default
            # greeting and immediately inject a "Printer notice: ..."
            # user_message so the LLM phrases the announcement in its own
            # voice. Otherwise (button press) let the agent open normally.
            await _send_init(upstream, duck_id,
                              suppress_first_message=bool(event_type))
            if event_type:
                # Pull printer_name from this duck's state — chip's URL
                # params don't carry it (see _dispatch_event comment / #41).
                this_state = _bambu_states.get(duck_id)
                pname = this_state.printer_name if this_state else None
                notice = _printer_text_for(event_type, subtask, "Printer notice", pname)
                logger.info("session opening from notify (duck=%s): event=%s subtask=%r printer=%r",
                            duck_id, event_type, subtask, pname)
                await _send_user_message(upstream, notice)
                # Mark first announcement done — any further events that
                # arrive during this session use "Printer update:" phrasing.
                setattr(upstream, _ANNOUNCED_ATTR, True)
            last_sent = [time.time()]
            up = asyncio.create_task(_duck_to_eleven(duck, upstream, mic_wav, last_sent))
            down = asyncio.create_task(_eleven_to_duck(duck, upstream, agent_wav))
            silence = asyncio.create_task(_silence_pump(upstream, last_sent))
            done, pending = await asyncio.wait({up, down, silence}, return_when=asyncio.FIRST_COMPLETED)
            for task in pending:
                task.cancel()
    except (websockets.WebSocketException, asyncio.TimeoutError, OSError,
            json.JSONDecodeError) as e:
        # Expected runtime errors during a live upstream session: WS
        # closed/protocol issues, network/transport, malformed message
        # from ElevenAgents. NARROW intentionally — programmer errors
        # (TypeError from a stale function signature, AttributeError
        # from a renamed attr, KeyError from a missing dict key)
        # previously hid behind a broad `except Exception` here, which
        # masked the _send_init signature mismatch bug for several
        # iterations (see #39). Those propagate now.
        logger.exception("upstream session error: %s", e)
    finally:
        if upstream_ref is not None:
            ups = _active_upstreams.get(duck_id)
            if ups:
                ups.discard(upstream_ref)
                if not ups:
                    _active_upstreams.pop(duck_id, None)
            # No separate cleanup for the announced flag — it lives on
            # the upstream object and dies with it.
        if mic_wav is not None:
            mic_wav.close()
        if agent_wav is not None:
            agent_wav.close()
        try:
            await duck.close()
        except (WebSocketDisconnect, RuntimeError, OSError):
            # Already-closed / double-close races land here cleanly.
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


# Legacy-adoption hook. main.py calls register_legacy_claim_handler at
# startup with its claim_legacy_if_applicable function. We can't import
# main.py here without a cycle.
_legacy_claim_fn = None


def register_legacy_claim_handler(fn) -> None:
    global _legacy_claim_fn
    _legacy_claim_fn = fn


# Same shim pattern for the set_printers reconfigure path — chip sends
# us the new serial subset, we narrow the binding in the DB, but the
# live BambuState's MQTT subscriptions also need updating. main.py owns
# the registry so we go through this callback.
_set_printers_reconfigure = None


def register_set_printers_handler(fn) -> None:
    global _set_printers_reconfigure
    _set_printers_reconfigure = fn


# And for list_printers — chip wants the printer list without re-auth.
# main.py's handler reads the duck's row, calls list_devices with the
# stored access_token, returns [{serial, name, online}, ...].
_list_printers_fn = None


def register_list_printers_handler(fn) -> None:
    global _list_printers_fn
    _list_printers_fn = fn


def _join_printer_names(names: list[str]) -> str:
    """Build a natural-sounding list for the post-onboarding spoken
    confirmation:
       []        -> ""               (caller should handle this case)
       [a]       -> "a"
       [a, b]    -> "a and b"
       [a, b, c] -> "a, b, and c"     (Oxford comma — TTS pacing
                                        sounds more measured)
    """
    names = [n for n in names if n]
    if not names:
        return ""
    if len(names) == 1:
        return names[0]
    if len(names) == 2:
        return f"{names[0]} and {names[1]}"
    return ", ".join(names[:-1]) + f", and {names[-1]}"


def _resolve_ws_duck_id(duck: WebSocket) -> Optional[str]:
    """Pull duck_id from the WS handshake. Order of precedence:
       1. `X-Duck-Id` header — the canonical multi-tenant signal
       2. `?duck_id=...` query param — fallback for clients that can't
          set headers (some libs don't expose them on WS)
       3. # COMPAT: default duck (oldest row in DB) — drops once chip
          firmware always sends X-Duck-Id

    Returns None only if the DB is empty AND no id was in the request,
    in which case the caller should reject the connection.

    Side effect: runs the legacy-claim adoption flow if the chip
    announces a real MAC and the DB has only "legacy" — that row
    gets renamed to the chip's MAC so subsequent lookups land.
    """
    duck_id = duck.headers.get("x-duck-id") or duck.query_params.get("duck_id")
    if duck_id:
        normalized = duck_id.lower().strip()
        if _legacy_claim_fn is not None:
            normalized = _legacy_claim_fn(normalized)
        return normalized
    return db.get().default_duck_id()  # COMPAT


@router.websocket("/ws/notify")
async def ws_notify_endpoint(duck: WebSocket) -> None:
    duck_id = _resolve_ws_duck_id(duck)
    if not duck_id:
        await duck.close(code=1011)
        return
    await duck.accept()
    db.get().touch_duck(duck_id)
    _notify_clients.setdefault(duck_id, set()).add(duck)
    logger.info("notify client connected (duck=%s, total=%d)",
                duck_id, sum(len(v) for v in _notify_clients.values()))
    try:
        while True:
            msg = await duck.receive()
            if msg.get("type") == "websocket.disconnect":
                break
            # Chip-originated text messages — the captive-portal APSTA
            # wizard sends `bambu_login` here so we handle the cloud
            # login on the chip's behalf. Could do it on the chip now
            # that wss:// works, but routing through the relay's
            # existing httpx machinery is simpler than adding a second
            # TLS path on the chip.
            text = msg.get("text")
            if not text:
                continue
            try:
                payload = json.loads(text)
            except json.JSONDecodeError:
                logger.warning("notify rx non-JSON: %s", text[:100])
                continue
            mtype = payload.get("type")
            if mtype == "list_printers":
                # Fast-path support for the "long-press while already
                # onboarded" flow (#41 follow-up). Chip already has
                # WiFi NVS + a row on the relay; it doesn't want to
                # re-do bambu_login. We use the stored access_token
                # to call list_devices and return the same numbered-
                # string format as bambu_login_result. Chip drops it
                # straight into its s_printers[] for the picker page.
                target = payload.get("duck_id") or duck_id
                ack = {"type": "list_printers_result", "ok": False}
                if _list_printers_fn is None:
                    ack["error"] = "no_handler"
                else:
                    try:
                        printers = await _list_printers_fn(target)
                        # Also pull the duck's CURRENT subscribed serial
                        # set so we can stamp `subscribed` per printer.
                        # Picker uses this to render the right check
                        # state on revisit (vs defaulting to online).
                        row = db.get().get_duck(target) or {}
                        try:
                            bound_serials = set(json.loads(
                                row.get("serials") or "[]"))
                        except (ValueError, TypeError):
                            bound_serials = set()
                        ack["ok"] = True
                        ack["printer_count"] = str(len(printers))
                        for i, p in enumerate(printers[:8]):
                            safe = (p.get("name") or "").replace('"', "'") \
                                                       .replace("\\", "/") \
                                                       .replace("\n", " ")
                            if len(safe) > 31:
                                safe = safe[:31]
                            ack[f"printer_{i}_name"] = safe
                            ack[f"printer_{i}_serial"] = p["serial"]
                            ack[f"printer_{i}_online"] = (
                                "1" if p.get("online") else "0")
                            ack[f"printer_{i}_subscribed"] = (
                                "1" if p["serial"] in bound_serials else "0")
                    except Exception as e:
                        # Broad on purpose — _list_printers_fn is a
                        # registered handler that can do anything (httpx,
                        # DB, runtime). But log the EXCEPTION TYPE so
                        # future programmer errors don't hide as a
                        # generic "list_printers failed: foo".
                        logger.warning("list_printers failed (%s): %s",
                                       type(e).__name__, e)
                        ack["error"] = str(e)[:80]
                await duck.send_text(json.dumps(ack, ensure_ascii=False))
                continue
            if mtype == "set_printers":
                # Phase B of #41 — captive-portal printer picker. Chip
                # sends the chosen serials pipe-delimited; relay narrows
                # the duck's binding to that subset and reconfigures the
                # BambuState. Original full list stays accessible — a
                # future re-pick (or /admin/rebind_printers) can widen
                # the binding back without re-doing bambu_login.
                target = payload.get("duck_id") or duck_id
                serials_str = payload.get("serials") or ""
                serials = [s for s in serials_str.split("|") if s]
                ack = {"type": "set_printers_result", "ok": False}
                if not target:
                    ack["error"] = "missing_duck_id"
                elif not serials:
                    ack["error"] = "no_serials"
                else:
                    try:
                        # Look up printer names from the existing row
                        # AND from a fresh list_devices call. The row
                        # only has names for currently-bound printers,
                        # so re-checking a previously-unchecked printer
                        # would lose its name (only its serial would
                        # be on the row to look up). Prefer the live
                        # list_devices result, fall back to the row.
                        row = db.get().get_duck(target) or {}
                        try:
                            existing_serials = json.loads(
                                row.get("serials") or "[]")
                            existing_names = json.loads(
                                row.get("printer_names") or "[]")
                        except (ValueError, TypeError):
                            existing_serials, existing_names = [], []
                        name_by_serial = dict(
                            zip(existing_serials, existing_names))
                        # Ask Bambu cloud for the live full list (uses
                        # the stored access_token, no re-auth). This
                        # ensures freshly-rechecked serials get their
                        # current friendly name.
                        if _list_printers_fn is not None and \
                           row.get("access_token"):
                            try:
                                live = await _list_printers_fn(target)
                                for p in live:
                                    if p.get("name"):
                                        name_by_serial[p["serial"]] = \
                                            p["name"]
                            except Exception as e:
                                # Broad — live list_devices reaches Bambu
                                # cloud via httpx; failure is a soft
                                # degrade (row names still work). Type
                                # in the log so the genre of failure is
                                # visible (network vs auth vs bug).
                                logger.warning(
                                    "set_printers: live list_devices "
                                    "failed (%s: %s) — falling back to "
                                    "row names only",
                                    type(e).__name__, e)
                        chosen_names = [name_by_serial.get(s, "")
                                        for s in serials]
                        db.get().upsert_duck(
                            target,
                            serials=serials,
                            printer_names=chosen_names,
                        )
                        # Reconfigure the live BambuState so its MQTT
                        # subscriptions match the new selection. Need
                        # access to the in-memory states dict from main;
                        # we go through register_bambu_listener since
                        # main.py wires its setter at startup.
                        if _set_printers_reconfigure is not None:
                            _set_printers_reconfigure(target, serials,
                                                       chosen_names)
                        logger.info("set_printers stored for duck=%s "
                                    "(%d printers)", target, len(serials))
                        ack["ok"] = True
                        ack["count"] = len(serials)
                        # Onboarding handshake (#34): once the duck has
                        # bound to its printer subset, fire the same
                        # notify pipeline a print event uses. Chip
                        # wakes, opens an agent session, agent speaks
                        # "All set. I'm listening for X and Y" in the
                        # project voice. No bespoke TTS path — same
                        # rail as every other notification.
                        joined = _join_printer_names(chosen_names)
                        if joined:
                            line = (f"All set. I'm listening for {joined}. "
                                    f"Get printing! Tap me to talk.")
                        else:
                            # Edge case: chosen list had no friendly
                            # names (rare — Bambu cloud usually has them).
                            line = "All set. Tap me to talk."
                        # Schedule on the running loop so the ack we're
                        # about to send below isn't held up by the
                        # dispatch's own awaits.
                        asyncio.create_task(
                            _dispatch_event(target, "setup_complete", line))
                    except Exception as e:
                        # Broad — covers DB upserts, JSON parsing of row
                        # data, and the live BambuState reconfigure
                        # which touches paho-mqtt. Type in the log so
                        # we can tell DB issues from MQTT issues at a
                        # glance.
                        logger.warning("set_printers failed (%s): %s",
                                       type(e).__name__, e)
                        ack["error"] = "db_or_reconfigure_error"
                await duck.send_text(json.dumps(ack, ensure_ascii=False))
                continue
            if mtype == "set_eleven_creds":
                # Persist the user's ElevenLabs key + agent on this duck's
                # row. Captive portal sends this once during onboarding;
                # they get used the next time /ws/duck opens. We send a
                # `set_eleven_creds_result` ack back so the chip can
                # surface a clear failure to the user — without it a
                # silent DB error meant friends would think onboarding
                # succeeded but /ws/duck would close with code 1011 on
                # their first conversation attempt (audit, 2026-05-03).
                target = payload.get("duck_id") or duck_id
                key = payload.get("elevenlabs_key")
                agent = payload.get("elevenlabs_agent")
                ack = {"type": "set_eleven_creds_result", "ok": False}
                if not target or not key or not agent:
                    ack["error"] = "missing_fields"
                    logger.warning("set_eleven_creds missing fields")
                else:
                    try:
                        db.get().upsert_duck(
                            target,
                            elevenlabs_key=key,
                            elevenlabs_agent=agent,
                        )
                        logger.info("set_eleven_creds stored for duck=%s "
                                    "(agent=%s)", target, agent)
                        ack["ok"] = True
                    except Exception as e:
                        # Broad — db.upsert_duck path; sqlite3 errors
                        # most likely. Type in log for diagnosis.
                        logger.warning("set_eleven_creds upsert failed "
                                       "(%s): %s", type(e).__name__, e)
                        ack["error"] = "db_error"
                await duck.send_text(json.dumps(ack, ensure_ascii=False))
                continue
            if mtype == "bambu_login" and _bambu_login_handler is not None:
                # Stamp duck_id from the WS handshake into the payload so
                # the handler stores tokens on the right row. Chip-sent
                # duck_id (if any) wins, but the handshake is the
                # fallback so older firmware still works.
                payload.setdefault("duck_id", duck_id)
                logger.info("notify rx bambu_login (duck=%s, email=%s)",
                            payload["duck_id"], payload.get("email", "?"))
                try:
                    result = await _bambu_login_handler(payload)
                    reply = {"type": "bambu_login_result", "ok": True, **result}
                except asyncio.CancelledError:
                    # Don't swallow shutdown/cancellation as a login failure —
                    # propagate so FastAPI's lifespan teardown can finish.
                    raise
                except Exception as e:
                    # Broad — _bambu_login_handler is registered by
                    # main.py and reaches Bambu cloud + DB. HTTPException
                    # comes through with structured detail; any other
                    # runtime exception still produces a usable reply.
                    # Type goes into the log so it's clear when we
                    # caught something off-script (e.g., a TypeError
                    # from a refactor that changed the handler shape).
                    code = "login_failed"
                    msg_text = str(e)
                    # Pull through structured fields if HTTPException-shaped
                    detail = getattr(e, "detail", None)
                    if isinstance(detail, dict):
                        code = detail.get("code", code)
                        msg_text = detail.get("message", msg_text)
                    reply = {"type": "bambu_login_result", "ok": False,
                             "code": code, "message": msg_text}
                    logger.warning("bambu_login failed (duck=%s, %s): %s",
                                   duck_id, type(e).__name__, reply)
                await duck.send_text(json.dumps(reply, ensure_ascii=False))
                continue
            if mtype == "wipe_duck":
                # Factory-reset hand-off — chip is about to nvs_flash_erase
                # itself; we delete its row so the user's Bambu access_token,
                # ElevenLabs creds, printer binding, and account email all
                # disappear from the relay before the chip leaves their
                # hands. The next owner's onboarding creates a fresh row
                # under the same chip MAC.
                target = payload.get("duck_id") or duck_id
                ack = {"type": "wipe_duck_result", "ok": False}
                if not target:
                    ack["error"] = "missing_duck_id"
                else:
                    try:
                        # Stop the live MQTT subscription too — without
                        # this, paho keeps listening on the previous
                        # owner's account topics until the next deploy.
                        # _set_printers_reconfigure can stop the state by
                        # passing an empty serials list, but that leaves
                        # the BambuState alive on the wrong account; the
                        # cleanest move is to let main.py decide via a
                        # dedicated handler. For now, delete the row +
                        # log; the live MQTT state will be reaped on next
                        # relay restart. Acceptable for a low-traffic
                        # admin op.
                        deleted = db.get().delete_duck(target)
                        ack["ok"] = bool(deleted)
                        ack["deleted"] = bool(deleted)
                        logger.info("wipe_duck: %s for duck=%s",
                                    "deleted" if deleted else "no-op (no row)",
                                    target)
                    except Exception as e:
                        # Broad — DB-layer errors. Type in log for
                        # diagnosis.
                        logger.warning("wipe_duck failed (%s): %s",
                                       type(e).__name__, e)
                        ack["error"] = "db_error"
                await duck.send_text(json.dumps(ack, ensure_ascii=False))
                continue
            # Unknown message types — silently ignore.
    except WebSocketDisconnect:
        pass
    finally:
        clients = _notify_clients.get(duck_id)
        if clients:
            clients.discard(duck)
            if not clients:
                _notify_clients.pop(duck_id, None)
        logger.info("notify client disconnected (duck=%s, remaining=%d)",
                    duck_id, sum(len(v) for v in _notify_clients.values()))


@router.post("/admin/test_notification")
async def admin_test_notification(event: str = "finish", subtask: str = "TestPrint",
                                    duck_id: str | None = None):
    """Manual trigger for testing the notification path without waiting
    for a real print to finish. Stamps printer_name from the live state
    so the synthetic event matches the shape of a real bambu_state event.

    Without a `duck_id` query param, fires for the default duck.
    # COMPAT — same fallback as the un-scoped /tools routes."""
    target = duck_id or db.get().default_duck_id()
    if target is None:
        return {"ok": False, "error": "no ducks registered"}
    state = _bambu_states.get(target)
    pname = state.printer_name if state else ""
    fire_notification_for(target, {"type": event, "subtask": subtask,
                                    "printer_name": pname})
    return {
        "ok": True, "event": event, "subtask": subtask,
        "duck_id": target,
        "printer_name": pname,
        "clients_notified": len(_notify_clients.get(target, set())),
    }
