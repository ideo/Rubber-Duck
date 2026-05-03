# Bambu Relay

Multi-tenant bridge between ElevenLabs ElevenAgents and Bambu printers.

The duck (ESP32-S3) opens a `wss://` to this relay (TLS terminated by
the deployment edge — Fly.io's Let's Encrypt cert by default). The
relay holds an ElevenAgents session per active conversation and a
per-duck MQTT subscription to that user's Bambu printer. ElevenAgents
calls path-scoped tool webhooks (`/tools/printer_state/{duck_id}`)
during conversations to read live printer state.

```
duck ──wss──→ this relay ──TLS──→ ElevenAgents
                  │
                  └─ MQTT (per-duck) ──→ Bambu cloud broker
```

State lives in a SQLite DB (`ducks.db`) keyed by `duck_id` (chip
SoftAP MAC). Each row holds the user's Bambu access token,
ElevenLabs creds, and printer binding. See
[`bambu/docs/MULTI-TENANT-REQ.md`](../docs/MULTI-TENANT-REQ.md).

## Local dev

Requires Python 3.10+ (FastAPI uses PEP 604 `str | None` syntax at runtime).

```bash
cd bambu/relay
python3.13 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env   # fill in any LAN/MOCK overrides + ElevenLabs creds
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8088
```

The relay automatically migrates a legacy `tokens.json` (single-tenant
format) into `ducks.db` on first boot, leaving the file on disk for
safety.

## Deploy (Fly.io)

See [`bambu/DEPLOY.md`](../DEPLOY.md) for the Claude-Code-runnable
runbook. TL;DR:

```bash
fly launch --no-deploy --copy-config --name <your-app>
fly volumes create ducks_db --size 1 --region iad --app <your-app>
fly secrets set RELAY_SHARED_SECRET=<random-hex> --app <your-app>
fly deploy --app <your-app>
```

The current production deploy is at `https://duck-duck-print.fly.dev`.

### Mock mode (no printer required)

`MOCK=1` swaps the MQTT subscriber for `mock_printer.py`, which walks through
IDLE → PREPARE → RUNNING → FINISH on a loop. Useful for exercising the
endpoints before you have a printer reachable.

```bash
MOCK=1 RELAY_SHARED_SECRET=test123 .venv/bin/uvicorn main:app --port 8088
curl -H "X-Relay-Secret: test123" http://127.0.0.1:8088/tools/printer_state
```

## ElevenAgents agent setup

In the ElevenAgents dashboard, add three Server Tools (Webhook type)
pointing at the relay. URLs are path-scoped by `duck_id` (12 hex
chars = the chip's SoftAP MAC; the `/setup/{duck_id}` helper page
gives you the right URL to paste). All require an `X-Relay-Secret`
header matching `RELAY_SHARED_SECRET`.

| Tool name | Method | URL |
|---|---|---|
| `get_printer_state` | GET | `https://<your-relay>/tools/printer_state/{duck_id}` |
| `get_print_history` | GET | `https://<your-relay>/tools/print_history/{duck_id}?n={n}` |
| `get_temperatures` | GET | `https://<your-relay>/tools/temperatures/{duck_id}` |

For backward compat (older agent configs), the un-scoped versions
`/tools/printer_state` etc still work and resolve to the default
duck (oldest row in the DB). New agent configs should use the
path-scoped variants.

System prompt suggestion: "You are a rubber duck companion sitting
next to a 3D printer. You have tools to check the printer's live
state. Be concise, a little snarky, helpful. Don't list raw JSON —
translate to natural language."

## What's NOT in v0

- No `pause_print` / destructive tools — auth story not figured out
- No persistence of print history yet (in-memory only; lost on restart)
- No cloud-MQTT path — local broker only (printer needs LAN Only + Developer Mode)
- No auth on the relay itself — add a shared-secret header before exposing publicly
