#!/bin/bash
# duck-env.sh — Duck Duck Duck runtime config for Gemini CLI hook scripts.
# Same config as the Claude plugin hooks — both talk to the same widget.

DUCK_SERVICE_PORT="${DUCK_SERVICE_PORT:-3333}"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT}}"
