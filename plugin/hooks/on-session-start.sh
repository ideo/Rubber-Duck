#!/bin/bash
# On session start — health check + context injection with smart greeting.
# SessionStart hooks must return JSON with additionalContext to inject into Claude's context.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/duck-env.sh"

STATE_DIR="${HOME}/Library/Application Support/DuckDuckDuck"
LAST_SESSION_FILE="${STATE_DIR}/last-session"

# --- Gather context ---

HOUR=$(date +%H)
DOW=$(date +%u)  # 1=Monday, 7=Sunday
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$PWD")

# Time since last session
MINUTES_SINCE=""
if [ -f "$LAST_SESSION_FILE" ]; then
    LAST_TS=$(cat "$LAST_SESSION_FILE" 2>/dev/null)
    NOW_TS=$(date +%s)
    if [ -n "$LAST_TS" ] && [ "$LAST_TS" -gt 0 ] 2>/dev/null; then
        DIFF=$((NOW_TS - LAST_TS))
        MINUTES_SINCE=$((DIFF / 60))
    fi
fi

# Write current timestamp
mkdir -p "$STATE_DIR"
date +%s > "$LAST_SESSION_FILE"

# --- Time of day ---
if [ "$HOUR" -lt 6 ]; then
    TIME_VIBE="late_night"
elif [ "$HOUR" -lt 12 ]; then
    TIME_VIBE="morning"
elif [ "$HOUR" -lt 17 ]; then
    TIME_VIBE="afternoon"
elif [ "$HOUR" -lt 21 ]; then
    TIME_VIBE="evening"
else
    TIME_VIBE="night"
fi

# --- Recency ---
if [ -z "$MINUTES_SINCE" ]; then
    RECENCY="first_ever"
elif [ "$MINUTES_SINCE" -lt 5 ]; then
    RECENCY="back_immediately"
elif [ "$MINUTES_SINCE" -lt 60 ]; then
    RECENCY="recent"
elif [ "$MINUTES_SINCE" -lt 1440 ]; then
    HOURS_SINCE=$((MINUTES_SINCE / 60))
    RECENCY="hours_away_${HOURS_SINCE}h"
else
    DAYS_SINCE=$((MINUTES_SINCE / 1440))
    RECENCY="days_away_${DAYS_SINCE}d"
fi

# --- Check widget ---

# If widget isn't running, stay completely silent — don't inject anything into Claude's context
if ! curl -sf "${DUCK_SERVICE_URL}/health" > /dev/null 2>&1; then
    exit 0
fi

MSG="Duck Duck Duck is watching this session. Time: ${TIME_VIBE}. Recency: ${RECENCY}. Greet the user with personality — pick a tone that fits the context. Be brief (one sentence). Examples by vibe: late_night: 'Burning the midnight oil, huh?' / morning+first_ever: 'First time! Let's see what you've got.' / back_immediately: 'Miss me already?' / recent: 'Back so soon — what broke?' / hours_away: 'Been a minute. What are we getting into?' / days_away: 'Long time no quack.' / friday evening: 'Friday night coding? Respect.' Do NOT use these examples verbatim — improvise something fresh each time."

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"${MSG}"}}
EOF
exit 0
