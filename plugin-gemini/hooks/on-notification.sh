#!/bin/bash
# Hook: Notification — fires when Gemini CLI shows a notification.
# We only care about ToolPermission notifications — when Gemini pauses for user approval.
# This is observe-only: we can't relay decisions back, so the widget just
# speaks an alert and the user handles approval in the terminal themselves.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

# Only handle ToolPermission notifications
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""' 2>/dev/null)
if [ "$NOTIFICATION_TYPE" != "ToolPermission" ]; then
  exit 0
fi

# Extract a useful tool name for logging
TOOL_NAME=$(echo "$INPUT" | jq -r '.details.rootCommand // .details.title // "tool"' 2>/dev/null)

# POST to widget — just an alert, no decision relay
PAYLOAD=$(jq -n --arg tool "$TOOL_NAME" '{tool_name: $tool}')

curl -s -X POST "${DUCK_SERVICE_URL}/permission-gemini" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1 &

exit 0
