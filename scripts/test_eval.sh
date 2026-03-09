#!/bin/bash
# Quick test: send a fake evaluation request to the service
# Usage: ./test_eval.sh [user|claude] "text to evaluate"

DUCK_CONFIG_FILE="${HOME}/.duck/config"
[ -f "$DUCK_CONFIG_FILE" ] && source "$DUCK_CONFIG_FILE"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT:-3333}}"

SOURCE="${1:-user}"
TEXT="${2:-Let's rewrite the entire app in Brainfuck for maximum performance}"

echo "Sending test eval ($SOURCE): $TEXT"
echo

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg source "$SOURCE" \
    --arg text "$TEXT" \
    '{source: $source, text: $text, session_id: "test"}')" | jq .
