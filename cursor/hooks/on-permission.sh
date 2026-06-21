#!/bin/bash
# Cursor hook: beforeShellExecution + beforeMCPExecution.
#
# This is a NON-BLOCKING NOTIFIER, not a permission gate. Cursor owns its own
# approval UI and allow-list, and Cursor's hook "ask"/"allow" responses are
# ignored anyway (only "deny" is honored) — so the duck deliberately does NOT
# influence the decision. It fires a fire-and-forget "pending" ping to the
# widget and returns instantly with NO decision, leaving Cursor's native
# approve/deny flow 100% untouched.
#
# The widget pairs this "pending" with the matching "resolved" ping from
# on-after-shell.sh: if the command runs within a short grace period it was
# auto-approved (stay silent); if it's still unresolved, Cursor is parked on its
# approve prompt waiting for the user, and the duck chirps once.
#
# Why fire-and-forget (backgrounded curl, not --max-time): Cursor BLOCKS its
# agent loop until this hook process exits. Any wait here re-freezes the very
# approve UI we're trying to leave responsive. So we detach the POST and return.
#
# Cursor stdin (see https://cursor.com/docs/hooks):
#   beforeShellExecution: { command, cwd, conversation_id, workspace_roots, ... }
#   beforeMCPExecution:   { tool_name, tool_input, conversation_id, workspace_roots, ... }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)

# Build the /activity "pending" body. Repo basename is computed HERE (clean,
# slash-free) so the server never has to parse a path back out of escaped JSON.
BODY=$(python3 -c "
import json, sys, os
try:
    d = json.loads(sys.argv[1])
except Exception:
    print('{}'); sys.exit(0)
event = d.get('hook_event_name', 'beforeShellExecution')
roots = d.get('workspace_roots') or []
repo = os.path.basename(roots[0].rstrip('/')) if roots else ''
out = {
    'state': 'pending',
    'app': 'cursor',
    'repo': repo,
    'conversation_id': d.get('conversation_id', ''),
}
if event == 'beforeMCPExecution':
    out['kind'] = 'mcp'
    out['tool'] = d.get('tool_name', '')
else:
    out['kind'] = 'shell'
    out['command'] = d.get('command', '')
print(json.dumps(out))
" "$INPUT")

# Fire-and-forget: detached subshell so the hook never waits on the POST.
# A short -m guards against a wedged connection leaving stray curls around;
# the hook's exit does not depend on it.
( curl -s -m 2 -X POST "${DUCK_SERVICE_URL}/activity" \
    -H "Content-Type: application/json" \
    -d "$BODY" >/dev/null 2>&1 & )

# No decision — return immediately so Cursor's own approval flow is untouched.
echo '{}'
exit 0
