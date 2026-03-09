#!/bin/bash
# Check if the Rubber Duck eval service (embedded in widget) is running.
# The widget IS the server — there's nothing to start here.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

if curl -s "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1; then
    echo "🦆 Service running (widget)"
    exit 0
else
    echo "❌ Service not running. Start the widget:"
    echo "   cd widget && make run"
    exit 1
fi
