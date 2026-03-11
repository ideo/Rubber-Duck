#!/bin/bash
# Hook: Stop - fires when Claude finishes responding
# Sends Claude's response (with user context) to the evaluation service

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // "false"')

# Prevent infinite loop if Stop hook re-triggers
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# If last_assistant_message is missing, read from transcript JSONL
# Content can be a string or array of content blocks — handle both in one jq pass
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ]; then
  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    LAST_MESSAGE=$(tail -r "$TRANSCRIPT_PATH" \
      | jq -r 'select(.type=="assistant") | .message.content | if type=="array" then [.[] | select(.type=="text") | .text] | join(" ") elif type=="string" then . else empty end' 2>/dev/null \
      | head -1)
  fi
fi

# Skip empty responses
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ]; then
  exit 0
fi

# Try to grab the last user message from transcript for context
LAST_USER=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  LAST_USER=$(tail -r "$TRANSCRIPT_PATH" \
    | jq -r 'select(.type=="human") | .message.content | if type=="array" then [.[] | select(.type=="text") | .text] | join(" ") elif type=="string" then . else empty end' 2>/dev/null \
    | head -1)
fi

PAYLOAD=$(jq -n \
  --arg session "$SESSION_ID" \
  --arg text "$LAST_MESSAGE" \
  --arg context "$LAST_USER" \
  --arg source "claude" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $session, timestamp: $timestamp, source: $source, text: $text, user_context: $context}')

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
