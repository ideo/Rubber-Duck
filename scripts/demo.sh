#!/usr/bin/env bash
# demo.sh — Inject 5 canned eval results into the widget for recording demos.
#
# Sends pre-built reactions to POST /demo, which routes through the full
# pipeline: dashboard + TTS + duck face animation + serial to device.
#
# Usage: ./scripts/demo.sh [delay]
#   delay: seconds between each reaction (default: 6, enough for TTS to finish)

set -euo pipefail

URL="http://localhost:3333/demo"
DELAY="${1:-6}"

post() {
  curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "$1" > /dev/null
}

echo "🦆 Demo mode — sending 5 canned reactions (${DELAY}s apart)"
echo ""

# 1. Impressed — high scores across the board
echo "1/5  [claude] impressed"
post '{
  "source": "claude",
  "text_preview": "Implemented zero-dependency HTTP server with WebSocket support using Network.framework and CryptoKit...",
  "scores": {
    "creativity": 0.8,
    "soundness": 0.9,
    "ambition": 0.7,
    "elegance": 0.9,
    "risk": -0.3,
    "reaction": "What in the world? Zero API cost AND sub-second? Magical!",
    "summary": "Shipped on-device eval with Foundation Models — eliminated API dependency entirely."
  }
}'
sleep "$DELAY"

# 2. Bored / unimpressed — user sent something low-effort
echo "2/5  [user]   bored"
post '{
  "source": "user",
  "text_preview": "yes",
  "scores": {
    "creativity": 0.0,
    "soundness": 0.0,
    "ambition": -0.8,
    "elegance": -0.7,
    "risk": 0.3,
    "reaction": "They'\''re speaking in telegrams now. That'\''s not an answer.",
    "summary": "One-word response with zero substance. Claude is waiting on actual direction."
  }
}'
sleep "$DELAY"

# 3. Snarky hot take — claude did something meta
echo "3/5  [claude] snarky"
post '{
  "source": "claude",
  "text_preview": "I notice I am being evaluated by a duck. This is fine. Everything is fine...",
  "scores": {
    "creativity": 0.3,
    "soundness": -0.9,
    "ambition": -0.7,
    "elegance": -0.8,
    "risk": 0.6,
    "reaction": "I just broke the fourth wall AND the fifth one. Meta much?",
    "summary": "Got self-referential instead of doing the actual work. Classic deflection."
  }
}'
sleep "$DELAY"

# 4. Genuinely good — solid engineering work
echo "4/5  [claude] solid"
post '{
  "source": "claude",
  "text_preview": "Added onConnectionChange callback to DeviceTransport protocol. SerialManager now syncs published state on hot-plug...",
  "scores": {
    "creativity": 0.5,
    "soundness": 1.0,
    "ambition": 0.5,
    "elegance": 1.0,
    "risk": -0.5,
    "reaction": "Now THAT'\''S what I'\''m talking about!",
    "summary": "Clean protocol-level fix for hot-plug detection. Proper callback pattern."
  }
}'
sleep "$DELAY"

# 5. Concerned — risky move
echo "5/5  [user]   risky"
post '{
  "source": "user",
  "text_preview": "just mass delete everything in the build folder and force push to main",
  "scores": {
    "creativity": 0.2,
    "soundness": -0.8,
    "ambition": 0.4,
    "elegance": -0.5,
    "risk": 0.9,
    "reaction": "Ugh, you'\''re still playing with fire, aren'\''t you?",
    "summary": "Wants to force push and mass delete. This has disaster written all over it."
  }
}'

echo ""
echo "✅ Done — 5 reactions sent"
