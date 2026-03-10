#!/bin/bash
# duck-env.sh — Source this to load Rubber Duck runtime config.
# Provides DUCK_SERVICE_PORT, DUCK_SERVICE_URL, DUCK_TMUX_SESSION, etc.
# Reads from ~/.duck/config (written by the widget on launch).
# Falls back to hardcoded defaults if config doesn't exist yet.

DUCK_CONFIG_FILE="${HOME}/.duck/config"

if [ -f "$DUCK_CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$DUCK_CONFIG_FILE"
fi

# Ensure all vars have defaults (match DuckConfig.swift)
DUCK_SERVICE_PORT="${DUCK_SERVICE_PORT:-3333}"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT}}"
DUCK_TMUX_SESSION="${DUCK_TMUX_SESSION:-duck}"
DUCK_TMUX_WINDOW="${DUCK_TMUX_WINDOW:-claude}"
DUCK_PID_FILE="${DUCK_PID_FILE:-${HOME}/.duck/duck.pid}"
DUCK_VOICE="${DUCK_VOICE:-Boing}"
