"""ElevenLabs webhook target. Per-duck tools the LLM can call mid-conversation.

Multi-tenant since 2026-05-03 (#31): the relay holds N BambuState
instances, one per duck_id, in the `states` registry. Two parallel
shapes for the same data:

- **Path-scoped routes** like `/tools/printer_state/{duck_id}` —
  the explicit shape needed when one relay hosts multiple ducks
  (each ElevenLabs agent points at its tenant's path).
- **Un-scoped routes** like `/tools/printer_state` — resolves to the
  default duck (oldest DB row). Canonical for self-hosters with one
  duck, where the duck_id is unambiguous; the shipped agent template
  uses these.

Both are first-class. See bambu/docs/MULTI-TENANT-REQ.md.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException

import bambu_cloud
import db
from bambu_state import BambuState
from duck_proxy import (
    router as duck_router,
    register_bambu_listener,
    register_bambu_login_handler,
    register_legacy_claim_handler,
    register_list_printers_handler,
    register_set_printers_handler,
)

load_dotenv()

logger = logging.getLogger("main")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:main: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False

# Per-duck BambuState registry. Populated in lifespan startup from the DB.
# All other code that needs printer state goes through get_state(duck_id).
states: dict[str, BambuState] = {}

# Legacy single-tenant tokens.json. Migration reads this once on startup
# and writes one row into ducks.db; the file is left on disk for safety
# (operator decides when to delete). See db.migrate_from_tokens_json.
TOKENS_PATH = Path(__file__).parent / "tokens.json"
DB_PATH = Path(os.environ.get("DUCKS_DB_PATH",
                              str(Path(__file__).parent / "ducks.db")))

# Default cloud broker. Bambu has US, EU, and CN regional brokers — the
# user_id is global so any region works, but lower-latency to the user's
# region. Override via env if needed. Per-duck override lives in the DB row.
DEFAULT_CLOUD_HOST = os.environ.get("BAMBU_CLOUD_HOST", "us.mqtt.bambulab.com")

# duck_id used when migrating legacy tokens.json (no chip MAC available
# at migration time). Operator can set DUCK_ID env to a real chip MAC; if
# unset, "legacy" is used as a sentinel that the firmware update can
# rename to its real MAC on first connect (next checkpoint).
LEGACY_DUCK_ID = os.environ.get("DUCK_ID", "legacy")


def _state_from_row(row: dict) -> BambuState:
    """Build a BambuState from a ducks DB row. Cloud mode if access_token
    is present; LAN mode otherwise (env-var fallback for serial/access
    code). One BambuState per duck — they don't share clients or threads.

    Reads `serials`/`printer_names` JSON arrays first (#41 multi-printer
    canonical), falls back to legacy single `serial`/`printer_name` for
    rows that haven't been migrated."""
    def _parse_list(s: str | None) -> list[str]:
        if not s:
            return []
        try:
            v = json.loads(s)
            return [str(x) for x in v] if isinstance(v, list) else []
        except (ValueError, TypeError):
            return []

    if row.get("access_token") and row.get("bambu_user_id"):
        serials = _parse_list(row.get("serials"))
        names = _parse_list(row.get("printer_names"))
        # Legacy single-row fallback if the migration didn't run for
        # some reason (defensive).
        if not serials and row.get("serial"):
            serials = [row["serial"]]
            names = [row.get("printer_name") or ""]
        return BambuState(
            host=row.get("cloud_host") or DEFAULT_CLOUD_HOST,
            username=f"u_{row['bambu_user_id']}",
            password=row["access_token"],
            serials=serials,
            printer_names=names,
            verify_tls=True,
        )
    # LAN-ish fallback. Mostly for development; once the duck has done
    # cloud login this branch is unused.
    return BambuState(
        host=os.environ.get("BAMBU_HOST", "mock"),
        username="bblp",
        password=os.environ.get("BAMBU_ACCESS_CODE", "mock"),
        serial=os.environ.get("BAMBU_SERIAL", "mock"),
        verify_tls=False,
    )


