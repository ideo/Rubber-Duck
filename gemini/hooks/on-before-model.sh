#!/bin/bash
# Hook: BeforeModel — fires before Gemini sends a request to the LLM.
# Equivalent to Claude Code's UserPromptSubmit.
# Sends the user's prompt to the Duck Duck Duck evaluation service.
#
# Gemini CLI stdin payload includes:
#   session_id, cwd, hook_event_name, timestamp, llm_request
# All logging goes to stderr — stdout is reserved for JSON output.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

# Extract the user's latest prompt from the LLM request.
# Gemini CLI uses .llm_request.messages[] with {role, content} (content is a string).
PROMPT=$(echo "$INPUT" | jq -r '
  [.llm_request.messages[] | select(.role == "user")] | last | .content // ""
' 2>/dev/null)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)

# Skip empty prompts
if [ -z "$PROMPT" ] || [ "$PROMPT" = "null" ]; then
  exit 0
fi

# POST to Duck Duck Duck widget (fire and forget, all output to stderr)
PAYLOAD=$(jq -n \
  --arg session "$SESSION_ID" \
  --arg text "$PROMPT" \
  --arg source "user" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $session, timestamp: $timestamp, source: $source, text: $text}')

curl -s -X POST "${DUCK_SERVICE_URL}/evaluate" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
