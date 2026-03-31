#!/bin/bash
# Hook: PermissionRequest - fires when Claude wants to take an action
# POSTs to the eval service and BLOCKS until voice approval or timeout.
# Returns hookSpecificOutput with behavior: "allow"/"deny" to Claude Code.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

LOG="/tmp/rubber-duck-permission.log"

# Rotate log if over 1MB
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
  tail -200 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# 1. Log hook start with timestamp
echo "========================================" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] HOOK START" >> "$LOG"

INPUT=$(cat)

# 2. Log the full INPUT received from stdin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] INPUT: $INPUT" >> "$LOG"

TOOL_NAME=$(json_get "$INPUT" "tool_name" "unknown")
TOOL_INPUT=$(json_get "$INPUT" "tool_input" "{}")
SESSION_ID=$(json_get "$INPUT" "session_id")
# Extract suggestions as raw JSON (need the array intact for the response)
PERMISSION_SUGGESTIONS=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    print(json.dumps(d.get('permission_suggestions', [])))
except: print('[]')
" "$INPUT")

# 3. Log extracted fields
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TOOL_NAME: $TOOL_NAME" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SESSION_ID: $SESSION_ID" >> "$LOG"

# 3b. Smart filtering — skip noise the user doesn't need to voice-approve
SUGGESTION_COUNT=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$PERMISSION_SUGGESTIONS")
PERMISSION_MODE=$(json_get "$INPUT" "permission_mode" "default")

# Zero suggestions + not AskUserQuestion → nothing useful to voice-ask
if [ "$SUGGESTION_COUNT" = "0" ] && [ "$TOOL_NAME" != "AskUserQuestion" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] No suggestions, not AskUserQuestion — passing through" >> "$LOG"
  echo "========================================" >> "$LOG"
  exit 0
fi

# Plan mode (except AskUserQuestion) → pass through to Claude Code's own UI
if [ "$PERMISSION_MODE" = "plan" ] && [ "$TOOL_NAME" != "AskUserQuestion" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Plan mode — passing through to Claude Code" >> "$LOG"
  echo "========================================" >> "$LOG"
  exit 0
fi

# MCP subagent tools (preview, browser automation) → pass through to Claude Code's own UI
if echo "$TOOL_NAME" | grep -q "^mcp__"; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MCP tool ($TOOL_NAME) — passing through to Claude Code" >> "$LOG"
  echo "========================================" >> "$LOG"
  exit 0
fi

# Build the permission request payload
CURL_BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'tool_name': sys.argv[1],
    'tool_input': sys.argv[2],
    'session_id': sys.argv[3],
    'permission_suggestions': json.loads(sys.argv[4])
}))
" "$TOOL_NAME" "$TOOL_INPUT" "$SESSION_ID" "$PERMISSION_SUGGESTIONS")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURL REQUEST: POST ${DUCK_SERVICE_URL}/permission" >> "$LOG"

# POST to permission endpoint (blocks until voice response or 30s timeout)
RESPONSE=$(curl -s -X POST ${DUCK_SERVICE_URL}/permission \
  -H "Content-Type: application/json" \
  -d "$CURL_BODY" \
  --max-time 35)
CURL_EXIT=$?

# 5. Log the response and curl exit code
echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURL EXIT CODE: $CURL_EXIT" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] RESPONSE: $RESPONSE" >> "$LOG"

# If service unreachable or error, don't block — let Claude Code's own UI handle it
if [ -z "$RESPONSE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] RESPONSE is empty — falling through (exit 0)" >> "$LOG"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] HOOK EXIT (empty response)" >> "$LOG"
  echo "========================================" >> "$LOG"
  exit 0
fi

# Extract decision and optional suggestion index
DECISION=$(json_get "$RESPONSE" "decision")
SUGGESTION_INDEX=$(json_get "$RESPONSE" "suggestion_index" "null")

# 6. Log the extracted decision
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DECISION: $DECISION, SUGGESTION_INDEX: $SUGGESTION_INDEX" >> "$LOG"

# Only output if we got a clear decision
if [ "$DECISION" = "allow" ] || [ "$DECISION" = "deny" ]; then
  OUTPUT=$(python3 -c "
import json, sys
decision = sys.argv[1]
suggestion_index = sys.argv[2]
suggestions = json.loads(sys.argv[3])

result = {'behavior': decision}
if suggestion_index != 'null':
    try:
        idx = int(suggestion_index) - 1  # 1-based from user
        if 0 <= idx < len(suggestions):
            result['updatedPermissions'] = [suggestions[idx]]
    except: pass

print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PermissionRequest',
        'decision': result
    }
}))
" "$DECISION" "$SUGGESTION_INDEX" "$PERMISSION_SUGGESTIONS")

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] OUTPUT (stdout): $OUTPUT" >> "$LOG"
  echo "$OUTPUT"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] NO OUTPUT — decision was not allow/deny: '$DECISION'" >> "$LOG"
fi

# 8. Log hook exit
echo "[$(date '+%Y-%m-%d %H:%M:%S')] HOOK EXIT" >> "$LOG"
echo "========================================" >> "$LOG"

exit 0
