#!/bin/bash
# duck-env.sh — shared runtime config for Duck Duck Duck Codex hooks.
# Uses python3 for JSON handling so the plugin has no jq dependency.

DUCK_PORT_FILE="${HOME}/Library/Application Support/DuckDuckDuck/port"
if [ -z "${DUCK_SERVICE_PORT}" ] && [ -f "$DUCK_PORT_FILE" ]; then
    DUCK_SERVICE_PORT=$(cat "$DUCK_PORT_FILE" 2>/dev/null)
fi
DUCK_SERVICE_PORT="${DUCK_SERVICE_PORT:-3333}"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

json_get() {
    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1] or '{}')
    keys = sys.argv[2].split('.')
    v = d
    for k in keys:
        if isinstance(v, dict):
            v = v.get(k)
        else:
            v = None
        if v is None:
            break
    if isinstance(v, (dict, list)):
        print(json.dumps(v))
    else:
        print(v if v is not None else (sys.argv[3] if len(sys.argv) > 3 else ''))
except Exception:
    print(sys.argv[3] if len(sys.argv) > 3 else '')
" "$1" "$2" "${3:-}"
}

json_build() {
    python3 -c "
import json, sys
d = {}
args = sys.argv[1:]
for i in range(0, len(args), 2):
    if i + 1 < len(args):
        d[args[i]] = args[i + 1]
print(json.dumps(d))
" "$@"
}

json_escape_string() {
    python3 -c "import json, sys; print(json.dumps(sys.argv[1]))" "$1"
}
