#!/bin/bash
# Hook: SessionEnd — fires when a Claude Code session terminates.
# Tells the widget the session ended so the duck can say goodbye.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Notify widget (fire-and-forget)
curl -sf -X POST "${DUCK_SERVICE_URL}/session-end" \
  -H "Content-Type: application/json" \
  -d "{\"reason\":\"${REASON}\",\"session_id\":\"${SESSION_ID}\"}" \
  > /dev/null 2>&1

exit 0
