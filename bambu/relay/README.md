# Bambu Relay

Bridge between an ElevenLabs Convai agent and a Bambu printer's MQTT broker.

The duck (ESP32-S3) opens a WebSocket to Convai. The Convai LLM, mid-conversation,
calls tools defined in the Convai dashboard — those tools are HTTP webhooks
pointing at this relay. The relay holds the MQTT subscription and answers.

```
duck ──wss──→ ElevenLabs Convai ──webhook──→ this relay ──MQTT──→ Bambu printer
```

## Run

```bash
cd relay
cp .env.example .env   # fill in printer IP, access code, serial
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8088
```

Expose to Convai with `ngrok http 8088` (or deploy somewhere with a public URL).

## Convai agent setup

In the Convai dashboard, add three Webhook tools pointing at this relay:

| Tool name | Method | URL |
|---|---|---|
| `get_printer_state` | GET | `https://<your-relay>/tools/printer_state` |
| `get_print_history` | GET | `https://<your-relay>/tools/print_history?n={n}` |
| `get_temperatures` | GET | `https://<your-relay>/tools/temperatures` |

System prompt suggestion: "You are a rubber duck companion sitting next to a 3D
printer. You have tools to check the printer's live state. Be concise, a little
snarky, helpful. Don't list raw JSON — translate to natural language."

## What's NOT in v0

- No `pause_print` / destructive tools — auth story not figured out
- No persistence of print history yet (in-memory only; lost on restart)
- No cloud-MQTT path — local broker only (printer needs LAN Only + Developer Mode)
- No auth on the relay itself — add a shared-secret header before exposing publicly
