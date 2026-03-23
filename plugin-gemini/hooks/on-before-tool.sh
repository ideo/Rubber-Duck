#!/bin/bash
# Hook: BeforeTool — fires before Gemini executes a tool.
# Equivalent to Claude Code's PermissionRequest hook.
# POSTs to the eval service and BLOCKS until voice approval or timeout.
#
# Gemini CLI stdin payload includes:
#   session_id, cwd, hook_event_name, timestamp, tool_name, tool_input
# To block: exit 2 (stderr becomes the reason) or return {"decision": "block"}
# To allow: exit 0 with empty or no JSON
# All logging goes to stderr — stdout is reserved for JSON output.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

# Extract tool info from the Gemini hook payload
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)

# Build permission request body — same format as Claude hooks
CURL_BODY=$(jq -n \
    --arg tool "$TOOL_NAME" \
    --arg input "$TOOL_INPUT" \
    --arg session "$SESSION_ID" \
    '{tool_name: $tool, tool_input: $input, session_id: $session, permission_suggestions: []}')

# POST to permission endpoint (blocks until voice response or 30s timeout)
RESPONSE=$(curl -s -X POST "${DUCK_SERVICE_URL}/permission" \
  -H "Content-Type: application/json" \
  -d "$CURL_BODY" \
  --max-time 35)

# If service unreachable, don't block — let Gemini's own UI handle it
if [ -z "$RESPONSE" ]; then
  exit 0
fi

DECISION=$(echo "$RESPONSE" | jq -r '.decision // ""')

# Exit code 2 = block/deny, stderr becomes the reason shown to the user
if [ "$DECISION" = "deny" ]; then
  echo "Denied by Duck Duck Duck voice gate" >&2
  exit 2
fi

# allow = exit 0, Gemini proceeds
exit 0
