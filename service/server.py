"""
Rubber Duck Evaluation Service

Receives Claude Code hook payloads, evaluates them using Claude API
on multiple dimensions, and pushes results to all connected outputs:
  - Browser dashboard + 3D viewer (WebSocket)
  - Teensy hardware (Serial)
  - macOS desktop widget (WebSocket)
  - Voice reactions (TTS via speech engine)

Also handles:
  - Voice input → Claude Code (via tmux bridge)
  - Permission requests → voice approval gate
"""

import argparse
import asyncio
import json
import os
import pathlib
import signal
import subprocess
import sys
from datetime import datetime
from dotenv import load_dotenv

# Load .env from service directory
load_dotenv(pathlib.Path(__file__).parent / ".env", override=True)

import aiohttp
from aiohttp import web
import anthropic
import serial
import serial.tools.list_ports

# --- Config ---
PORT = 3333
SERIAL_BAUD = 9600
SERIAL_PORT = None  # Auto-detect, or set to e.g. "/dev/tty.usbmodem*"
DASHBOARD_PATH = pathlib.Path(__file__).parent / "dashboard.html"
VIEWER_PATH = pathlib.Path(__file__).parent / "viewer.html"
PID_PATH = pathlib.Path(__file__).parent / ".pid"

# Evaluation dimensions and their descriptions for the LLM prompt
DIMENSIONS = {
    "creativity": "How novel or creative is the approach? Boring/obvious vs inspired/surprising.",
    "soundness": "Is this technically sound? Will it work, or is it flawed/naive?",
    "ambition": "How ambitious is the scope? Trivial tweak vs bold undertaking.",
    "elegance": "Is the solution elegant and clean, or hacky and convoluted?",
    "risk": "How risky is this? Safe and predictable vs could-go-wrong territory.",
}

EVAL_SYSTEM_PROMPT = """You are a rubber duck sitting on a developer's desk. You observe their conversations with an AI coding assistant and have OPINIONS about what you see.

You evaluate text on these dimensions, scoring each from -1.0 to 1.0:

{dimensions}

You also provide a short (max 10 word) gut reaction quote - what the duck would say if it could talk. Be opinionated and characterful. Examples: "Oh no, not another todo app", "Now THAT'S what I'm talking about", "This is fine. Everything is fine."

Respond ONLY with valid JSON matching this schema:
{{
  "creativity": <float -1 to 1>,
  "soundness": <float -1 to 1>,
  "ambition": <float -1 to 1>,
  "elegance": <float -1 to 1>,
  "risk": <float -1 to 1>,
  "reaction": "<short gut reaction string>"
}}"""

EVAL_USER_PROMPT = """Source: {source}
{context_line}
Text to evaluate:
{text}"""

# --- State ---
connected_ws: set[web.WebSocketResponse] = set()
serial_port: serial.Serial = None
client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))
speech_engine = None  # SpeechEngine instance, set in main


# --- Serial ---

def find_teensy_port():
    """Auto-detect Teensy USB serial port."""
    for port in serial.tools.list_ports.comports():
        desc = (port.description or "").lower()
        mfg = (port.manufacturer or "").lower()
        if any(k in desc for k in ["teensy", "usb serial"]) or \
           any(k in mfg for k in ["teensy", "pjrc"]):
            return port.device
    return None


def connect_serial():
    """Try to connect to Teensy. Non-blocking, fails gracefully."""
    global serial_port
    port_path = SERIAL_PORT or find_teensy_port()
    if not port_path:
        print("[serial] No Teensy found. Running without hardware.")
        return False
    try:
        serial_port = serial.Serial(port_path, SERIAL_BAUD, timeout=0.1)
        print(f"[serial] Connected to {port_path}")
        return True
    except serial.SerialException as e:
        print(f"[serial] Failed to connect to {port_path}: {e}")
        serial_port = None
        return False


def send_to_teensy(scores: dict, source: str):
    """Send evaluation scores to Teensy over serial."""
    global serial_port
    if serial_port is None:
        return

    # Protocol: {U|C},creativity,soundness,ambition,elegance,risk\n
    src_char = "U" if source == "user" else "C"
    msg = f"{src_char},{scores.get('creativity', 0):.2f},{scores.get('soundness', 0):.2f}," \
          f"{scores.get('ambition', 0):.2f},{scores.get('elegance', 0):.2f},{scores.get('risk', 0):.2f}\n"

    try:
        serial_port.write(msg.encode())
        serial_port.flush()
    except serial.SerialException:
        print("[serial] Connection lost. Will retry on next eval.")
        serial_port = None


# --- Evaluation ---

def build_system_prompt() -> str:
    dim_text = "\n".join(f"- {k}: {v}" for k, v in DIMENSIONS.items())
    return EVAL_SYSTEM_PROMPT.format(dimensions=dim_text)


