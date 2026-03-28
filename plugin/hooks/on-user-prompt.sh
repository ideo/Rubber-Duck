#!/bin/bash
# Hook: UserPromptSubmit - fires when user hits enter
# Sends the user's prompt to the evaluation service

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

PROMPT=$(json_get "$INPUT" "prompt")
SESSION_ID=$(json_get "$INPUT" "session_id")

# Skip empty prompts
if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ]; then
  exit 0
fi

PAYLOAD=$(json_build \
  session_id "$SESSION_ID" \
  timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  source "user" \
  text "$PROMPT")

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
