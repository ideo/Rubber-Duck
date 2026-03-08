"""
Routes — HTTP and WebSocket handler registrations.
"""

import json
import pathlib
from datetime import datetime

import aiohttp
from aiohttp import web

from broadcast import broadcast, connected_ws
from evaluator import evaluate, DIMENSIONS
from permission import gate, describe_suggestion
from tmux_bridge import send_to_claude_code

SERVICE_DIR = pathlib.Path(__file__).parent
DASHBOARD_PATH = SERVICE_DIR / "dashboard.html"
VIEWER_PATH = SERVICE_DIR / "viewer.html"


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

    scores = await evaluate(text, source, user_context)

    result = {
        "type": "eval",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "source": source,
        "text_preview": text[:150] + ("..." if len(text) > 150 else ""),
        "session_id": session_id,
        "scores": scores,
    }

    await broadcast(result)

    print(f"[{source}] {scores.get('reaction', '...')}  |  {scores.get('summary', '')}  |  "
          + "  ".join(f"{k}:{v:+.1f}" for k, v in scores.items() if k not in ('reaction', 'summary')))

    return web.json_response(result)


async def handle_permission(request: web.Request) -> web.Response:
    """Handle permission request — blocks until voice approval or timeout."""
    try:
        body = await request.json()
    except json.JSONDecodeError:
        return web.json_response({"error": "invalid json"}, status=400)

    tool_name = body.get("tool_name", "unknown")
    tool_input = body.get("tool_input", "{}")
    suggestions = body.get("permission_suggestions", [])

    option_labels = [describe_suggestion(s) for s in suggestions]

    print(f"[permission] Request: {tool_name} ({len(suggestions)} options)")

    await broadcast({
        "type": "permission",
        "status": "pending",
        "tool_name": tool_name,
        "tool_input": str(tool_input)[:200],
        "option_labels": option_labels,
    })

    decision, suggestion_index = await gate.wait_for_decision(timeout=30.0)

    if decision == "timeout":
        print("[permission] Timeout — no response from widget")
        await broadcast({"type": "permission", "status": "timeout", "tool_name": tool_name})
        return web.json_response({})

    await broadcast({"type": "permission", "status": decision, "tool_name": tool_name})

    response: dict = {"decision": decision}
    if decision == "allow" and suggestion_index is not None:
        response["suggestion_index"] = suggestion_index
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
                        text = data.get("text", "").strip()
                        if text:
                            send_to_claude_code(text)

                    elif cmd == "permission_response":
                        decision = data.get("decision", "deny")
                        suggestion_index = data.get("suggestion_index")
                        gate.resolve(decision, suggestion_index)

                except json.JSONDecodeError:
                    pass
    finally:
        connected_ws.discard(ws)
        print(f"[ws] Client disconnected ({len(connected_ws)} total)")

    return ws


async def handle_dashboard(request: web.Request) -> web.Response:
    return web.FileResponse(DASHBOARD_PATH)


async def handle_viewer(request: web.Request) -> web.Response:
    return web.FileResponse(VIEWER_PATH)


async def handle_health(request: web.Request) -> web.Response:
    from tmux_bridge import session, pane
    status = {
        "status": "ok",
        "connected_clients": len(connected_ws),
        "dimensions": list(DIMENSIONS.keys()),
        "tmux_target": f"{session}:{pane}",
    }
    return web.json_response(status)


def create_app() -> web.Application:
    """Create and configure the aiohttp application."""
    app = web.Application()
    app.router.add_post("/evaluate", handle_evaluate)
    app.router.add_post("/permission", handle_permission)
    app.router.add_get("/ws", handle_websocket)
    app.router.add_get("/", handle_dashboard)
    app.router.add_get("/viewer", handle_viewer)
    app.router.add_get("/health", handle_health)
    return app
