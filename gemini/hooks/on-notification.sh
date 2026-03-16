#!/bin/bash
# Hook: Notification — fires when Gemini CLI shows a notification.
# We only care about ToolPermission notifications — when Gemini pauses for user approval.
# This is observe-only: we can't block or return a decision.
# Instead, we POST to the widget, which speaks the question, listens for voice,
# and uses TmuxBridge to type y/n into Gemini's tmux pane.
#
# Gemini CLI stdin payload includes:
#   session_id, cwd, hook_event_name, timestamp, notification_type, message, tool_name, tool_input
# All logging goes to stderr — stdout is reserved for JSON output.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

# Only handle ToolPermission notifications
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""' 2>/dev/null)
if [ "$NOTIFICATION_TYPE" != "ToolPermission" ]; then
  exit 0
fi

# Extract tool info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""' 2>/dev/null)

# Detect tmux pane — Gemini is running in the terminal that launched the hook
TMUX_TARGET="${TMUX_PANE:-}"
if [ -z "$TMUX_TARGET" ] && [ -n "$TMUX" ]; then
  # Extract pane from TMUX env var (format: /tmp/tmux-xxx/default,session,pane)
  TMUX_TARGET=$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)
fi

# POST to widget — fire and forget, widget handles voice + tmux async
PAYLOAD=$(jq -n \
    --arg tool "$TOOL_NAME" \
    --arg input "$TOOL_INPUT" \
    --arg session "$SESSION_ID" \
    --arg message "$MESSAGE" \
    --arg tmux_target "$TMUX_TARGET" \
    '{tool_name: $tool, tool_input: $input, session_id: $session, message: $message, tmux_target: $tmux_target}')

curl -s -X POST "${DUCK_SERVICE_URL}/permission-gemini" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1 &

exit 0
