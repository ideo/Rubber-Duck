# DEPLOY.md — runbook for Claude Code

You are setting up a Bambu Duck for a new user. The user has a chip,
a Bambu printer, a Bambu account, and an ElevenLabs account. They
just cloned this repo and ran `claude`. Walk them end-to-end.

This file is written for **Claude Code as the executor**, not for a
human reader. The user's job is to:
- Install `flyctl` (if not already) and run `fly auth login`.
- Have an ElevenLabs API key ready (free tier is fine to start).
- Plug their duck in via USB when you ask.

Stop and ask the user only at the explicit **ASK USER** markers below.
Otherwise, run the steps in order. If a step fails, surface the error,
stop, and let the user decide whether to retry.

---

## Phase 0 — Preflight

**Verify the user has flyctl installed and authenticated.**

```
fly version
fly auth whoami
```

If either fails: stop and ASK USER to install/login. Don't proceed.

**Verify Docker is NOT required locally.** Fly does the build remotely.

**Verify the user has the repo at this directory.** The runbook assumes
`bambu/relay/` is the working directory for Phase 1.

---

## Phase 1 — Fly app

**ASK USER** for an app name. Default suggestion:
`duck-relay-<6-char-random>`. Lowercase, hyphens, must be globally
unique on Fly. Capture as `APP_NAME`.

```bash
cd bambu/relay

# Launch but don't deploy yet — we need to set the volume + secret first.
fly launch --no-deploy --copy-config --name "$APP_NAME" \
  --region iad --org personal \
  --vm-size shared-cpu-1x --vm-memory 256
```

If launch fails because the name is taken: ASK USER for a different name.

**Create the persistent volume for SQLite.**

```bash
fly volumes create ducks_db --size 1 --region iad --app "$APP_NAME"
```

Volume size 1GB is the floor; we use ~10MB. Don't bother resizing.

**Generate and set a fresh `RELAY_SHARED_SECRET`.**

```bash
SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
fly secrets set RELAY_SHARED_SECRET="$SECRET" --app "$APP_NAME"
```

**Save the secret to a local file** so the user can paste it later.
Do NOT echo it into chat history. Write to a file outside the repo:

```bash
mkdir -p ~/.duck-deploy
echo "RELAY_SHARED_SECRET=$SECRET" > ~/.duck-deploy/$APP_NAME.env
echo "APP_HOSTNAME=${APP_NAME}.fly.dev" >> ~/.duck-deploy/$APP_NAME.env
chmod 600 ~/.duck-deploy/$APP_NAME.env
```

Tell the user where the file is. They'll need the secret for ElevenLabs
tool config in Phase 2.

**Deploy.**

```bash
fly deploy --app "$APP_NAME"
```

This is the first billable action. Cost: ~$3/month for an always-on
shared-cpu-1x. ASK USER to confirm before running if you haven't
already. Wait for the deploy to finish (typically 2-3 minutes).

**Verify it's healthy.**

```bash
curl -s "https://$APP_NAME.fly.dev/health"
```

Should return `{"ok":true,"duck_count":0,"ducks":[]}`. Empty ducks
list is correct — the duck hasn't onboarded yet.

If 502 / 503: `fly logs --app "$APP_NAME"` and surface the error.

Capture `RELAY_URL=https://$APP_NAME.fly.dev` and
`RELAY_WS_URL=wss://$APP_NAME.fly.dev` for Phase 2.

---

## Phase 2 — ElevenLabs agent

**ASK USER** for their ElevenLabs API key. Save to a local-only env
var; do NOT write to a committed file.

```bash
# In your shell, exported from the user's prompt — NOT committed.
export XI_KEY="<user's key>"
```

**Create the agent from our template.** The template lives at
`bambu/elevenlabs/agent-template.json`. Tool URLs in it use the
un-scoped `/tools/printer_state` route which the relay resolves to
the "default duck" (oldest row in the DB) — for self-hosters with
one duck this is forever-correct and means we can create the agent
BEFORE the chip onboards.

Two values to substitute:
- `{{RELAY_URL}}` → `https://$APP_NAME.fly.dev`
- `{{RELAY_SHARED_SECRET}}` → the secret from Phase 1

```bash
# Strip the leading _comment field and substitute placeholders, then
# POST to ElevenLabs. jq removes _comment cleanly; sed handles the
# value substitutions. Pipe to curl with --data-binary @- so big
# system_prompt strings don't get mangled.
RENDERED=$(jq 'del(._comment) | del(.conversation_config.tts._comment_voice)' \
  bambu/elevenlabs/agent-template.json | sed \
  -e "s|{{RELAY_URL}}|$RELAY_URL|g" \
  -e "s|{{RELAY_SHARED_SECRET}}|$SECRET|g")

AGENT_ID=$(echo "$RENDERED" | curl -s -X POST \
  "https://api.elevenlabs.io/v1/convai/agents/create" \
  -H "xi-api-key: $XI_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @- | python3 -c "import sys, json; print(json.load(sys.stdin)['agent_id'])")

echo "AGENT_ID=$AGENT_ID" >> ~/.duck-deploy/$APP_NAME.env
```

