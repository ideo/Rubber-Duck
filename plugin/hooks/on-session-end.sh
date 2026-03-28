#!/bin/bash
# Hook: SessionEnd — fires when a Claude Code session terminates.
# Tells the widget the session ended so the duck can say goodbye.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
REASON=$(json_get "$INPUT" "reason" "unknown")
SESSION_ID=$(json_get "$INPUT" "session_id")

# Notify widget (fire-and-forget)
PAYLOAD=$(json_build reason "$REASON" session_id "$SESSION_ID")
curl -sf -X POST "${DUCK_SERVICE_URL}/session-end" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
