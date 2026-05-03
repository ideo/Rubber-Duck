# Multi-tenant relay on Fly.io — requirements

Drafted 2026-05-02. Owns issues #31 (multi-tenant), #32 (off-laptop deploy),
plus the cleanup punch-list that made it through APSTA.

## Goal

Bambu Duck is open hardware / open source. The product is a thing other
people stand up themselves — clone the repo, run Claude Code, plug a
chip in, end up with a working duck. The deployment story is part of
the project, not separate from it.

The relay is multi-tenant because:
1. The DIY user might want one relay for their 1+ ducks (family of 3
   ducks, a workshop with 5, etc).
2. We're also running an instance for 3 trusted colleagues, who get
   onboarded the same way DIY users do — they just don't pay the Fly
   bill because we're paying it.

There is one code path. Multi-tenant from day zero. Self-host is the
default mental model; "we're hosting yours" is just "we ran the runbook
on our Fly account for you."

## Two deployment shapes

Same relay code. Same multi-tenant DB. Difference is who owns the Fly
account and the ElevenLabs account.

### Self-hosted (the canonical path, what the project is for)

- User runs Claude Code inside a clone of this repo.
- Claude follows `bambu/DEPLOY.md` — a runbook written explicitly for
  Claude Code as the executor, not for a human reader — to:
    1. Provision a Fly app + volume in the user's Fly account.
    2. Generate a fresh `RELAY_SHARED_SECRET` and write it as a Fly
       secret.
    3. Use the user's ElevenLabs API key to programmatically create an
       agent from `bambu/elevenlabs/agent-template.json` and configure
       its 3 tool URLs against their relay.
    4. Hand the user back: their relay URL, agent_id, secret, and a
       one-line "next: plug in your duck and follow the captive portal."
- User's effort: get a Fly account, get an ElevenLabs account + API
  key, paste both keys into Claude when asked, plug duck in. Total
  ≈ 20 minutes including account signups.
- The chip firmware is generic — never per-user. Onboarding goes
  through the captive portal exclusively.

### Shared relay (our convenience for 3 colleagues)

- Same relay code, deployed to a Fly app we own (`duck-relay.fly.dev`
  or similar).
- Same multi-tenant DB — colleagues are just rows alongside any other
  ducks. Each colleague brings their own ElevenLabs account.
- We hand them: relay URL + shared secret. They onboard via the
  captive portal exactly like a self-hoster.
- The only thing we save them is the Fly setup cost ($0 base + ~$3/mo)
  and the runbook step — the rest of their experience is identical.
- If we ever stop hosting, they re-run the self-host runbook and
  point their captive-portal entries at their new relay URL. Migration
  cost is one re-onboarding per duck.

The dividing line: who pays the ~$3/mo Fly bill. Code path is identical.

## Out of scope (deliberately)

- A user-facing dashboard (status page only — see "Other"). No accounts, no
  password resets, no UI for re-bind printer. Captive portal does it all.
