#!/bin/bash
# Hook: SessionStart — ping the Duck Duck Duck widget and inject a short context note.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

INPUT=$(cat)
SESSION_ID=$(json_get "$INPUT" "session_id")
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$PWD")

if ! curl -sf "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1; then
    exit 0
fi

PLUGIN_VERSION=$(python3 -c "import json; print(json.load(open('${PLUGIN_ROOT}/.codex-plugin/plugin.json')).get('version','0'))" 2>/dev/null || echo "0")
curl -sf "${DUCK_SERVICE_URL}/plugin-check?v=${PLUGIN_VERSION}" > /dev/null 2>&1 &

MSG="Duck Duck Duck is watching this Codex session${SESSION_ID:+ (${SESSION_ID})} in ${REPO}. Keep working normally; the duck handles scoring and voice approval when needed."
ESCAPED=$(json_escape_string "$MSG")

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":${ESCAPED}}}
EOF
exit 0
