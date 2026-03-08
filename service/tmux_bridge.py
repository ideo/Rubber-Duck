"""
tmux Bridge — inject voice commands into Claude Code CLI via tmux send-keys.
"""

import subprocess

# Configurable via CLI args (set by server.py main)
session = "duck"
pane = "claude.0"


def send_to_claude_code(text: str):
    """Send text to Claude Code via tmux send-keys."""
    target = f"{session}:{pane}"
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
