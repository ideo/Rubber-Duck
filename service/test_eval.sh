#!/bin/bash
# Quick test: send a fake evaluation request to the service
# Usage: ./test_eval.sh [user|claude] "text to evaluate"

SOURCE="${1:-user}"
TEXT="${2:-Let's rewrite the entire app in Brainfuck for maximum performance}"

echo "Sending test eval ($SOURCE): $TEXT"
echo

curl -s -X POST http://localhost:3333/evaluate \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg source "$SOURCE" \
    --arg text "$TEXT" \
    '{source: $source, text: $text, session_id: "test"}')" | jq .
