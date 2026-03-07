#!/bin/bash
# Hook: Stop - fires when Claude finishes responding
# Sends Claude's response (with user context) to the evaluation service

INPUT=$(cat)

LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // "false"')

# Prevent infinite loop if Stop hook re-triggers
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Skip empty responses
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ]; then
  exit 0
fi

# Try to grab the last user message from transcript for context
LAST_USER=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  LAST_USER=$(jq -r 'select(.type=="human") | .message.content' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1)
fi

PAYLOAD=$(jq -n \
  --arg session "$SESSION_ID" \
  --arg text "$LAST_MESSAGE" \
  --arg context "$LAST_USER" \
  --arg source "claude" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $session, timestamp: $timestamp, source: $source, text: $text, user_context: $context}')

curl -s -X POST http://localhost:3333/evaluate \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
