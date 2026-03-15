#!/bin/bash
# Hook: SessionStart — health check the Duck Duck Duck widget.
# Gemini equivalent of Claude's SessionStart hook.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

# Ping the widget to mark plugin connected
curl -sf "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1

exit 0
