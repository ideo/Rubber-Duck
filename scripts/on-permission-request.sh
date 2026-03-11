#!/bin/bash
# Hook: PermissionRequest - fires when Claude wants to take an action
# POSTs to the eval service and BLOCKS until voice approval or timeout.
# Returns hookSpecificOutput with behavior: "allow"/"deny" to Claude Code.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

LOG="/tmp/rubber-duck-permission.log"

# 1. Log hook start with timestamp
echo "========================================" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] HOOK START" >> "$LOG"

INPUT=$(cat)

# 2. Log the full INPUT received from stdin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] INPUT: $INPUT" >> "$LOG"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // "{}"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
PERMISSION_SUGGESTIONS=$(echo "$INPUT" | jq -c '.permission_suggestions // []')

# 3. Log extracted fields
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TOOL_NAME: $TOOL_NAME" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] TOOL_INPUT: $TOOL_INPUT" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SESSION_ID: $SESSION_ID" >> "$LOG"

# 4. Log the curl request being made
CURL_BODY=$(jq -n \
    --arg tool "$TOOL_NAME" \
    --arg input "$TOOL_INPUT" \
    --arg session "$SESSION_ID" \
    --argjson suggestions "$PERMISSION_SUGGESTIONS" \
    '{tool_name: $tool, tool_input: $input, session_id: $session, permission_suggestions: $suggestions}')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURL REQUEST: POST ${DUCK_SERVICE_URL}/permission" >> "$LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURL BODY: $CURL_BODY" >> "$LOG"

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

# Extract decision and optional suggestion index (-1 = deny, 0 = allow once, 1+ = suggestion[index-1])
DECISION=$(echo "$RESPONSE" | jq -r '.decision // ""')
SUGGESTION_INDEX=$(echo "$RESPONSE" | jq -r '.suggestion_index // "null"')

# 6. Log the extracted decision
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DECISION: $DECISION, SUGGESTION_INDEX: $SUGGESTION_INDEX" >> "$LOG"

# Only output if we got a clear decision
# Claude Code expects: {"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow|deny", "updatedPermissions": {...}}}}
if [ "$DECISION" = "allow" ] || [ "$DECISION" = "deny" ]; then
  SUGGESTION_COUNT=$(echo "$PERMISSION_SUGGESTIONS" | jq 'length')

  if [ "$SUGGESTION_INDEX" != "null" ] && [ "$SUGGESTION_INDEX" -gt "0" ] 2>/dev/null \
      && [ "$SUGGESTION_COUNT" -gt "0" ]; then
    # Use the suggestion at index-1 (1-based from user)
    IDX=$((SUGGESTION_INDEX - 1))
    SELECTED=$(echo "$PERMISSION_SUGGESTIONS" | jq -c ".[$IDX]")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applying suggestion[$IDX]: $SELECTED" >> "$LOG"
    OUTPUT=$(jq -n \
      --arg behavior "$DECISION" \
      --argjson perms "$SELECTED" \
      '{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": $behavior, "updatedPermissions": $perms}}}')
  else
    OUTPUT=$(jq -n --arg behavior "$DECISION" \
      '{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": $behavior}}}')
  fi
  # 7. Log the final output being sent to stdout
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] OUTPUT (stdout): $OUTPUT" >> "$LOG"
  echo "$OUTPUT"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] NO OUTPUT — decision was not allow/deny: '$DECISION'" >> "$LOG"
fi

# 8. Log hook exit
echo "[$(date '+%Y-%m-%d %H:%M:%S')] HOOK EXIT" >> "$LOG"
echo "========================================" >> "$LOG"

exit 0
