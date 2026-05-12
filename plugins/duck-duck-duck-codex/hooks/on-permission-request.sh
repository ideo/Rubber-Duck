#!/bin/bash
# Hook: PermissionRequest — ask Duck Duck Duck for voice approval.
# Codex supports allow/deny decisions. If the widget is unavailable or times out,
# stay silent so Codex's normal approval UI handles the request.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

TOOL_NAME=$(json_get "$INPUT" "tool_name" "unknown")
TOOL_INPUT=$(json_get "$INPUT" "tool_input" "{}")
SESSION_ID=$(json_get "$INPUT" "session_id")
TURN_ID=$(json_get "$INPUT" "turn_id")

CURL_BODY=$(python3 -c "
import json, sys
try:
    tool_input = json.loads(sys.argv[2])
except Exception:
    tool_input = sys.argv[2]
print(json.dumps({
    'tool_name': sys.argv[1],
    'tool_input': tool_input,
    'session_id': sys.argv[3],
    'turn_id': sys.argv[4],
    'agent': 'codex',
    'permission_suggestions': []
}))
" "$TOOL_NAME" "$TOOL_INPUT" "$SESSION_ID" "$TURN_ID")

RESPONSE=$(curl -s -X POST "${DUCK_SERVICE_URL}/permission" \
  -H "Content-Type: application/json" \
  -d "$CURL_BODY" \
  --max-time 35)

if [ -z "$RESPONSE" ]; then
    exit 0
fi

DECISION=$(json_get "$RESPONSE" "decision")

if [ "$DECISION" = "allow" ]; then
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}
EOF
elif [ "$DECISION" = "deny" ]; then
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied by Duck Duck Duck voice approval."}}}
EOF
fi

exit 0
