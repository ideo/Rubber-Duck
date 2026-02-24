"""
Rubber Duck Evaluation Service

Receives Claude Code hook payloads, evaluates them using Claude API
on multiple dimensions, and pushes results to a browser dashboard via WebSocket.
"""

import asyncio
import json
import os
import pathlib
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
    """Push evaluation result to all connected dashboard clients."""
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
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "source": source,
        "text_preview": text[:150] + ("..." if len(text) > 150 else ""),
        "session_id": session_id,
        "scores": scores,
    }

    # Broadcast to dashboard
    await broadcast(result)

    # TODO: eventually send to serial here
    # await send_to_teensy(scores)

    print(f"[{source}] {scores.get('reaction', '...')}  |  "
          + "  ".join(f"{k}:{v:+.1f}" for k, v in scores.items() if k != "reaction"))

    return web.json_response(result)


async def handle_websocket(request: web.Request) -> web.WebSocketResponse:
    """WebSocket endpoint for the dashboard."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    connected_ws.add(ws)
    print(f"[dashboard] client connected ({len(connected_ws)} total)")

    try:
        async for msg in ws:
            pass  # We only push, never receive
    finally:
        connected_ws.discard(ws)
        print(f"[dashboard] client disconnected ({len(connected_ws)} total)")

    return ws


async def handle_dashboard(request: web.Request) -> web.Response:
    """Serve the dashboard HTML."""
    return web.FileResponse(DASHBOARD_PATH)


async def handle_test(request: web.Request) -> web.Response:
    """Quick test endpoint to verify the service is running."""
    return web.json_response({
        "status": "ok",
        "connected_clients": len(connected_ws),
        "dimensions": list(DIMENSIONS.keys()),
    })


# --- App ---

def create_app() -> web.Application:
    app = web.Application()
    app.router.add_post("/evaluate", handle_evaluate)
    app.router.add_get("/ws", handle_websocket)
    app.router.add_get("/", handle_dashboard)
    app.router.add_get("/health", handle_test)
    return app


if __name__ == "__main__":
    print(f"Rubber Duck service starting on http://localhost:{PORT}")
    print(f"Dashboard: http://localhost:{PORT}")
    print(f"Dimensions: {', '.join(DIMENSIONS.keys())}")
    print()
    web.run_app(create_app(), port=PORT, print=None)