If the POST fails: surface the error and stop. Common causes:
- 401 — wrong API key.
- 422 — template malformed (probably a substitution issue, or a field
  the user's ElevenLabs plan doesn't support — e.g. some `tts.model_id`
  values are paid-tier-only).

The template defaults to `eleven_v3_conversational` for the live
agent voice and a curated voice (`ygoBNrnmTEdu5NtDTmAY`) tuned for
the duck's personality. Voice selection criteria + alternatives are
in [`bambu/agent/voice.md`](agent/voice.md); auditioning happens in
the ElevenLabs dashboard after import. If the user changes the
voice, also update `gen_phrases.py`'s `VOICE_ID` so the embedded
onboarding phrases (`tap_to_start`, `wifi_up`) match the live voice.

**Multi-duck note:** if the user runs more than one chip on this
relay, each chip needs its own agent because the un-scoped tool URLs
all resolve to the default duck. The template's `_comment` field
documents the path-scoped variant (`/tools/printer_state/<duck_id>`)
to swap in for that case.

---

## Phase 3 — Hand-off to the user

Print to chat:

```
Your relay is running at:  https://<APP_NAME>.fly.dev
Your ElevenLabs agent_id:  <AGENT_ID>
Your shared secret:        ~/.duck-deploy/<APP_NAME>.env

Next steps for you:
1. Power on your duck. Hold the button for 3 seconds if it's already
   onboarded — that re-opens the captive portal.
2. From your phone, join the WiFi network "DuckDuckDuck-XXXX" (the
   AP your duck publishes when it has nothing to do).
3. The captive portal will pop. Fill in:
     - your home WiFi name + password
     - your Bambu account email + password
     - the ElevenLabs API key + agent_id from above
     - (Advanced) Relay URL: leave blank, OR paste
       wss://<APP_NAME>.fly.dev to override the default
4. Hit "Set up". The wizard does the rest. ~60 seconds.

When the duck says "you're set", you're done. Press the button to talk.
```

That's it. Don't deploy chip firmware here — the user flashes
themselves once (separate doc, see firmware/README.md). The captive
portal is the only configuration surface.

---

## What this runbook does NOT do

- **Create accounts** — Fly, ElevenLabs, and Bambu all require email
  verification. You can't do this for the user.
- **Flash chip firmware** — firmware is generic across users; the
  captive portal does all per-user config. If the user hasn't flashed,
  point them at `bambu/firmware/README.md` (or the prebuilt binary
  release once #48's firmware-distribution sub-task lands).
- **Modify ElevenLabs voice settings** — the agent template inherits
  whatever voice the template was exported with. If the user wants a
  different voice, point them at the ElevenLabs UI.
- **Bambu cloud login** — the chip+relay handle this through the
  captive portal flow. No human-in-the-loop needed beyond entering
  email + password.

---

## Recovery / common issues

**Duck doesn't connect to relay after onboarding:**
1. `fly logs --app "$APP_NAME"` — look for "notify client connected".
2. If you see "auth_failed=true" in `/admin/list_ducks`: the user's
   Bambu access_token has likely expired. Long-press the duck button
   to re-onboard.

**Captive portal won't load:**
- iOS auto-pop sometimes wedges. Tell user to manually browse to
  `http://192.168.4.1` while joined to the duck's AP.

**ElevenLabs agent doesn't respond:**
- `fly logs` for the relay — look for "no ElevenLabs creds" warnings.
  Means the captive portal upload didn't land; user re-runs onboarding
  with creds filled in.

**Secret rotation:**
- `fly secrets set RELAY_SHARED_SECRET="$NEW" --app "$APP_NAME"` then
  re-deploy. User has to update the ElevenLabs agent's tool auth header
  to match. Don't do this lightly.

---

## Optional Phase 4 — Litestream backups

The relay image already includes Litestream. Deploys without an S3
bucket configured run uvicorn directly, no replication; deploys with
one configured stream the SQLite WAL to S3-compatible storage in real
time and restore from latest snapshot if the local DB ever disappears.

For a project at our scale (4 ducks), the Fly volume's nightly
snapshots are usually enough. Enable Litestream when the deployment
matters enough that "everyone re-onboards" isn't an acceptable
recovery story.

Recommended target: **Backblaze B2** — S3-compatible, cheaper than
AWS S3 by an order of magnitude, plenty for a SQLite DB measuring
in single-digit MB.

ASK USER whether they want to enable backups. If yes:

```bash
# User creates a bucket in their B2 account named e.g. "duck-relay-backups",
# generates an application key with write access scoped to that bucket.

fly secrets set \
    LITESTREAM_BUCKET="<bucket-name>" \
    LITESTREAM_ENDPOINT="https://s3.us-east-005.backblazeb2.com" \
    LITESTREAM_ACCESS_KEY_ID="<their-key-id>" \
    LITESTREAM_SECRET_ACCESS_KEY="<their-application-key>" \
    --app "$APP_NAME"
```

Verify replication started:

```bash
fly logs --app "$APP_NAME" | grep -i litestream
```

Should see `Litestream enabled — bucket=<name>` early, then
`replicating to: ...` lines on subsequent activity.

Restore is automatic on container start if the local DB is empty and
a replica exists. Manual restore (e.g., spinning up a fresh dev
machine from production data):

```bash
litestream restore -config litestream.yml /local/path/ducks.db
```