async def evaluate(text: str, source: str, user_context: str = "") -> dict:
    """Call Claude API to evaluate text on multiple dimensions."""
    context_line = ""
    if user_context and source == "claude":
        context_line = f"User's request (for context): {user_context[:500]}\n"

    # Truncate very long texts to keep eval focused and fast
    truncated = text[:2000] + ("..." if len(text) > 2000 else "")

    user_prompt = EVAL_USER_PROMPT.format(
        source=source,
        context_line=context_line,
        text=truncated,
    )

    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(
        None,
        lambda: client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=256,
            system=build_system_prompt(),
            messages=[{"role": "user", "content": user_prompt}],
        ),
    )

    raw = response.content[0].text.strip()
    # Strip markdown code fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]  # remove ```json line
        raw = raw.rsplit("```", 1)[0]  # remove closing ```
        raw = raw.strip()

    # Parse the JSON response
    try:
        result = json.loads(raw)
    except json.JSONDecodeError:
        # Fallback if the model doesn't return clean JSON
        print(f"[eval] Failed to parse JSON: {raw[:200]}")
        result = {dim: 0.0 for dim in DIMENSIONS}
        result["reaction"] = "I'm confused"

    return result


async def broadcast(data: dict):
    """Push data to all connected WebSocket clients."""
    msg = json.dumps(data)
    dead = set()
    for ws in connected_ws:
        try:
            await ws.send_str(msg)
        except (ConnectionResetError, ConnectionError):
            dead.add(ws)
    connected_ws.difference_update(dead)


# --- HTTP Handlers ---

async def handle_evaluate(request: web.Request) -> web.Response:
    """Receive hook payload, evaluate, broadcast results."""
    try:
        body = await request.json()
    except json.JSONDecodeError:
        return web.json_response({"error": "invalid json"}, status=400)

    text = body.get("text", "")
    source = body.get("source", "unknown")
    user_context = body.get("user_context", "")
    session_id = body.get("session_id", "")

    if not text:
        return web.json_response({"error": "no text"}, status=400)

    # Run evaluation
    scores = await evaluate(text, source, user_context)

    result = {
        "type": "eval",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "source": source,
        "text_preview": text[:150] + ("..." if len(text) > 150 else ""),
        "session_id": session_id,
        "scores": scores,
    }

    # Broadcast to all connected clients (dashboard, widget, viewer)
    await broadcast(result)

    # Send to Teensy (non-blocking, fails gracefully)
    send_to_teensy(scores, source)

    # Speak the duck's reaction
    if speech_engine:
        speech_engine.speak(scores.get("reaction", ""))

    print(f"[{source}] {scores.get('reaction', '...')}  |  "
          + "  ".join(f"{k}:{v:+.1f}" for k, v in scores.items() if k != "reaction"))

    return web.json_response(result)


async def handle_permission(request: web.Request) -> web.Response:
    """Handle permission request — blocks until voice approval or timeout.

    Called by on-permission-request.sh hook. The hook blocks waiting for
    this response, and Claude Code blocks waiting for the hook.

    Flow: Claude Code → hook → POST /permission → voice ask → voice response → reply
    """
    try:
        body = await request.json()
    except json.JSONDecodeError:
        return web.json_response({"error": "invalid json"}, status=400)

    tool_name = body.get("tool_name", "unknown")
    tool_input = body.get("tool_input", "{}")
    session_id = body.get("session_id", "")

    print(f"[permission] Request: {tool_name}")

    # Broadcast permission pending to widget/dashboard
    await broadcast({
        "type": "permission",
        "status": "pending",
        "tool_name": tool_name,
        "tool_input": str(tool_input)[:200],
    })

    # Ask user via voice and wait for response
    if speech_engine:
        loop = asyncio.get_event_loop()
        approved = await loop.run_in_executor(
            None,
            lambda: speech_engine.request_permission(tool_name, timeout=30.0),
        )
    else:
        # No speech engine — don't block, let Claude Code's own UI handle it
        print("[permission] No speech engine — skipping voice gate")
        return web.json_response({})

    decision = "allow" if approved else "deny"

    # Broadcast result
    await broadcast({
        "type": "permission",
        "status": decision,
        "tool_name": tool_name,
    })

    return web.json_response({"decision": decision})


