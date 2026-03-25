#!/bin/bash
# duck-env.sh — Rubber Duck runtime config for hook scripts.
# All values are hardcoded defaults matching DuckConfig.swift.
# Override any value via environment variable before sourcing.

# Read dynamic port from widget's state file, fall back to default
DUCK_PORT_FILE="${HOME}/Library/Application Support/DuckDuckDuck/port"
if [ -z "${DUCK_SERVICE_PORT}" ] && [ -f "$DUCK_PORT_FILE" ]; then
    DUCK_SERVICE_PORT=$(cat "$DUCK_PORT_FILE" 2>/dev/null)
fi
DUCK_SERVICE_PORT="${DUCK_SERVICE_PORT:-3333}"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT}}"
DUCK_TMUX_SESSION="${DUCK_TMUX_SESSION:-duck}"
DUCK_TMUX_WINDOW="${DUCK_TMUX_WINDOW:-claude}"
DUCK_VOICE="${DUCK_VOICE:-Boing}"
