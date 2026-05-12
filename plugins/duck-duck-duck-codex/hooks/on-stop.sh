#!/bin/bash
# Hook: Stop — score Codex's last assistant response.
# Stop hooks should emit valid JSON on stdout, so no-op cases return {}.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
LAST_MESSAGE=$(json_get "$INPUT" "last_assistant_message")
SESSION_ID=$(json_get "$INPUT" "session_id")
TURN_ID=$(json_get "$INPUT" "turn_id")

if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ] || [ "$LAST_MESSAGE" = "None" ]; then
    echo "{}"
    exit 0
fi

PAYLOAD=$(json_build \
  session_id "$SESSION_ID" \
  turn_id "$TURN_ID" \
  agent "codex" \
  timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  source "claude" \
  text "$LAST_MESSAGE")

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

echo "{}"
exit 0
