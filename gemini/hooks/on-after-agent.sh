#!/bin/bash
# Hook: AfterAgent — fires when Gemini finishes responding.
# Equivalent to Claude Code's Stop hook.
# Sends the agent's response to the Duck Duck Duck evaluation service.
#
# Gemini CLI stdin payload includes:
#   session_id, cwd, hook_event_name, timestamp, prompt, prompt_response
# All logging goes to stderr — stdout is reserved for JSON output.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

# Extract the agent's response text
LAST_MESSAGE=$(echo "$INPUT" | jq -r '
  .prompt_response //
  ""
' 2>/dev/null)

# Get the user's prompt for context
LAST_USER=$(echo "$INPUT" | jq -r '
  .prompt //
  ""
' 2>/dev/null)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)

# Skip empty responses
if [ -z "$LAST_MESSAGE" ] || [ "$LAST_MESSAGE" = "null" ]; then
  exit 0
fi

# Truncate long responses to first 4000 chars for eval
LAST_MESSAGE=$(echo "$LAST_MESSAGE" | head -c 4000)
LAST_USER=$(echo "$LAST_USER" | head -c 2000)

# POST to Duck Duck Duck widget (fire and forget)
# source is "claude" to match the widget's eval pipeline — it scores AI responses
# the same regardless of which AI produced them.
PAYLOAD=$(jq -n \
  --arg session "$SESSION_ID" \
  --arg text "$LAST_MESSAGE" \
  --arg context "$LAST_USER" \
  --arg source "claude" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $session, timestamp: $timestamp, source: $source, text: $text, user_context: $context}')

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
