#!/bin/bash
# Hook: Stop - fires when Claude finishes responding
# Sends Claude's response (with user context) to the evaluation service

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

LAST_MESSAGE=$(json_get "$INPUT" "last_assistant_message")
SESSION_ID=$(json_get "$INPUT" "session_id")
TRANSCRIPT_PATH=$(json_get "$INPUT" "transcript_path")
STOP_HOOK_ACTIVE=$(json_get "$INPUT" "stop_hook_active" "false")

# Prevent infinite loop if Stop hook re-triggers
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# If last_assistant_message is missing, read from transcript JSONL
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ] || [ "$LAST_MESSAGE" = "None" ]; then
  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    LAST_MESSAGE=$(python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    for line in reversed(f.readlines()):
        try:
            entry = json.loads(line.strip())
            if entry.get('type') == 'assistant':
                content = entry.get('message', {}).get('content', '')
                if isinstance(content, list):
                    texts = [b.get('text','') for b in content if b.get('type')=='text']
                    print(' '.join(texts))
                elif isinstance(content, str):
                    print(content)
                sys.exit(0)
        except: continue
" "$TRANSCRIPT_PATH" 2>/dev/null)
  fi
fi

# Skip empty responses
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ] || [ "$LAST_MESSAGE" = "None" ]; then
  exit 0
fi

# Try to grab the last user message from transcript for context
LAST_USER=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  LAST_USER=$(python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    for line in reversed(f.readlines()):
        try:
            entry = json.loads(line.strip())
            if entry.get('type') == 'human':
                content = entry.get('message', {}).get('content', '')
                if isinstance(content, list):
                    texts = [b.get('text','') for b in content if b.get('type')=='text']
                    print(' '.join(texts))
                elif isinstance(content, str):
                    print(content)
                sys.exit(0)
        except: continue
" "$TRANSCRIPT_PATH" 2>/dev/null)
fi

PAYLOAD=$(json_build \
  session_id "$SESSION_ID" \
  timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  source "claude" \
  text "$LAST_MESSAGE" \
  user_context "$LAST_USER")

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