async def handle_websocket(request: web.Request) -> web.WebSocketResponse:
    """WebSocket endpoint for dashboard, widget, and viewer clients."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    connected_ws.add(ws)
    print(f"[ws] Client connected ({len(connected_ws)} total)")

    try:
        async for msg in ws:
            # Accept commands from widget (e.g., toggle TTS, change voice)
            if msg.type == aiohttp.WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                    cmd = data.get("command")
                    if cmd == "set_voice" and speech_engine:
                        speech_engine.voice = data.get("voice", speech_engine.voice)
                        print(f"[ws] Voice set to {speech_engine.voice}")
                except json.JSONDecodeError:
                    pass
    finally:
        connected_ws.discard(ws)
        print(f"[ws] Client disconnected ({len(connected_ws)} total)")

    return ws


async def handle_dashboard(request: web.Request) -> web.Response:
    """Serve the dashboard HTML."""
    return web.FileResponse(DASHBOARD_PATH)


async def handle_viewer(request: web.Request) -> web.Response:
    """Serve the 3D viewer HTML."""
    return web.FileResponse(VIEWER_PATH)


async def handle_health(request: web.Request) -> web.Response:
    """Health check / status endpoint."""
    status = {
        "status": "ok",
        "connected_clients": len(connected_ws),
        "dimensions": list(DIMENSIONS.keys()),
        "speech_engine": speech_engine is not None,
        "serial": serial_port is not None,
    }
    if speech_engine and speech_engine._tmux_session:
        status["tmux_target"] = f"{speech_engine._tmux_session}:{speech_engine._tmux_pane}"
    return web.json_response(status)


# --- App ---

def create_app() -> web.Application:
    app = web.Application()
    app.router.add_post("/evaluate", handle_evaluate)
    app.router.add_post("/permission", handle_permission)
    app.router.add_get("/ws", handle_websocket)
    app.router.add_get("/", handle_dashboard)
    app.router.add_get("/viewer", handle_viewer)
    app.router.add_get("/health", handle_health)
    return app


def write_pid():
    """Write current process PID for lifecycle management."""
    PID_PATH.write_text(str(os.getpid()))


def cleanup_pid():
    """Remove PID file on shutdown."""
    try:
        PID_PATH.unlink(missing_ok=True)
    except Exception:
        pass


def handle_signal(signum, frame):
    """Graceful shutdown on SIGTERM/SIGINT."""
    print("\n[duck] Shutting down...")
    if speech_engine:
        speech_engine.stop()
    cleanup_pid()
    sys.exit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rubber Duck Evaluation Service")
    parser.add_argument("--voice", default="Boing", help="macOS TTS voice (default: Boing)")
    parser.add_argument("--wake-word", default="ducky", help="Wake word (default: ducky)")
    parser.add_argument("--mic", type=int, default=None, help="Microphone device index")
    parser.add_argument("--list-mics", action="store_true", help="List mics and exit")
    parser.add_argument("--no-speech", action="store_true", help="Disable speech engine")
    parser.add_argument("--tmux-session", default="duck", help="tmux session name for voice bridge")
    parser.add_argument("--tmux-pane", default="claude.0", help="tmux pane for Claude Code input")
    parser.add_argument("--port", type=int, default=PORT, help="HTTP server port")
    args = parser.parse_args()

    PORT = args.port

    if args.list_mics:
        from speech import SpeechEngine
        print("Available microphones:")
        SpeechEngine.list_mics()
        sys.exit(0)

    # Register signal handlers
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    # Write PID file
    write_pid()

    print("=" * 50)
    print("  RUBBER DUCK — Evaluation Service")
    print(f"  Dashboard:  http://localhost:{PORT}")
    print(f"  3D Viewer:  http://localhost:{PORT}/viewer")
    print(f"  Voice:      {args.voice}")
    print(f"  Wake word:  \"{args.wake_word}\"")
    print("=" * 50)
    print()

    # Try to connect to Teensy (optional)
    connect_serial()

    # Initialize speech engine
    if not args.no_speech:
        try:
            from speech import SpeechEngine

            # Auto-detect Teensy mic if available
            mic_idx = args.mic
            if mic_idx is None:
                teensy_mic = SpeechEngine.find_teensy_mic()
                if teensy_mic is not None:
                    mic_idx = teensy_mic
                    print(f"[speech] Auto-detected Teensy mic at index {mic_idx}")

            speech_engine = SpeechEngine(
                mic_index=mic_idx,
                voice=args.voice,
                wake_word=args.wake_word,
            )
            speech_engine.calibrate()
            speech_engine.set_tmux_target(args.tmux_session, args.tmux_pane)
            speech_engine.start()  # Background wake word listener

            # Greeting
            speech_engine.speak("What are we up to?")

        except ImportError as e:
            print(f"[speech] Missing dependency: {e}")
            print("[speech] Install with: pip install SpeechRecognition PyAudio")
            print("[speech] Running without voice.")
        except Exception as e:
            print(f"[speech] Failed to initialize: {e}")
            print("[speech] Running without voice.")
    else:
        print("[speech] Disabled via --no-speech")

    print()
    web.run_app(create_app(), port=PORT, print=None)

    # Cleanup
    if speech_engine:
        speech_engine.stop()
    cleanup_pid()
