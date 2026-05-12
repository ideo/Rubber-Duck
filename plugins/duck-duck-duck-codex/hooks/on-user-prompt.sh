#!/bin/bash
# Hook: UserPromptSubmit — score the user's prompt when it is submitted to Codex.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
PROMPT=$(json_get "$INPUT" "prompt")
SESSION_ID=$(json_get "$INPUT" "session_id")
TURN_ID=$(json_get "$INPUT" "turn_id")

if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ] || [ "$PROMPT" = "None" ]; then
    exit 0
fi

PAYLOAD=$(json_build \
  session_id "$SESSION_ID" \
  turn_id "$TURN_ID" \
  agent "codex" \
  timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  source "user" \
  text "$PROMPT")

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
