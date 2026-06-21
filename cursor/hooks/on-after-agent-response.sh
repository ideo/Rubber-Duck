#!/bin/bash
# Cursor hook: afterAgentResponse — fires when the Cursor agent finishes its
# turn, carrying the final assistant text. The Claude Code analogue is Stop
# (which we drive off last_assistant_message). We use afterAgentResponse rather
# than Cursor's `stop` hook because `stop` only reports a status string with no
# message text — there'd be nothing to score. Forwarded to /evaluate with
# source="claude" so the duck reacts to the agent's answer.
#
# Cursor stdin (see https://cursor.com/docs/hooks):
#   { "text": "<assistant final text>", "conversation_id", "generation_id",
#     "model", "hook_event_name": "afterAgentResponse" }
# stdout: no output fields supported — emit nothing.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

LAST_MESSAGE=$(json_get "$INPUT" "text")
SESSION_ID=$(json_get "$INPUT" "conversation_id")
REPO=$(python3 -c "
import json, sys, os
try:
    d = json.loads(sys.argv[1]); r = d.get('workspace_roots') or []
    print(os.path.basename(r[0].rstrip('/')) if r else '')
except: print('')
" "$INPUT")

# Skip empty responses
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ] || [ "$LAST_MESSAGE" = "None" ]; then
  exit 0
fi

PAYLOAD=$(json_build \
  session_id "$SESSION_ID" \
  timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  source "claude" \
  app "cursor" \
  repo "$REPO" \
  text "$LAST_MESSAGE")

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
