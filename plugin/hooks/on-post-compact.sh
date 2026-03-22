#!/bin/bash
# Hook: PostCompact — fires after context window compaction completes.
# Tells the widget to stop humming. Injects a reminder into the new context.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "auto"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Tell widget to stop humming
curl -sf -X POST "${DUCK_SERVICE_URL}/compact" \
  -H "Content-Type: application/json" \
  -d "{\"phase\":\"post\",\"trigger\":\"${TRIGGER}\",\"session_id\":\"${SESSION_ID}\"}" \
  > /dev/null 2>&1

exit 0
