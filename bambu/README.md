# Bambu Duck

A standalone, conversational rubber duck that lives next to a Bambu 3D printer.
No Mac required. The duck talks to an **ElevenAgents** (ElevenLabs's
conversational AI product, formerly "Convai") agent over WebSocket through
a small relay, and the agent can query the printer's live state
mid-conversation. The relay also pushes notifications to the duck when
the printer hits notable events (start, finish, fault), so the duck
speaks up unprompted.

```
[duck ESP32-S3]  ──wss──→  [relay (Fly.io)]  ──wss──→  [ElevenAgents]
       ↑                          │
       └────── speaker ────────── │ ──MQTT──→ [Bambu cloud broker]──→ [printer]
```

## Pieces

| Dir | What | Status |
|---|---|---|
| [`firmware/`](firmware/) | ESP-IDF project for ESP32-S3 (XIAO Seeed + custom ducky PCB variants): I2S mic + DAC out, WebSocket client, captive-portal onboarding, embedded Opus phrase playback | working — daily-driven on hardware |
| [`relay/`](relay/) | Python FastAPI service on Fly.io. Multi-tenant: per-duck Bambu MQTT subscription, ElevenAgents session bridging, post-onboarding notifications | working — deployed to `duck-duck-print.fly.dev`, runnable self-hosted |
| [`agent/`](agent/) | ElevenAgents config (system prompt, tool schemas, voice) — source of truth since the dashboard rots | working — agent template POSTs cleanly via [`DEPLOY.md`](DEPLOY.md) |

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

## Self-hosting

The runbook is [`DEPLOY.md`](DEPLOY.md). It's written for **Claude
Code as the executor** — clone the repo, `cd bambu`, run Claude
inside it, ask "deploy a bambu duck for me." The runbook walks Claude
through Fly app setup, ElevenLabs agent creation, and hand-off to
the user for chip onboarding. ~5 minutes end-to-end.

For background on the architecture and the risks accepted to ship
v1, see [`docs/BAMBU-DUCK-API-SURVEY.md`](../docs/BAMBU-DUCK-API-SURVEY.md).