# Serializes /admin/bambu_login calls so two concurrent attempts can't race
# the DB write or hammer Bambu's API in a way that looks botty.
_login_lock: asyncio.Lock | None = None


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # 1. Open the DB and run the one-shot migration from tokens.json.
    #    Migration is idempotent (skipped if the DB has any rows or the
    #    file is missing) and never deletes the file.
    database = db.init(DB_PATH)
    migrated = database.migrate_from_tokens_json(TOKENS_PATH, LEGACY_DUCK_ID)
    if migrated:
        logger.info("first-run migration: tokens.json → ducks.db (id=%s)",
                    LEGACY_DUCK_ID)

    # 2. Spin up a BambuState per row. Done sequentially with a small
    #    delay so a future hot-onboarding doesn't slam Bambu's auth
    #    endpoint when N ducks come up at once. (See #31 risks.)
    rows = database.list_ducks()
    has_lan_env = bool(os.environ.get("BAMBU_HOST"))
    if not rows and (has_lan_env or os.environ.get("MOCK") == "1"):
        # Empty DB but operator gave us LAN-mode env (or MOCK). Spin up
        # one "legacy" placeholder state so local dev can run before
        # any real duck has onboarded. On a fresh Fly deploy with
        # neither BAMBU_HOST nor MOCK set, we skip this and the relay
        # simply has zero ducks until one onboards via captive portal.
        logger.info("no ducks in DB but LAN/MOCK env present — "
                    "starting placeholder state under id=%s",
                    LEGACY_DUCK_ID)
        s = _state_from_row({})
        states[LEGACY_DUCK_ID] = s
        if os.environ.get("MOCK") == "1":
            from mock_printer import drive_in_thread
            drive_in_thread(s)
        else:
            s.start()
        register_bambu_listener(LEGACY_DUCK_ID, s)
    elif not rows:
        # Truly empty — fresh deploy, no operator-provided LAN config,
        # and tokens.json migration didn't happen (no file). Nothing
        # to start. /health will report 0 ducks; first chip to
        # bambu_login will create a row and spin up its state on the
        # fly via _do_bambu_login.
        logger.info("no ducks registered — relay idle, awaiting first onboard")
    else:
        for row in rows:
            duck_id = row["duck_id"]
            logger.info("starting BambuState for duck_id=%s (printer=%r, host=%s)",
                        duck_id,
                        row.get("printer_name") or "(unknown)",
                        row.get("cloud_host"))
            s = _state_from_row(row)
            states[duck_id] = s
            if os.environ.get("MOCK") == "1":
                from mock_printer import drive_in_thread
                drive_in_thread(s)
            else:
                s.start()
            register_bambu_listener(duck_id, s)
            await asyncio.sleep(0.5)  # spread MQTT auths

    yield

    if os.environ.get("MOCK") != "1":
        for duck_id, s in states.items():
            try:
                s.stop()
            except Exception as e:
                logger.warning("stop failed for %s: %s", duck_id, e)


app = FastAPI(lifespan=lifespan)
app.include_router(duck_router)


def _auth(secret: str | None) -> None:
    expected = os.environ.get("RELAY_SHARED_SECRET")
    if expected and secret != expected:
        raise HTTPException(401, "bad shared secret")


import re
_MAC_HEX_RE = re.compile(r"^[0-9a-f]{12}$")


