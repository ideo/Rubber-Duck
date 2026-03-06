#!/bin/bash
# Hook: PermissionRequest - fires when Claude wants to take an action
# POSTs to the eval service and BLOCKS until voice approval or timeout.
# Returns {"decision": "allow"} or {"decision": "deny"} to Claude Code.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // "{}"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# POST to permission endpoint (blocks until voice response or 30s timeout)
RESPONSE=$(curl -s -X POST http://localhost:3333/permission \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg tool "$TOOL_NAME" \
    --arg input "$TOOL_INPUT" \
    --arg session "$SESSION_ID" \
    '{tool_name: $tool, tool_input: $input, session_id: $session}')" \
  --max-time 35)

# If service unreachable or error, don't block — let Claude Code's own UI handle it
if [ -z "$RESPONSE" ]; then
  exit 0
fi

# Extract decision
DECISION=$(echo "$RESPONSE" | jq -r '.decision // ""')

# Only output if we got a clear decision
if [ "$DECISION" = "allow" ] || [ "$DECISION" = "deny" ]; then
  echo "{\"decision\": \"$DECISION\"}"
fi

exit 0
