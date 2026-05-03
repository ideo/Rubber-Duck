"""Convai webhook target. Per-duck tools the LLM can call mid-conversation.

Multi-tenant since 2026-05-03 (#31): the relay holds N BambuState
instances, one per duck_id, in the `states` registry. Routes that the
ElevenLabs agent calls are now path-scoped (`/tools/printer_state/{duck_id}`).
Old un-scoped routes are kept as compatibility shims that resolve to the
"default" duck (oldest row in the DB) so existing chip firmware and a
pre-update ElevenLabs agent config keep working through the cutover.

The cutover plan, per bambu/docs/MULTI-TENANT-REQ.md:
1. Land this PR — relay becomes multi-tenant, existing duck still works
   as-is via compat shims.
2. Update chip firmware to send `X-Duck-Id` on /ws/notify and /ws/duck
   handshakes (separate PR; tracked in #31).
3. Update ElevenLabs agent's tool URLs to include the duck_id (manual,
   per-tenant — done via the setup helper page; tracked in #48).
4. Drop compat shims — search "# COMPAT" markers.
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
    code). One BambuState per duck — they don't share clients or threads."""
    if row.get("access_token") and row.get("bambu_user_id"):
        return BambuState(
            host=row.get("cloud_host") or DEFAULT_CLOUD_HOST,
            username=f"u_{row['bambu_user_id']}",
            password=row["access_token"],
            serial=row.get("serial") or "",
            verify_tls=True,
            printer_name=row.get("printer_name") or "",
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
    if not rows and os.environ.get("MOCK") != "1":
        # Empty DB and not in mock mode = LAN-ish dev install with no
        # tokens. Spin up one "legacy" state so /health and the wizard
        # path keep working until a duck actually onboards.
        logger.info("no ducks in DB — starting in LAN/env mode under id=%s",
                    LEGACY_DUCK_ID)
        s = _state_from_row({})
        states[LEGACY_DUCK_ID] = s
        if os.environ.get("MOCK") == "1":
            from mock_printer import drive_in_thread
            drive_in_thread(s)
        else:
            s.start()
        register_bambu_listener(LEGACY_DUCK_ID, s)
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


def _resolve_duck_id(duck_id: str | None) -> str:
    """Compat helper: explicit duck_id wins; otherwise fall back to the
    DB's default (oldest row). Raises 404 if the DB is empty.

    Used by the un-scoped compat routes. Once chip firmware + ElevenLabs
    agent both send duck_id everywhere, this helper goes away (search
    `# COMPAT` to find all the call sites)."""
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


# ---- COMPAT: un-scoped tools (resolve to default duck) -------------------
# Kept so a pre-update ElevenLabs agent config keeps working during the
# cutover. Drop these and `_resolve_duck_id` once all tenants have moved
# their tool URLs to the path-scoped variants above.


@app.get("/tools/printer_state")  # COMPAT
def printer_state_compat(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return _state_for(_resolve_duck_id(None)).snapshot()


@app.get("/tools/temperatures")  # COMPAT
def temperatures_compat(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return _state_for(_resolve_duck_id(None)).temperatures()


@app.get("/tools/print_history")  # COMPAT
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


@app.get("/admin/raw_state")  # COMPAT
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
        out.append({
            "duck_id": r["duck_id"],
            "account_email": r.get("account_email"),
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
    duck_id = payload.get("duck_id") or _resolve_duck_id(None)  # COMPAT
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

    pinned = os.environ.get("BAMBU_SERIAL")
    chosen = None
    if pinned:
        chosen = next((d for d in devices if d.get("dev_id") == pinned), None)
    if chosen is None:
        chosen = next((d for d in devices if d.get("online")), devices[0])
    serial = chosen["dev_id"]
    printer_name = chosen.get("name", "")

    # Persist on the duck's row. upsert_duck preserves any other fields
    # already set (cloud_host, elevenlabs_*) since we pass only what's new.
    db.get().upsert_duck(
        duck_id,
        access_token=result["access_token"],
        refresh_token=result["refresh_token"],
        bambu_user_id=result["user_id"],
        serial=serial,
        printer_name=printer_name,
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
            serial=serial,
            verify_tls=True,
            printer_name=printer_name,
        )

    return {
        "duck_id": duck_id,
        "user_id": result["user_id"],
        "serial": serial,
        "printer_name": printer_name or "(unknown)",
        "online": chosen.get("online", False),
    }


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


@app.get("/admin/bambu_status/{duck_id}")
def bambu_status_scoped(duck_id: str,
                        x_relay_secret: str | None = Header(default=None)):
    """Per-duck status: mode, printer binding, live MQTT connection
    state. Auth-gated because the response includes account_email."""
    _auth(x_relay_secret)
    row = db.get().get_duck(duck_id)
    s = states.get(duck_id)
    info = {
        "duck_id": duck_id,
        "mode": "cloud" if (row and row.get("access_token")) else "lan",
        "host": s.host if s else None,
        "serial": s.serial if s else None,
        "user_id": row.get("bambu_user_id") if row else None,
        "account_email": row.get("account_email") if row else None,
        "printer_name": row.get("printer_name") if row else None,
    }
    if s is not None:
        try:
            info["connected"] = bool(s._client.is_connected())
        except Exception:
            info["connected"] = False
        info["auth_failed"] = getattr(s, "auth_failed", False)
        info["last_message_age_ms"] = s.last_message_age_ms()
    return info


@app.get("/admin/bambu_status")  # COMPAT
def bambu_status_compat(x_relay_secret: str | None = Header(default=None)):
    return bambu_status_scoped(_resolve_duck_id(None), x_relay_secret)
