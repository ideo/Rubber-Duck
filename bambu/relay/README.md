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

Don't hand-build the agent — use [`bambu/elevenlabs/agent-template.json`](../elevenlabs/agent-template.json).
The [`DEPLOY.md`](../DEPLOY.md) runbook substitutes `{{RELAY_URL}}`
and `{{RELAY_SHARED_SECRET}}` and POSTs the rendered JSON to
ElevenLabs in one shot — system prompt, tool schemas, voice, and
the `X-Relay-Secret` auth header are all wired up consistently.

The three Server Tools (Webhook) the template registers:

| Tool name | Method | URL |
|---|---|---|
| `get_printer_state` | GET | `https://<your-relay>/tools/printer_state` |
| `get_print_history` | GET | `https://<your-relay>/tools/print_history?n={n}` |
| `get_temperatures` | GET | `https://<your-relay>/tools/temperatures` |

The un-scoped paths above resolve to the "default duck" (oldest row
in the DB) — fine for self-hosters running one duck per relay, which
is the common case. For multi-duck setups, switch to the scoped
variants `/tools/printer_state/<duck_id>` etc and create one agent
per duck.

## What's intentionally NOT here

- **No destructive tools** (pause / stop / parameter changes). Agent
  is read-only. Adding any actuating tool requires the authority
  model in [`#25`](https://github.com/ideo/Rubber-Duck/issues/25)
  to land first.
- **No print history persistence across restarts** — in-memory only,
  rebuilt on MQTT reconnect. Closed [`#23`](https://github.com/ideo/Rubber-Duck/issues/23)
  as won't-do: the relay re-reads live state on reconnect; the duck
  doesn't need to memory-manage.
- **Cloud MQTT only in production** — relay uses Bambu's CA-signed
  cloud broker (`us.mqtt.bambulab.com`), TLS verified by default.
  A LAN-direct dev path exists in code (`verify_tls=False`,
  WARN-loud at construction) but is unused in production.
- **Relay auth is a shared-secret header**, not OAuth / per-user
  tokens. `X-Relay-Secret` matches `RELAY_SHARED_SECRET`. Generate
  fresh per deployment, keep it private.
