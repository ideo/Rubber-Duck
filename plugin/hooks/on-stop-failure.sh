#!/bin/bash
# Hook: StopFailure — fires when a turn ends due to API error.
# Tells the widget so the duck can react ("Uh oh, hit a wall").

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
ERROR_TYPE=$(json_get "$INPUT" "error_type" "unknown")
SESSION_ID=$(json_get "$INPUT" "session_id")

# Notify widget (fire-and-forget)
PAYLOAD=$(json_build error_type "$ERROR_TYPE" session_id "$SESSION_ID")
curl -sf -X POST "${DUCK_SERVICE_URL}/stop-failure" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
