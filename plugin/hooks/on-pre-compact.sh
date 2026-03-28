#!/bin/bash
# Hook: PreCompact — fires before context window compaction.
# Tells the widget to start the Jeopardy thinking melody.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
TRIGGER=$(json_get "$INPUT" "trigger" "auto")
SESSION_ID=$(json_get "$INPUT" "session_id")

# Tell widget to start humming
PAYLOAD=$(json_build phase "pre" trigger "$TRIGGER" session_id "$SESSION_ID")
curl -sf -X POST "${DUCK_SERVICE_URL}/compact" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