def claim_legacy_if_applicable(announced_id: str) -> str:
    """First-real-MAC adoption flow.

    The tokens.json → DB migration creates a row keyed "legacy" because we
    don't know the chip's MAC at migration time. The first real chip to
    announce itself (via X-Duck-Id on a WS handshake) should TAKE OVER
    that row rather than create a duplicate orphan — same Bambu account,
    same printer binding, same MQTT client thread.

    Conditions for a takeover:
      1. The announced id looks like a chip MAC (12 lowercase hex chars).
      2. The DB has exactly one duck and it's the "legacy" placeholder.
      3. The announced id isn't itself "legacy" (sanity).

    Returns the id the caller should treat the connection as. Almost
    always either `announced_id` (if takeover happened or wasn't needed)
    or the same string verbatim (if conditions weren't met — caller
    proceeds normally, possibly hitting a 404 if the duck isn't in the
    DB yet, which is the right answer).
    """
    if announced_id == "legacy" or not _MAC_HEX_RE.match(announced_id):
        return announced_id
    rows = db.get().list_ducks()
    if len(rows) != 1 or rows[0]["duck_id"] != "legacy":
        return announced_id
    if not db.get().rename_duck("legacy", announced_id):
        return announced_id
    # Move the in-memory state under the new id so subsequent lookups hit.
    s = states.pop("legacy", None)
    if s is not None:
        states[announced_id] = s
    logger.info("adopted legacy duck → %s (chip's real MAC, BambuState carried over)",
                announced_id)
    return announced_id


def _resolve_duck_id(duck_id: str | None) -> str:
    """Resolve a possibly-omitted duck_id to a concrete one via the DB's
    default (oldest row). Raises 503 if the DB is empty.

    Used by un-scoped routes (`/tools/printer_state` without a path
    segment) — these are the canonical shape for self-hosters with one
    duck and the explicit shape for multi-tenant relays where each
    agent points at its tenant's path-scoped URL."""
    if duck_id:
        return duck_id
    default = db.get().default_duck_id()
    if not default:
        raise HTTPException(503, "no ducks registered yet")
    return default


def _state_for(duck_id: str) -> BambuState:
    s = states.get(duck_id)
    if s is None:
        raise HTTPException(404, f"unknown duck_id: {duck_id}")
    return s


@app.get("/health")
def health():
    return {
        "ok": True,
        "duck_count": len(states),
        "ducks": list(states.keys()),
    }


# ---- Path-scoped tools (the canonical multi-tenant routes) ---------------


