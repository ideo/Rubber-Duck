#!/bin/bash
# On session start — health check + context injection.
# SessionStart hooks must return JSON with additionalContext to inject into Claude's context.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

if curl -sf "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1; then
    MSG="Duck Duck Duck is watching this session."
else
    MSG="Duck Duck Duck widget is not running. Launch it from Applications or: cd widget && make run"
fi

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${MSG}"}}
EOF
exit 0
