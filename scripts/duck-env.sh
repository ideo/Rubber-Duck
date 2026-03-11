#!/bin/bash
# duck-env.sh — Rubber Duck runtime config for hook scripts.
# All values are hardcoded defaults matching DuckConfig.swift.
# Override any value via environment variable before sourcing.

DUCK_SERVICE_PORT="${DUCK_SERVICE_PORT:-3333}"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT}}"
DUCK_TMUX_SESSION="${DUCK_TMUX_SESSION:-duck}"
DUCK_TMUX_WINDOW="${DUCK_TMUX_WINDOW:-claude}"
DUCK_VOICE="${DUCK_VOICE:-Boing}"