@app.get("/tools/printer_state/{duck_id}")
def printer_state_scoped(duck_id: str,
                         x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return _state_for(duck_id).snapshot()


@app.get("/tools/temperatures/{duck_id}")
def temperatures_scoped(duck_id: str,
                        x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return _state_for(duck_id).temperatures()


@app.get("/tools/print_history/{duck_id}")
def print_history_scoped(duck_id: str, n: int = 5,
                         x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return {"history": _state_for(duck_id).history(max(1, min(n, 20)))}


# ---- Un-scoped tool routes — canonical for single-duck self-hosters ----
# Originally tagged COMPAT for a multi-tenant cutover, but in practice:
#   - Self-hosters (one duck per relay): un-scoped is the natural shape;
#     the agent template uses these URLs directly. Resolves to "the
#     duck" via default_duck_id() — unambiguous when there's only one.
#   - Multi-tenant deployments (one relay, several ducks): each agent
#     uses /tools/.../{duck_id} explicitly because un-scoped would
#     route every agent to the same default duck.
# So these routes stay. _resolve_duck_id is part of the canonical API.


@app.get("/tools/printer_state")
def printer_state_compat(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return _state_for(_resolve_duck_id(None)).snapshot()


@app.get("/tools/temperatures")
def temperatures_compat(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return _state_for(_resolve_duck_id(None)).temperatures()


@app.get("/tools/print_history")
def print_history_compat(n: int = 5,
                         x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return {"history": _state_for(_resolve_duck_id(None)).history(max(1, min(n, 20)))}


# ---- Admin --------------------------------------------------------------


@app.get("/admin/raw_state/{duck_id}")
def raw_state_scoped(duck_id: str):
    """Dump the FULL Bambu push_status payload for a specific duck.
    No auth — local diagnostic only."""
    return _state_for(duck_id)._state


@app.get("/admin/raw_state")
def raw_state_compat():
    duck_id = db.get().default_duck_id()
    if duck_id is None or duck_id not in states:
        return {}
    return states[duck_id]._state


@app.get("/admin/list_ducks")
def list_ducks(x_relay_secret: str | None = Header(default=None)):
    """Show what ducks the relay is hosting. Auth-gated because the row
    includes account_email (low-stakes leak but still PII)."""
    _auth(x_relay_secret)
    rows = db.get().list_ducks()
    out = []
    for r in rows:
        s = states.get(r["duck_id"])
        # Parse JSON arrays for surfacing in the response.
        try:
            serials = json.loads(r["serials"]) if r.get("serials") else []
        except (ValueError, TypeError):
            serials = []
        try:
            printer_names = (json.loads(r["printer_names"])
                             if r.get("printer_names") else [])
        except (ValueError, TypeError):
            printer_names = []
        out.append({
            "duck_id": r["duck_id"],
            "account_email": r.get("account_email"),
            "printer_names": printer_names,
            "serials": serials,
            # Legacy singletons kept for back-compat readers.
            "printer_name": r.get("printer_name"),
            "serial": r.get("serial"),
            "cloud_host": r.get("cloud_host"),
            "created_at": r.get("created_at"),
            "last_seen_at": r.get("last_seen_at"),
            "live": s is not None,
            "auth_failed": getattr(s, "auth_failed", None) if s else None,
        })
    return {"ducks": out}


async def _do_bambu_login(payload: dict) -> dict:
    """Core login logic — used by both the HTTP endpoint and the chip-
    initiated WS message handler. Raises HTTPException on failure so
    both callers get consistent error shapes.

    `payload` carries an optional `duck_id`. When present, the resulting
    tokens are stored on that duck's DB row and that duck's BambuState
    is reconfigured. When absent (legacy chip firmware), we fall back to
    the default duck. Operators with multiple ducks should always send
    duck_id — see compat note above.
    """
    global _login_lock
    if _login_lock is None:
        _login_lock = asyncio.Lock()

    email = payload.get("email")
    password = payload.get("password")
    code = payload.get("code") or None
    user_id_override = payload.get("user_id") or os.environ.get("BAMBU_USER_ID")
    # Fall back to the default duck if the chip didn't send duck_id
    # in the payload. Pre-X-Duck-Id firmware did this implicitly; the
    # current chip always sends it via the WS handshake header.
    duck_id = payload.get("duck_id") or _resolve_duck_id(None)
    # Same legacy-adoption pass as the WS handshake — chip-supplied real
    # MAC takes over the "legacy" placeholder row.
    duck_id = claim_legacy_if_applicable(duck_id)
    if not email or not password:
        raise HTTPException(400, "email and password required")

    async with _login_lock:
        try:
            result = await bambu_cloud.login(email, password, code, user_id_override)
        except bambu_cloud.TwoFARequired as e:
            raise HTTPException(401, detail={"code": "2fa_required", "message": str(e)})
        except bambu_cloud.LoginError as e:
            raise HTTPException(401, detail={"code": "login_failed", "message": str(e)})

    try:
        devices = await bambu_cloud.list_devices(result["access_token"])
    except bambu_cloud.LoginError as e:
        raise HTTPException(502, detail={"code": "list_devices_failed", "message": str(e)})
    if not devices:
        raise HTTPException(404, detail={"code": "no_printers",
                                         "message": "Bambu account has no bound printers"})

    # Multi-printer #41 Phase A — subscribe to ALL printers in the
    # account by default. Phase B (captive-portal checkbox picker)
    # will let the user opt out of specific printers; until then,
    # the duck is omniscient about every printer the user owns.
    #
    # BAMBU_SERIAL env (legacy single-printer pin) still narrows to
    # one if set — that's the dev / single-printer-shared-relay path.
    pinned = os.environ.get("BAMBU_SERIAL")
    if pinned:
        chosen = [d for d in devices if d.get("dev_id") == pinned] \
                  or devices[:1]
    else:
        chosen = devices
    serials = [d["dev_id"] for d in chosen]
    printer_names = [d.get("name", "") for d in chosen]

    # Persist on the duck's row. upsert_duck preserves any other fields
    # already set (cloud_host, elevenlabs_*) since we pass only what's new.
    db.get().upsert_duck(
        duck_id,
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        bambu_user_id=result["user_id"],
        serials=serials,
        printer_names=printer_names,
        account_email=email,
    )

    # Reconfigure (or first-create) the BambuState for this duck.
    s = states.get(duck_id)
    if s is None:
        # Brand-new duck — build a state and start it.
        row = db.get().get_duck(duck_id) or {}
        s = _state_from_row(row)
        states[duck_id] = s
        s.start()
        register_bambu_listener(duck_id, s)
    else:
        s.reconfigure(
            host=DEFAULT_CLOUD_HOST,
            username=f"u_{result['user_id']}",
            password=result["access_token"],
            serials=serials,
            printer_names=printer_names,
            verify_tls=True,
        )

    # Enumerate printers as numbered string fields so the chip's
    # captive portal (Phase B of #41) can render a checkbox picker
    # without needing a JSON array parser. We sanitize names to
    # remove characters that would confuse the chip's substring
    # JSON extractor (quotes, backslashes, control chars). The
    # original name stays in the DB row's printer_names array; this
    # is just the wire-safe form for chip rendering.
    out: dict = {
        "duck_id": duck_id,
        "user_id": result["user_id"],
        # Legacy single-value fields kept for back-compat readers.
        "serial": serials[0] if serials else "",
        "printer_name": printer_names[0] if printer_names else "(unknown)",
        "online": any(d.get("online", False) for d in chosen),
        # Phase B: numbered string fields.
        "printer_count": str(len(chosen)),
    }
    MAX_WIRE_PRINTERS = 8
    for i, d in enumerate(chosen[:MAX_WIRE_PRINTERS]):
        # Strip JSON-troublesome chars from names. The chip's
        # extract_json_string finds string values via memchr('"');
        # an embedded quote ends the value early. Limit to 31 chars
        # so the chip's display buffer doesn't overflow.
        safe_name = (d.get("name", "") or "").replace('"', "'") \
                                              .replace("\\", "/") \
                                              .replace("\n", " ")
        if len(safe_name) > 31:
            safe_name = safe_name[:31]
        out[f"printer_{i}_name"] = safe_name
        out[f"printer_{i}_serial"] = d["dev_id"]
        out[f"printer_{i}_online"] = "1" if d.get("online", False) else "0"
        # First-onboarding default: every printer in `chosen` is about
        # to be subscribed (Phase A behavior — bambu_login subscribes
        # to all). Picker will pre-check accordingly.
        out[f"printer_{i}_subscribed"] = "1"
    return out


@app.post("/admin/bambu_login")
async def bambu_login_endpoint(payload: dict, x_relay_secret: str | None = Header(default=None)):
    """HTTP entry point for cloud login. Body: {duck_id?, email, password,
    code?, user_id?}. Same logic as the chip's WS-initiated path — this
    exists for curl-based development + future debugging."""
    _auth(x_relay_secret)
    result = await _do_bambu_login(payload)
    return {"ok": True, **result}


# Wire the duck_proxy /ws/notify handler so chip-originated bambu_login
# messages dispatch to the same logic as the HTTP endpoint.
register_bambu_login_handler(_do_bambu_login)

# Wire the legacy-MAC adoption flow so the first real-MAC chip handshake
# claims the migrated "legacy" row (rather than orphaning it).
register_legacy_claim_handler(claim_legacy_if_applicable)


def _reconfigure_for_set_printers(duck_id: str, serials: list[str],
                                   printer_names: list[str]) -> None:
    """Chip-driven printer-subset selection (#41 Phase B). The DB has
    already been updated with the narrowed list; we just need to point
    the live BambuState's MQTT subscriptions at the new serial set.

    Called from duck_proxy.py via the registered handler so we don't
    have to import main.py from there (cycle)."""
    s = states.get(duck_id)
    if s is None:
        # No live state yet — onboarding flow that hasn't fully
        # completed; the next bambu_login (or the first /admin/import_duck)
        # will create one with the right binding from the row we just wrote.
        return
    row = db.get().get_duck(duck_id) or {}
    s.reconfigure(
        host=row.get("cloud_host") or DEFAULT_CLOUD_HOST,
        username=f"u_{row['bambu_user_id']}",
        password=row["access_token"],
        serials=serials,
        printer_names=printer_names,
        verify_tls=True,
    )


register_set_printers_handler(_reconfigure_for_set_printers)


async def _list_printers_for(duck_id: str) -> list[dict]:
    """Fast-path printer list for the chip's "long-press while already
    onboarded" flow. Uses the duck's stored access_token (no re-auth
    needed) to call list_devices on Bambu cloud, returns simple dicts
    the duck_proxy handler can stamp into the response.
    """
    row = db.get().get_duck(duck_id)
    if not row or not row.get("access_token"):
        raise RuntimeError("duck not bound to a Bambu account yet")
    devices = await bambu_cloud.list_devices(row["access_token"])
    return [
        {"serial": d["dev_id"],
         "name": d.get("name", ""),
         "online": d.get("online", False)}
        for d in devices
    ]


register_list_printers_handler(_list_printers_for)


@app.post("/admin/import_duck")
async def import_duck(payload: dict,
                      x_relay_secret: str | None = Header(default=None)):
    """Transplant an existing duck row from another relay (e.g. local
    dev → Fly cutover) without making the user re-onboard via captive
    portal. Body carries the access_token directly, so no Bambu
    re-login is needed; we just call list_devices with the supplied
    token and populate the row.

    Required: duck_id, bambu_user_id, access_token, account_email.
    Optional: refresh_token, cloud_host, elevenlabs_key, elevenlabs_agent.

    Auth-gated. Sensitive — same exposure as /admin/bambu_login since
    we're stamping a long-lived access_token onto a row.
    """
    _auth(x_relay_secret)
    duck_id = payload.get("duck_id")
    user_id = payload.get("bambu_user_id")
    access_token = payload.get("access_token")
    account_email = payload.get("account_email")
    if not all([duck_id, user_id, access_token, account_email]):
        raise HTTPException(400, "duck_id, bambu_user_id, access_token, "
                                  "account_email all required")

    try:
        devices = await bambu_cloud.list_devices(access_token)
    except bambu_cloud.LoginError as e:
        raise HTTPException(502, detail={
            "code": "list_devices_failed", "message": str(e)})
    if not devices:
        raise HTTPException(404, "Bambu account has no bound printers")

    serials = [d["dev_id"] for d in devices]
    printer_names = [d.get("name", "") for d in devices]
    cloud_host = payload.get("cloud_host") or DEFAULT_CLOUD_HOST

    upsert_kwargs = {
        "bambu_user_id": user_id,
        "access_token": access_token,
        "account_email": account_email,
        "serials": serials,
        "printer_names": printer_names,
        "cloud_host": cloud_host,
    }
    if payload.get("refresh_token"):
        upsert_kwargs["refresh_token"] = payload["refresh_token"]
    if payload.get("elevenlabs_key"):
        upsert_kwargs["elevenlabs_key"] = payload["elevenlabs_key"]
    if payload.get("elevenlabs_agent"):
        upsert_kwargs["elevenlabs_agent"] = payload["elevenlabs_agent"]
    db.get().upsert_duck(duck_id, **upsert_kwargs)

    # Spin up (or reconfigure) the BambuState. Same flow as bambu_login.
    s = states.get(duck_id)
    if s is None:
        row = db.get().get_duck(duck_id) or {}
        s = _state_from_row(row)
        states[duck_id] = s
        s.start()
        register_bambu_listener(duck_id, s)
    else:
        s.reconfigure(
            host=cloud_host,
            username=f"u_{user_id}",
            password=access_token,
            serials=serials,
            printer_names=printer_names,
            verify_tls=True,
        )

    return {
        "ok": True,
        "duck_id": duck_id,
        "printers": [
            {"serial": d["dev_id"], "name": d.get("name", ""),
             "online": d.get("online", False)}
            for d in devices
        ],
    }


@app.post("/admin/rebind_printers/{duck_id}")
async def rebind_printers(duck_id: str,
                          x_relay_secret: str | None = Header(default=None)):
    """Re-list this duck's Bambu account and update the bound printer
    set to ALL printers in the account, no re-onboarding needed.

    Useful after the multi-printer #41 cutover for ducks that were
    bound to a single printer pre-migration: pre-migration each
    bambu_login picked one. This endpoint re-runs list_devices with
    the stored access_token and writes back the full set.

    Auth-gated (sensitive: re-issues MQTT subscriptions).
    """
    _auth(x_relay_secret)
    row = db.get().get_duck(duck_id)
    if not row or not row.get("access_token"):
        raise HTTPException(404, "duck not found or has no Bambu binding")

    try:
        devices = await bambu_cloud.list_devices(row["access_token"])
    except bambu_cloud.LoginError as e:
        raise HTTPException(502, detail={
            "code": "list_devices_failed",
            "message": str(e),
        })
    if not devices:
        raise HTTPException(404, detail={
            "code": "no_printers",
            "message": "Bambu account has no bound printers",
        })

    serials = [d["dev_id"] for d in devices]
    printer_names = [d.get("name", "") for d in devices]
    db.get().upsert_duck(duck_id, serials=serials, printer_names=printer_names)

    s = states.get(duck_id)
    if s is not None:
        s.reconfigure(
            host=row.get("cloud_host") or DEFAULT_CLOUD_HOST,
            username=f"u_{row['bambu_user_id']}",
            password=row["access_token"],
            serials=serials,
            printer_names=printer_names,
            verify_tls=True,
        )

    return {
        "ok": True,
        "duck_id": duck_id,
        "printers": [
            {"serial": d["dev_id"], "name": d.get("name", ""),
             "online": d.get("online", False)}
            for d in devices
        ],
    }


@app.get("/admin/bambu_status/{duck_id}")
def bambu_status_scoped(duck_id: str,
                        x_relay_secret: str | None = Header(default=None)):
    """Per-duck status: mode, all bound printers, live MQTT connection
    state. Auth-gated because the response includes account_email."""
    _auth(x_relay_secret)
    row = db.get().get_duck(duck_id)
    s = states.get(duck_id)
    info = {
        "duck_id": duck_id,
        "mode": "cloud" if (row and row.get("access_token")) else "lan",
        "host": s.host if s else None,
        "user_id": row.get("bambu_user_id") if row else None,
        "account_email": row.get("account_email") if row else None,
        # Multi-printer #41 — full bound list. Legacy `serial` /
        # `printer_name` kept as the [0] of each for back-compat.
        "serials": (s.serials if s else []) or [],
        "printer_names": (s.printer_names if s else []) or [],
        "serial": s.serial if s else None,
        "printer_name": s.printer_name if s else None,
    }
    if s is not None:
        try:
            info["connected"] = bool(s._client.is_connected())
        except Exception:
            info["connected"] = False
        info["auth_failed"] = getattr(s, "auth_failed", False)
        info["last_message_age_ms"] = s.last_message_age_ms()
    return info


@app.get("/admin/bambu_status")
def bambu_status_compat(x_relay_secret: str | None = Header(default=None)):
    return bambu_status_scoped(_resolve_duck_id(None), x_relay_secret)
