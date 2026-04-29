# Bambu Relay

Bridge between an ElevenLabs ElevenAgents agent and a Bambu printer's MQTT broker.

The duck (ESP32-S3) opens a WebSocket to ElevenAgents. The ElevenAgents LLM, mid-conversation,
calls tools defined in the ElevenAgents dashboard — those tools are HTTP webhooks
pointing at this relay. The relay holds the MQTT subscription and answers.

```
duck ──wss──→ ElevenLabs ElevenAgents ──webhook──→ this relay ──MQTT──→ Bambu printer
```

## Run

Requires Python 3.10+ (FastAPI uses PEP 604 `str | None` syntax at runtime).

```bash
cd bambu/relay
python3.13 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env   # fill in printer IP, access code, serial
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8088
```

Expose to ElevenAgents with `ngrok http 8088` (or deploy somewhere with a public URL).

### Mock mode (no printer required)

`MOCK=1` swaps the MQTT subscriber for `mock_printer.py`, which walks through
IDLE → PREPARE → RUNNING → FINISH on a loop. Useful for exercising the
endpoints before you have a printer reachable.

```bash
MOCK=1 RELAY_SHARED_SECRET=test123 .venv/bin/uvicorn main:app --port 8088
curl -H "X-Relay-Secret: test123" http://127.0.0.1:8088/tools/printer_state
```

## ElevenAgents agent setup

In the ElevenAgents dashboard, add three Server Tools (Webhook type) pointing at this relay:

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
