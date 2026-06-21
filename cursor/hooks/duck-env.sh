#!/bin/bash
# duck-env.sh — Rubber Duck runtime config for plugin hook scripts.
# All values are hardcoded defaults matching DuckConfig.swift.
# Override any value via environment variable before sourcing.
# Zero external dependencies — uses python3 (ships with macOS) instead of jq.

# Read dynamic port from widget's state file, fall back to default
DUCK_PORT_FILE="${HOME}/Library/Application Support/DuckDuckDuck/port"
if [ -z "${DUCK_SERVICE_PORT}" ] && [ -f "$DUCK_PORT_FILE" ]; then
    DUCK_SERVICE_PORT=$(cat "$DUCK_PORT_FILE" 2>/dev/null)
fi
DUCK_SERVICE_PORT="${DUCK_SERVICE_PORT:-3333}"
DUCK_SERVICE_URL="${DUCK_SERVICE_URL:-http://localhost:${DUCK_SERVICE_PORT}}"
DUCK_TMUX_SESSION="${DUCK_TMUX_SESSION:-duck}"
DUCK_TMUX_WINDOW="${DUCK_TMUX_WINDOW:-claude}"
DUCK_VOICE="${DUCK_VOICE:-Boing}"

# --- JSON helpers (python3, no jq needed) ---

# Extract a field from JSON string. Usage: json_get "$JSON" "field" "default"
json_get() {
    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    keys = sys.argv[2].split('.')
    v = d
    for k in keys:
        v = v.get(k, None) if isinstance(v, dict) else None
        if v is None: break
    print(v if v is not None else sys.argv[3] if len(sys.argv) > 3 else '')
except: print(sys.argv[3] if len(sys.argv) > 3 else '')
" "$1" "$2" "${3:-}"
}

# Build a JSON object from key=value pairs. Usage: json_build key1 val1 key2 val2 ...
json_build() {
    python3 -c "
import json, sys
d = {}
args = sys.argv[1:]
for i in range(0, len(args), 2):
    if i+1 < len(args): d[args[i]] = args[i+1]
print(json.dumps(d))
" "$@"
}
