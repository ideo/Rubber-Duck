#!/bin/bash
# Cursor hook: afterShellExecution — observe-only.
#
# Fires after a shell command actually runs (i.e. after any approval). We pair
# it with the "pending" ping from on-permission.sh: this "resolved" ping cancels
# the duck's pending-timer for that command, so an auto-approved (fast) command
# never chirps. Keyed on conversation_id + command, which both events carry.
#
# Fire-and-forget and non-blocking, same as the pending side.
#
# Cursor stdin: { command, output, duration, sandbox, conversation_id, ... }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

BODY=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print('{}'); sys.exit(0)
print(json.dumps({
    'state': 'resolved',
    'kind': 'shell',
    'conversation_id': d.get('conversation_id', ''),
    'command': d.get('command', ''),
}))
" "$INPUT")

( curl -s -m 2 -X POST "${DUCK_SERVICE_URL}/activity" \
    -H "Content-Type: application/json" \
    -d "$BODY" >/dev/null 2>&1 & )

exit 0
