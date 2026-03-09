#!/bin/bash
# Stop the Rubber Duck eval service gracefully.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"
SERVICE_DIR="$(dirname "$SCRIPT_DIR")/service"
PID_FILE="$DUCK_PID_FILE"

if [ ! -f "$PID_FILE" ]; then
    # Try to find and kill by port as fallback
    PIDS=$(lsof -ti:"$DUCK_SERVICE_PORT" 2>/dev/null)
    if [ -n "$PIDS" ]; then
        echo "$PIDS" | xargs kill 2>/dev/null
        echo "🦆 Service stopped (found on port $DUCK_SERVICE_PORT)"
    else
        echo "🦆 Service not running"
    fi
    exit 0
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID" 2>/dev/null
    # Wait for graceful shutdown
    for i in $(seq 1 10); do
        if ! kill -0 "$PID" 2>/dev/null; then
            break
        fi
        sleep 0.3
    done
    # Force kill if still alive
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" 2>/dev/null
    fi
    echo "🦆 Service stopped (PID $PID)"
else
    echo "🦆 Service not running (stale PID file)"
fi

rm -f "$PID_FILE"
exit 0
