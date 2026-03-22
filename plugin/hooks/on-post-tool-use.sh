#!/bin/bash
# Hook: PostToolUse — fires after a tool succeeds.
# Used as a lightweight signal to clear the permission-pending state
# when the user approved via CLI instead of voice.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

# Fire-and-forget — just ping the widget to clear permission state
curl -sf -X POST "${DUCK_SERVICE_URL}/permission-clear" \
  > /dev/null 2>&1

exit 0
