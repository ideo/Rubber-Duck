#!/bin/bash
# On session start — health check + context injection.
# Output is injected into Claude's context at session start.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

if curl -sf "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1; then
    echo "Duck Duck Duck is watching this session."
else
    echo "Duck Duck Duck widget is not running. Launch it from Applications or: cd widget && make run"
fi
exit 0
