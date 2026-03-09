#!/bin/bash
# Start the Rubber Duck eval service in the background.
# Writes PID to service/.pid for lifecycle management.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"
SERVICE_DIR="$(dirname "$SCRIPT_DIR")/service"
PID_FILE="$DUCK_PID_FILE"

# Check if already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "🦆 Service already running (PID $OLD_PID)"
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# Activate venv if present
if [ -d "$SERVICE_DIR/venv" ]; then
    source "$SERVICE_DIR/venv/bin/activate"
fi

# Start service in background
cd "$SERVICE_DIR"
nohup python3 server.py --port "$DUCK_SERVICE_PORT" "$@" > "$SERVICE_DIR/duck.log" 2>&1 &
SERVICE_PID=$!
echo "$SERVICE_PID" > "$PID_FILE"

# Wait for service to be ready
for i in $(seq 1 10); do
    if curl -s "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1; then
        echo "🦆 Service started (PID $SERVICE_PID)"
        exit 0
    fi
    sleep 0.5
done

echo "⚠️  Service started (PID $SERVICE_PID) but health check didn't respond yet"
exit 0
