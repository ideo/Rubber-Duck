# Bambu Duck

A standalone, conversational rubber duck that lives next to a Bambu 3D printer.
No Mac required. The duck talks to an **ElevenAgents** (ElevenLabs's
conversational AI product, formerly "Convai") agent over WebSocket, and the
agent can query the printer's live state mid-conversation.

```
[duck ESP32-S3]  ──wss──→  [ElevenAgents]  ──webhook──→  [relay]  ──MQTT──→  [Bambu printer]
       ↑                        ↓ audio
       └────── speaker ─────────┘
```

## Pieces

| Dir | What | Status |
|---|---|---|
| [`firmware/`](firmware/) | ESP-IDF project for XIAO Seeed ESP32-S3: I2S mic, WebSocket client, I2S DAC out | scaffold — needs bench tuning |
| [`relay/`](relay/) | Python FastAPI service. Holds Bambu MQTT subscription, exposes HTTP tool endpoints for ElevenAgents Server Tool calls | v0 — verified against mock, not yet against real printer |
| [`agent/`](agent/) | ElevenAgents config (system prompt, tool schemas, voice) — source of truth since the dashboard rots | working in playground |

## How the agent gets printer-aware

ElevenAgents lets you define **Server Tools** — HTTP webhooks the LLM can call
mid-conversation. The relay exposes three:

- `GET /tools/printer_state` — current stage, percent, layer, temps, HMS codes
- `GET /tools/temperatures` — nozzle/bed/chamber subset
- `GET /tools/print_history?n=N` — last N print outcomes

When the user says "how's the dragon coming along?", the LLM calls
`get_printer_state`, gets live JSON, and replies in natural language with the
duck's voice.

## Why this is different from the rest of the repo

The Mac widget + plugin variants are all built around the model "duck reacts to
Claude Code activity over USB serial." This one doesn't need a Mac at all — it's
a self-contained appliance that talks to a printer. Hence its own top-level dir
instead of another `firmware/rubber_duck_s3_*` sibling.

See [docs/BAMBU-DUCK-API-SURVEY.md](../docs/BAMBU-DUCK-API-SURVEY.md) for the
full architectural background and risks.
