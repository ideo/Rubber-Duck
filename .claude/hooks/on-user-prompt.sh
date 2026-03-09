#!/bin/bash
# Hook: UserPromptSubmit - fires when user hits enter
# Sends the user's prompt to the evaluation service

[ -f "${HOME}/.duck/config" ] && source "${HOME}/.duck/config"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT:-3333}}"

INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Skip empty prompts
if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ]; then
  exit 0
fi

PAYLOAD=$(jq -n \
  --arg session "$SESSION_ID" \
  --arg text "$PROMPT" \
  --arg source "user" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $session, timestamp: $timestamp, source: $source, text: $text}')

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
