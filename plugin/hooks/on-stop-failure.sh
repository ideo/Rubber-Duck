#!/bin/bash
# Hook: StopFailure — fires when a turn ends due to API error.
# Tells the widget so the duck can react ("Uh oh, hit a wall").

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
ERROR_TYPE=$(echo "$INPUT" | jq -r '.error_type // "unknown"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Notify widget (fire-and-forget)
curl -sf -X POST "${DUCK_SERVICE_URL}/stop-failure" \
  -H "Content-Type: application/json" \
  -d "{\"error_type\":\"${ERROR_TYPE}\",\"session_id\":\"${SESSION_ID}\"}" \
  > /dev/null 2>&1

exit 0
