#!/bin/bash
# Hook: PostCompact — fires after context window compaction completes.
# Tells the widget to stop humming. Injects a reminder into the new context.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
TRIGGER=$(json_get "$INPUT" "trigger" "auto")
SESSION_ID=$(json_get "$INPUT" "session_id")

# Tell widget to stop humming
PAYLOAD=$(json_build phase "post" trigger "$TRIGGER" session_id "$SESSION_ID")
curl -sf -X POST "${DUCK_SERVICE_URL}/compact" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null 2>&1

exit 0