- Multi-printer per Bambu account. Each duck binds to one printer. If a user
  has multiple bound, we pick the first online one and the captive portal
  may show "duck is bound to {name}" (no chooser yet — #41).
- Token-refresh automation. If Bambu's access_token expires and refresh
  fails, the duck shows "needs reauth" and the user re-onboards. Punt.
- Anything that requires the chip to know about ElevenLabs. ElevenLabs is
  100% relay-side. (Important — see Identity model.)

## Identity model

**duck_id = chip's WiFi-SoftAP MAC, lowercase, no separators.** 12 hex chars.
Stable, free, already used to derive the AP SSID (`DuckDuckDuck-XXXX`).

```
struct {
  char id[13];           // e.g. "a1b2c3d4e5f6"
  // ... what the relay knows about this duck
}
```

The chip sends `duck_id` on every relay interaction:

- Header `X-Duck-Id: <id>` on the WS handshake to `/ws/notify` and `/ws/duck`.
- Field `"duck_id": "<id>"` inside the `bambu_login` WS message body.
- Path segment `/tools/printer_state/{duck_id}` on ElevenLabs webhooks.

The relay is the source of truth. First time a duck_id appears, the relay
creates a record. Records are keyed by duck_id throughout.

## Auth between chip and relay

Threat model: someone on the public internet who knows the relay URL
shouldn't be able to spoof a duck or read another duck's data. We are not
defending against a determined attacker who already has a user's Bambu
password — they have bigger problems than the relay.

**Mechanism: shared secret + duck_id.** All ducks compile in the same
`RELAY_SHARED_SECRET`. Chip sends `X-Relay-Secret: <secret>` on every
relay touch. ElevenLabs webhooks send `X-Relay-Secret` too (configured in
the agent's tool definitions).

This is fine for 4 users. If we ever go public, swap to per-duck issued
tokens (claim-on-first-handshake). Not worth designing now.

## Persistence

**SQLite on a Fly volume**, single file, atomic writes. Simpler than
Postgres for this scale. If we outgrow it, swap to Supabase Postgres later
(schema is small enough that the migration is one afternoon).

```sql
CREATE TABLE ducks (
  duck_id          TEXT PRIMARY KEY,
  bambu_user_id    TEXT,
  account_email    TEXT,
  access_token     TEXT,
  refresh_token    TEXT,
  serial           TEXT,
  printer_name     TEXT,
  cloud_host       TEXT NOT NULL DEFAULT 'us.mqtt.bambulab.com',
  elevenlabs_key   TEXT,
  elevenlabs_agent TEXT,
  created_at       INTEGER,
  last_seen_at     INTEGER
);
```

`tokens.json` is removed. Existing single-tenant install migrates by
reading the file once, inserting one row, deleting the file.

Volume mount: `/data` → SQLite at `/data/ducks.db`. Backed up nightly via
litestream → S3 (optional but recommended; the cost of losing the DB is
that all 4 friends have to re-onboard).

## Per-duck runtime state

Today: `state` is a module-level singleton (`bambu_state.py:state`).

Tomorrow:

```python
# main.py
states: dict[str, BambuState] = {}

def get_state(duck_id: str) -> BambuState:
    if duck_id not in states:
        row = db.fetch_duck(duck_id)
        if not row:
            raise HTTPException(404, "unknown duck")
        states[duck_id] = BambuState.from_row(row)
        states[duck_id].start()
    return states[duck_id]
```

On startup, the relay loads all known ducks and starts an MQTT client for
each. Each `BambuState` is its own thread + its own paho-mqtt client. 4
ducks ≈ 4 idle MQTT connections — trivial. Hundreds before we worry.

`reconfigure()` already exists for the post-login MQTT swap; we call it
per-duck instead of on a singleton.

## HTTP API

All tool endpoints become path-scoped:

```
GET  /tools/printer_state/{duck_id}
GET  /tools/temperatures/{duck_id}
GET  /tools/print_history/{duck_id}?n=5
```

Auth header `X-Relay-Secret` still required.

```
POST /admin/bambu_login           (body carries duck_id)
GET  /admin/bambu_status/{duck_id}
GET  /admin/raw_state/{duck_id}
GET  /health                      (unchanged — process-level)
GET  /status/{duck_id}            (NEW — public-ish health for friends)
```

The chip's WS-initiated bambu_login flow (today: relays creds via /ws/notify)
gains `duck_id` in the JSON body. duck_proxy.py routes the result to that
duck's BambuState.

## WebSocket protocol changes

`/ws/notify` handshake adds `X-Duck-Id`. The dispatcher tracks
`{duck_id: WebSocket}` rather than today's `_notify_clients` set. Notifications
generated by a BambuState fan out only to that duck's WS.

`/ws/duck` (audio path) similarly tags the connection by duck_id, so the
relay knows which user's ElevenLabs creds to use when forwarding audio.

## ElevenLabs — per-user config, relay-side

Each user creates their own ElevenLabs account + agent. They give us:

1. ElevenLabs API key (`xi-api-key`)
2. Agent ID

Both get stored on the duck's row in the DB. The chip forwards them via
the same captive-portal → relay handshake mechanism that today carries
Bambu creds. (Add to the wizard form. Chip never persists either.)

The agent template is a JSON we publish in the repo
(`bambu/elevenlabs/agent-template.json`). Users import it and edit 3
webhook URLs to use their duck_id. We host a setup helper page:

```
GET https://duck.fly.dev/setup/{duck_id}
```

Returns the 3 tool URLs and the shared secret for them to paste into
their agent's tool config. Saves 5 minutes of confusion per user.

## Captive portal — additions

Today's wizard collects: WiFi SSID, WiFi password, Bambu email, Bambu password.

Add (in priority order):

1. **ElevenLabs API key** (`type=password`, autocomplete=off)
2. **ElevenLabs agent ID** (`type=text`)
3. **Relay URL** (advanced — collapsed by default, pre-filled with
   `wss://duck.fly.dev`, editable for power users / region failover)

Wizard worker forwards (1) and (2) to the relay over the same WS path that
already carries Bambu login. Add a `set_eleven_creds` message type
alongside `bambu_login`. Relay stores them on the duck's row.

The /code (2FA) page stays as-is. Worker advances on success.

A new state added to the wizard: **WIZ_PICK_PRINTER** — if the Bambu
account has more than one online printer, render a `<select>` with the
options and POST `/pick`. (Optional for v1; if skipped, default to first
online which is today's behavior.)

## Bambu region

Per-duck `cloud_host` column. Default `us.mqtt.bambulab.com`. If a EU
user's login fails because their account is region-pinned, captive portal
shows a one-line "try EU broker" button that re-runs login against
`eu.mqtt.bambulab.com`. (Build out only when we hit it — most US users won't.)

## Bad-creds escape / restart

Today: on `WIZ_LOGIN_BAD_CREDS`, the page shows "Start over" pointing at
nothing. Wire `/restart` route that: (a) clears in-memory cred buffers,
(b) wipes the WiFi SSID/PW from NVS *only on user confirm*, (c) sets state
back to `WIZ_COLLECT_WIFI`. The browser re-renders to the form.

This unblocks: friend mistypes password → can recover without serial cable.

## Token refresh — fallback only

Don't auto-refresh. If MQTT auth fails, mark duck `auth_failed=true` in
the DB, send a `needs_reauth` notification to its /ws/notify, and the chip
chirps + lights its status. User long-presses the button to re-enter the
captive portal. (Long-press handler exists for AP-on-demand; we wire it
to also wipe stored creds when in this state.)

Better automation is a v2 problem.

## Observability

Today's "tail your terminal" goes away on Fly. Replacements:

- `fly logs` for the live tail.
- One JSON log line per duck event (`logger.info` with structured fields).
- `/status/{duck_id}` returns `{connected, last_message_age_ms, mode,
  printer_name}` — friend-facing, no secrets.
- `/health` stays process-level (200 = process up, says nothing about
  whether duck N is ok).

## Backups

`litestream replicate` to S3 (or Backblaze B2 — cheaper) every 60s.
SQLite WAL streaming, no measurable overhead. Restore is "copy file back
and start." Cost: pennies per month at our scale.

If we don't do this, treat the SQLite file as ephemeral and document
"if Fly volume dies, all friends re-onboard." Acceptable for v1, not
forever.

## Deployment — Fly.io

Same artifacts work for both shapes. The only difference is whose
`flyctl` account runs `fly deploy`.

Repo additions:

```
bambu/relay/Dockerfile          # python:3.13-slim, copy app, run uvicorn
bambu/relay/fly.toml            # app config, volume mount, health check
bambu/relay/.dockerignore
bambu/relay/litestream.yml      # SQLite → S3 replication (optional)
```

`fly.toml` essentials:

```toml
app = "duck-relay"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[mounts]
  source = "ducks_db"
  destination = "/data"

[http_service]
  internal_port = 8088
  force_https = true
  auto_stop_machines = false   # MQTT clients can't be stopped
  min_machines_running = 1

[[services]]
  internal_port = 8088
  protocol = "tcp"
  [[services.ports]]
    handlers = ["http"]
    port = 80
  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

[checks]
  [[checks.health]]
    type = "http"
    interval = "30s"
    path = "/health"
```

Secrets via `fly secrets set`:
- `RELAY_SHARED_SECRET` (chip and ElevenLabs use this)
- `LITESTREAM_S3_BUCKET`, `LITESTREAM_S3_KEY`, `LITESTREAM_S3_SECRET` (if backups)

Volume:
```
fly volumes create ducks_db --size 1 --region iad
```

1GB is wildly more than we need but is the floor.

## Self-host runbook — `bambu/DEPLOY.md`

A markdown file written **for Claude Code as the executor**, not for a
human reader. The user's role is: clone the repo, run Claude Code, paste
two keys when asked, plug their duck in.

The runbook is structured as a sequence of explicit instructions Claude
can act on. Sketch:

```
You are setting up a Bambu Duck for a new user. They have already given
you (or will, when prompted):
  - A Fly.io account they're logged into via flyctl
  - An ElevenLabs account + API key

Run these phases in order. Stop and ask the user only at the explicit
"ASK USER" markers.

PHASE 1 — Fly app
  1. ASK USER for a name for their relay (default: duck-relay-<random>).
  2. cd bambu/relay
  3. fly launch --no-deploy --copy-config --name <name> --region iad \
       --org personal --vm-size shared-cpu-1x --vm-memory 256
  4. fly volumes create ducks_db --size 1 --region iad --app <name>
  5. Generate a 32-byte random hex string. Set it:
     fly secrets set RELAY_SHARED_SECRET=<hex> --app <name>
  6. fly deploy --app <name>
  7. Capture <name>.fly.dev as RELAY_URL.

PHASE 2 — ElevenLabs agent
  1. ASK USER for their ElevenLabs API key.
  2. POST https://api.elevenlabs.io/v1/convai/agents
       body: contents of bambu/elevenlabs/agent-template.json
       (substitute RELAY_URL and RELAY_SHARED_SECRET into the 3 tool URLs
        + auth headers before posting)
     Capture the returned agent_id.

PHASE 3 — Hand-off
  1. Print to user:
       Your relay:    https://<name>.fly.dev
       Your agent_id: <agent_id>
       Your secret:   <hex>     (only shown once — write it down)
       Next: power on your duck, join the DuckDuckDuck-XXXX WiFi, and
       paste these into the captive portal.
  2. Don't flash anything — the firmware is generic; the captive portal
     will pull these into the chip and forward them to your relay.
```

The runbook is the spec. We refine it through `claude --plugin-dir`
testing — exactly the loop we already use for the duck-duck-duck plugin.

Constraints we accept by writing this for Claude:

- **Idempotency** — the runbook can be re-run after a partial failure
  (Phase 1 step 4 should detect "already exists" and skip). Claude is
  good at this if the runbook is explicit; we don't want it to be a
  Bash script that needs error-handling for every step.
- **Secrets discipline** — the runbook never asks Claude to store the
  ElevenLabs key or RELAY_SHARED_SECRET in the repo, in chat history,
  or in any committed file. Both flow into Fly secrets / ElevenLabs API
  via curl and then exist only in the user's accounts.
- **Trust** — the runbook says "ASK USER" before any destructive or
  billable action. Creating a Fly app costs nothing until it deploys;
  creating an ElevenLabs agent is free; the only billable line is
  `fly deploy`, which is gated by the user's earlier "yes deploy."

What `bambu/DEPLOY.md` does NOT do:

- It does not create a Fly account, an ElevenLabs account, or a Bambu
  account. Those are sign-up flows with email verification — not
  scriptable. The runbook tells the user to do them and pause.
- It does not flash the chip. The chip firmware is identical for every
  user; configuration goes through the captive portal.
- It does not do the physical onboarding. After the runbook prints the
  hand-off summary, the user takes over.

We ship `bambu/DEPLOY.md` and `bambu/elevenlabs/agent-template.json`
in the repo. README's "Deploy your own" section is two lines: clone,
run `claude` in `bambu/`. The runbook does the rest.

## Sizing

shared-cpu-1x with 256MB:
- Each MQTT client ≈ 5MB resident. 4 ducks = 20MB.
- FastAPI baseline ≈ 80MB.
- Headroom: plenty.

Cost estimate: $5-7/month total (Fly + B2). Known unknown:
ElevenLabs voice usage if we go shared-agent — but our plan is per-user
agents so we pay nothing for that.

## Migration plan (single-tenant → multi-tenant)

One PR, but reviewable. Can be staged on a branch and dry-run locally
before flipping the chip.

1. **Schema + DAO** — SQLite, migrations, tests for the data layer.
2. **`BambuState` registry** — `get_state(duck_id)` factory; lifespan
   loads all known ducks on startup; old singleton path kept temporarily
   for fallback.
3. **HTTP routes** — `/tools/*/{duck_id}` and `/admin/*/{duck_id}`. Old
   un-pathed routes return 410 Gone with a setup-helper link.
4. **WS handshake** — require `X-Duck-Id`. Reject without.
5. **Chip changes** — duck_id derived from MAC at boot, attached to all
   relay touches. Captive portal collects ElevenLabs creds. Relay URL
   becomes a configurable wizard field (default to Fly URL).
6. **Migration of existing tokens.json** — one-shot import script run on
   the Fly machine before flipping the chip.
7. **ElevenLabs agent template** — published as JSON; setup helper page
   live; doc in README for adding a new friend.
8. **Cutover** — flash one chip with the Fly URL, verify end-to-end, then
   the rest.

## Other issues to bundle along the way

Logging in here so they don't get re-discovered later.

- **HMS code vocabulary** — duck currently says "printer is reporting an
  error" with no detail. Lookup table for top ~50 codes (filament tangle,
  AMS retry, bed not detected, etc) so the duck can name the problem.
- **Duck status page for friends** — `/status/{duck_id}`, mentioned above.
  Public-readable, no secrets, just reachable so a friend can confirm
  "yes my duck is online, stop blaming the duck."
- **Wizard "no printers bound" handling** — today returns a generic
  `WIZ_LOGIN_BAD_CREDS`. Should surface a distinct page: "your Bambu
  account has no printers — bind one in Bambu Studio first."
- **Long-press on physical button** — should re-open captive portal
  *without* wiping stored creds (rescue path), and double-long-press
  should wipe. Today there's no long-press handler.
- **Ngrok references in code** — kill all references to ngrok in
  comments/config defaults once Fly URL is the canonical one. Audit
  `config.h`, `STATE.md`, `provision.c` comments.
- **`RELAY_HTTPS_BASE_URL` constants** in `config.h` — currently unused
  (since chip doesn't do HTTPS) but leftover. Remove.
- **Notification fan-out per duck** — today `_notify_clients` is a set of
  all connected WS; needs to become a `dict[duck_id, WebSocket]` so each
  duck only gets its own events.

## Risks

1. **MQTT auth failure under multi-tenant load** — if Bambu rate-limits
   per IP, 4 simultaneous logins from one Fly IP could trigger throttling.
   Unknown. Mitigation: stagger the relay's startup MQTT connects by 5s
   each; if we hit rate-limit signals, add per-account jitter on retry.
2. **WebSocket idle disconnects on Fly's edge** — Fly's HTTP edge has
   60s idle timeout by default. /ws/notify is mostly idle. Mitigation:
   chip already pings every 30s (verify); if not, add it.
3. **SQLite + threaded access** — paho-mqtt callbacks are on its own
   thread; FastAPI is async. Need a write-lock or move to a write-queue.
   Cleanest: all DB writes go through an async queue drained by one
   worker. Or use `aiosqlite` everywhere and never write from the MQTT
   thread (publish to an asyncio.Queue and let the event loop drain).
4. **Friend onboarding burden — ElevenLabs setup** — even with the helper
   page and template, it's a 10-minute first-time process. If a friend
   bails at step 4 we have a useless duck. Mitigation: video walkthrough
   in the README. Not in scope here, but flag it.
5. **Litestream + Fly volume edge cases** — if the Fly machine is force-
   migrated to a different host, the volume goes with it but litestream
   needs to re-anchor. Cheap to verify in a staging app.

## Open questions

- **"Reset duck" wire-protocol command** — `/admin/reset/{duck_id}` that
  pushes a `reboot` over /ws/notify. Useful in either shape — for our
  shared-relay case it lets us rescue a colleague's stuck duck; for
  self-hosters it's just a relay feature they can use themselves.
- **Domain** — `<name>.fly.dev` is free for any shape. Custom domain is
  cosmetic; not in scope.
- **Firmware distribution** — does a self-hoster flash from our prebuilt
  binary (we publish a release artifact) or build from source? Building
  is straightforward but requires ESP-IDF setup. Prebuilt is friendlier.
  Probably ship both. Decision punted to the firmware-distribution PR —
  the multi-tenant relay work doesn't depend on it.
- **Per-duck auth tokens** — currently one shared secret per relay (so
  every duck on a given relay shares it). For the shared-relay case
  with 3 colleagues this is fine; for a self-hoster running their own
  relay with 1 duck it's overkill but harmless. Revisit only if a
  shared relay ever expands beyond a trusted circle.
- **Multi-duck self-hoster** — works today: relay is multi-tenant, the
  runbook's hand-off section just needs "to add another duck, run the
  captive portal again with the same RELAY_URL+secret." Trivial.
- **DEPLOY.md tested with which Claude?** — the runbook targets Claude
  Code (the CLI). Should work with the Claude Desktop plugin too since
  the tool surface is shared, but smoke-test before claiming it.
- **Multi-relay coordination** — N/A. Relays are independent; nothing
  to coordinate. A self-hoster's relay never talks to ours.

## Definition of done

- 4 friends each have a duck on their desk talking to their Bambu.
- A 5th friend can be onboarded by: flashing one binary, telling them to
  join the AP, and pointing them at the ElevenLabs setup helper.
- The relay survives a Fly machine restart with no data loss.
- We can `fly logs` and tell which duck is which.
- The chip's firmware doesn't know about ElevenLabs.
- The chip's firmware doesn't know about other ducks.
