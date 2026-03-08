"""
Broadcast — WebSocket client management and message broadcasting.
"""

from __future__ import annotations

import json
from typing import Set

from aiohttp import web

# All connected WebSocket clients
connected_ws: Set[web.WebSocketResponse] = set()


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
