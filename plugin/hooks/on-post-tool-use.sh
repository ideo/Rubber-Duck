#!/bin/bash
# Hook: PostToolUse — fires after a tool succeeds.
# Used as a lightweight signal to clear the permission-pending state
# when the user approved via CLI instead of voice.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

# Skip sub-agent tool uses. PostToolUse fires for every tool a sub-agent
# runs — without this filter, a busy agent team would flood /permission-clear
# and could prematurely wipe the duck's "permission pending" state during a
# real main-session voice prompt. Main-session payloads omit `agent_id`.
INPUT=$(cat)
AGENT_ID=$(json_get "$INPUT" "agent_id" "")
[ -n "$AGENT_ID" ] && exit 0

# Fire-and-forget — just ping the widget to clear permission state
curl -sf -X POST "${DUCK_SERVICE_URL}/permission-clear" \
  > /dev/null 2>&1

exit 0
