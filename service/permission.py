"""
Permission Gate — voice-gated permission approval for Claude Code actions.

Replaces the previous global variable pattern with a PermissionGate class.
"""

from __future__ import annotations

import asyncio
from typing import Optional, Tuple

from broadcast import broadcast


class PermissionGate:
    """Manages a single pending permission request.

    Flow: Claude Code → hook → POST /permission → voice ask → voice response → reply
    """

    def __init__(self):
        self._event: Optional[asyncio.Event] = None
        self._decision: Optional[str] = None
        self._suggestion_index: Optional[int] = None

    async def wait_for_decision(self, timeout: float = 30.0) -> Tuple[str, Optional[int]]:
        """Block until the widget sends a permission response, or timeout.

        Returns (decision, suggestion_index) where decision is "allow" or "deny".
        """
        self._event = asyncio.Event()
        self._decision = None
        self._suggestion_index = None

        try:
            await asyncio.wait_for(self._event.wait(), timeout=timeout)
        except asyncio.TimeoutError:
            return ("timeout", None)

        decision = self._decision if self._decision in ("allow", "deny") else "deny"
        return (decision, self._suggestion_index)

    def resolve(self, decision: str, suggestion_index: Optional[int] = None):
        """Called when the widget sends a permission response via WebSocket."""
        self._decision = decision
        self._suggestion_index = suggestion_index
        if self._event:
            self._event.set()
        print(f"[permission] Widget responded: {decision}, suggestion_index={suggestion_index}")


# Singleton gate instance
gate = PermissionGate()


def describe_suggestion(suggestion: dict) -> str:
    """Generate a short, TTS-friendly label for a permission suggestion.

    Labels must sound natural when spoken aloud — no paths, globs, or special chars.
    """
    stype = suggestion.get("type", "")
    dest = suggestion.get("destination", "session")
    scope = "for this session" if dest == "session" else "permanently"

    if stype == "addRules":
        rules = suggestion.get("rules", [])
        if rules:
            tool = rules[0].get("toolName", "this tool")
            return f"always allow {tool} {scope}"
        return f"add a rule {scope}"
    elif stype == "addDirectories":
        return f"allow this directory {scope}"
    elif stype == "setMode":
        mode = suggestion.get("mode", "")
        if mode:
            return f"switch to {mode} mode"
        return "change the permission mode"
    elif stype == "toolAlwaysAllow":
        tool = suggestion.get("toolName", "this tool")
        return f"always allow {tool}"
    elif stype == "acceptEdits":
        return "allow all file edits"

    return "apply a permission rule"
