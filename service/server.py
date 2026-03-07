"""
Rubber Duck Evaluation Service

Receives Claude Code hook payloads, evaluates them using Claude API
on multiple dimensions, and broadcasts results via WebSocket:
  - Browser dashboard + 3D viewer
  - macOS desktop widget (which owns speech I/O + Teensy serial)

Also handles:
  - Voice input from widget → Claude Code (via tmux bridge)
  - Permission requests → widget voice gate → approval/denial
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

# --- Config ---
PORT = 3333
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
client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

# Permission gate: asyncio.Event set when widget responds to a permission request
permission_event = None       # asyncio.Event
permission_decision = None    # str: "allow" or "deny"
permission_suggestion_index = None  # int or None — which suggestion the user picked (1-based)

# tmux bridge config (set from CLI args)
tmux_session = "duck"
tmux_pane = "claude.0"


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
    # Widget handles TTS + serial to Teensy on its end.
    await broadcast(result)

    print(f"[{source}] {scores.get('reaction', '...')}  |  "
          + "  ".join(f"{k}:{v:+.1f}" for k, v in scores.items() if k != "reaction"))

    return web.json_response(result)


def describe_suggestion(suggestion: dict) -> str:
    """Generate a short human-readable label for a permission suggestion."""
    stype = suggestion.get("type", "")
    dest = suggestion.get("destination", "session")
    dest_label = "this session" if dest == "session" else "always"

    if stype == "addRules":
        rules = suggestion.get("rules", [])
        if rules:
            rule = rules[0]
            tool = rule.get("toolName", "this tool")
            content = rule.get("ruleContent", "")
            if content:
                return f"always allow {tool}({content}) for {dest_label}"
            return f"always allow {tool} for {dest_label}"
    elif stype == "addDirectories":
        dirs = suggestion.get("directories", [])
        if dirs:
            return f"allow all access in {dirs[0]} for {dest_label}"
        return f"add directory for {dest_label}"
    elif stype == "acceptEdits":
        return "allow all file edits"

    return stype or "unknown option"


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
    suggestions = body.get("permission_suggestions", [])

    # Generate human-readable option labels from suggestions
    option_labels = [describe_suggestion(s) for s in suggestions]

    print(f"[permission] Request: {tool_name} ({len(suggestions)} options)")

    # Broadcast permission pending to widget/dashboard (with option labels)
    await broadcast({
        "type": "permission",
        "status": "pending",
        "tool_name": tool_name,
        "tool_input": str(tool_input)[:200],
        "option_labels": option_labels,
    })

    # Wait for widget to respond via WebSocket (permission_response command)
    global permission_event, permission_decision, permission_suggestion_index
    permission_event = asyncio.Event()
    permission_decision = None
    permission_suggestion_index = None

    try:
        await asyncio.wait_for(permission_event.wait(), timeout=30.0)
    except asyncio.TimeoutError:
        print("[permission] Timeout — no response from widget")
        await broadcast({"type": "permission", "status": "timeout", "tool_name": tool_name})
        return web.json_response({})

    decision = permission_decision if permission_decision in ("allow", "deny") else "deny"

    # Broadcast result
    await broadcast({"type": "permission", "status": decision, "tool_name": tool_name})

    response: dict = {"decision": decision}
    if decision == "allow" and permission_suggestion_index is not None:
        response["suggestion_index"] = permission_suggestion_index
    return web.json_response(response)


async def handle_websocket(request: web.Request) -> web.WebSocketResponse:
    """WebSocket endpoint for dashboard, widget, and viewer clients."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    connected_ws.add(ws)
    print(f"[ws] Client connected ({len(connected_ws)} total)")

    try:
        async for msg in ws:
            if msg.type == aiohttp.WSMsgType.TEXT:
                try:
                    data = json.loads(msg.data)
                    cmd = data.get("command")

                    if cmd == "voice_input":
                        # Widget transcribed voice → inject into Claude Code via tmux
                        text = data.get("text", "").strip()
                        if text:
                            send_to_claude_code(text)

                    elif cmd == "permission_response":
                        # Widget collected voice response → unblock /permission
                        # decision: "allow" or "deny"
                        # suggestion_index: 1-based index into permission_suggestions, or null
                        global permission_event, permission_decision, permission_suggestion_index
                        decision = data.get("decision", "deny")
                        suggestion_index = data.get("suggestion_index")  # int or None
                        permission_decision = decision
                        permission_suggestion_index = suggestion_index
                        if permission_event:
                            permission_event.set()
                        print(f"[permission] Widget responded: {decision}, suggestion_index={suggestion_index}")

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
        "tmux_target": f"{tmux_session}:{tmux_pane}",
    }
    return web.json_response(status)


# --- tmux Bridge ---

def send_to_claude_code(text: str):
    """Send text to Claude Code via tmux send-keys."""
    target = f"{tmux_session}:{tmux_pane}"
    try:
        subprocess.run(
            ["tmux", "send-keys", "-t", target, "-l", text],
            check=True, timeout=5,
        )
        subprocess.run(
            ["tmux", "send-keys", "-t", target, "Enter"],
            check=True, timeout=5,
        )
        print(f"[tmux] Sent to {target}: {text[:80]}")
    except subprocess.CalledProcessError as e:
        print(f"[tmux] Failed to send: {e}")
    except FileNotFoundError:
        print("[tmux] tmux not found")


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
    cleanup_pid()
    sys.exit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rubber Duck Evaluation Service")
    parser.add_argument("--tmux-session", default="duck", help="tmux session name for voice bridge")
    parser.add_argument("--tmux-pane", default="claude.0", help="tmux pane for Claude Code input")
    parser.add_argument("--port", type=int, default=PORT, help="HTTP server port")
    args = parser.parse_args()

    PORT = args.port
    tmux_session = args.tmux_session
    tmux_pane = args.tmux_pane

    # Register signal handlers
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    # Write PID file
    write_pid()

    print("=" * 50)
    print("  RUBBER DUCK — Evaluation Service")
    print(f"  Dashboard:  http://localhost:{PORT}")
    print(f"  3D Viewer:  http://localhost:{PORT}/viewer")
    print(f"  tmux:       {tmux_session}:{tmux_pane}")
    print("=" * 50)
    print()
    print("  Speech + Serial owned by widget app.")
    print("  Start widget: cd widget && make run")
    print()

    web.run_app(create_app(), port=PORT, print=None)

    # Cleanup
    cleanup_pid()
