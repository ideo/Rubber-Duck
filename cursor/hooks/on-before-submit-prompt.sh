#!/bin/bash
# Cursor hook: beforeSubmitPrompt — fires when the user submits a prompt to the
# Cursor agent, before it hits Cursor's backend. The Claude Code analogue is
# UserPromptSubmit. We forward the prompt to the duck's /evaluate endpoint with
# source="user" so the duck scores and reacts to what the user just asked.
#
# Cursor stdin (see https://cursor.com/docs/hooks):
#   { "conversation_id", "generation_id", "prompt", "attachments",
#     "hook_event_name": "beforeSubmitPrompt", "workspace_roots" }
# stdout: informational only — we don't block prompts, so emit nothing.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

PROMPT=$(json_get "$INPUT" "prompt")
SESSION_ID=$(json_get "$INPUT" "conversation_id")
# repo = basename of the workspace root, computed here (clean string).
REPO=$(python3 -c "
import json, sys, os
try:
    d = json.loads(sys.argv[1]); r = d.get('workspace_roots') or []
    print(os.path.basename(r[0].rstrip('/')) if r else '')
except: print('')
" "$INPUT")

# Skip empty prompts
if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ]; then
  exit 0
fi

PAYLOAD=$(json_build \
  session_id "$SESSION_ID" \
  timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  source "user" \
  app "cursor" \
  repo "$REPO" \
  text "$PROMPT")

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
