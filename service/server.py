"""
Rubber Duck Evaluation Service — entrypoint.

Receives Claude Code hook payloads, evaluates them using Claude API,
and broadcasts results via WebSocket to the widget and dashboards.
"""

import argparse
import os
import pathlib
import signal
import sys

from dotenv import load_dotenv

# Load .env from service directory (before any module reads env vars)
load_dotenv(pathlib.Path(__file__).parent / ".env", override=True)

from aiohttp import web

import duck_config
import tmux_bridge
from routes import create_app

# --- Config ---
PORT = duck_config.port
PID_PATH = duck_config.pid_file


# --- PID / Signal ---

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


# --- Main ---

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rubber Duck Evaluation Service")
    parser.add_argument("--tmux-session", default=duck_config.tmux_session, help="tmux session name for voice bridge")
    parser.add_argument("--tmux-pane", default=f"{duck_config.tmux_window}.0", help="tmux pane for Claude Code input")
    parser.add_argument("--port", type=int, default=PORT, help="HTTP server port")
    args = parser.parse_args()

    PORT = args.port
    tmux_bridge.session = args.tmux_session
    tmux_bridge.pane = args.tmux_pane

    # Register signal handlers
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    # Write PID file
    write_pid()

    print("=" * 50)
    print("  RUBBER DUCK — Evaluation Service")
    print(f"  Dashboard:  http://localhost:{PORT}")
    print(f"  3D Viewer:  http://localhost:{PORT}/viewer")
    print(f"  tmux:       {tmux_bridge.session}:{tmux_bridge.pane}")
    print("=" * 50)
    print()
    print("  Speech + Serial owned by widget app.")
    print("  Start widget: cd widget && make run")
    print()

    web.run_app(create_app(), port=PORT, print=None)

    # Cleanup
    cleanup_pid()
