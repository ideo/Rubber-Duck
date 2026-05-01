"""Convai webhook target. Three GET tools the LLM can call mid-conversation."""
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
from bambu_state import BambuState
from duck_proxy import router as duck_router, register_bambu_listener

load_dotenv()

logger = logging.getLogger("main")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:main: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False

state: BambuState | None = None

# Saved cloud-mode credentials (so the relay can come up in cloud mode after
# a restart without the duck having to re-onboard). Single-entry today; will
# become a dict keyed by duck_id when multi-tenant lands (#31).
TOKENS_PATH = Path(__file__).parent / "tokens.json"

# Default cloud broker. Bambu has US, EU, and CN regional brokers — the
# user_id is global so any region works, but lower-latency to the user's
# region. Override via env if needed.
DEFAULT_CLOUD_HOST = os.environ.get("BAMBU_CLOUD_HOST", "us.mqtt.bambulab.com")


def _load_tokens() -> dict | None:
    if not TOKENS_PATH.exists():
        return None
    # Defensive: heal permissions if a prior version wrote with default umask.
    # Only chmod if the current mode is more permissive than 0600 to avoid
    # surprising the operator who may have intentionally tightened it further.
    try:
        mode = TOKENS_PATH.stat().st_mode & 0o777
        if mode & 0o077:  # any group/other bits set
            os.chmod(TOKENS_PATH, 0o600)
            logger.info("tokens.json perms hardened to 0600 (was %o)", mode)
    except OSError:
        pass
    try:
        return json.loads(TOKENS_PATH.read_text())
    except Exception as e:
        logger.warning("tokens.json unreadable (%s) — starting in LAN/env mode", e)
        return None


def _save_tokens(d: dict) -> None:
    """Atomic write + 0600 perms. The temp-file + rename pattern protects
    against partial writes if the process crashes mid-write or two
    /admin/bambu_login calls race (the asyncio.Lock prevents the latter
    in normal flow, but defensive). Permissions stay 0600 since the file
    holds access_token + refresh_token + account_email."""
    tmp = TOKENS_PATH.with_suffix(".json.tmp")
    fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(d, f, indent=2)
    os.replace(tmp, TOKENS_PATH)
    # Make sure perms are 0600 even if the file already existed (umask).
    os.chmod(TOKENS_PATH, 0o600)
    logger.info("tokens.json updated (user_id=%s, serial=%s)",
                d.get("user_id"), d.get("serial"))


# Serializes /admin/bambu_login calls so two concurrent attempts can't race
# the tokens.json write or hammer Bambu's API in a way that looks botty.
# Created lazily inside the endpoint (FastAPI's lifespan-startup runs in a
# different loop than the request handlers in some hot-reload setups).
_login_lock: asyncio.Lock | None = None


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global state
    tokens = _load_tokens()

    if tokens:
        # Cloud mode — the user has logged in to Bambu cloud previously and
        # we have their saved access_token + selected printer serial.
        logger.info("starting in CLOUD mode (loaded tokens.json)")
        state = BambuState(
            host=DEFAULT_CLOUD_HOST,
            username=f"u_{tokens['user_id']}",
            password=tokens["access_token"],
            serial=tokens["serial"],
            verify_tls=True,
        )
    else:
        # LAN mode — fall back to env-var configuration. This is the path
        # used during development and before the duck has done OAuth.
        logger.info("starting in LAN mode (no tokens.json)")
        state = BambuState(
            host=os.environ.get("BAMBU_HOST", "mock"),
            username="bblp",
            password=os.environ.get("BAMBU_ACCESS_CODE", "mock"),
            serial=os.environ.get("BAMBU_SERIAL", "mock"),
            verify_tls=False,
        )

    if os.environ.get("MOCK") == "1":
        # Mock mode: don't connect to a broker, let mock_printer.py drive state via injection.
        from mock_printer import drive_in_thread
        drive_in_thread(state)
    else:
        state.start()
    # Wire notification fan-out. Captures the asyncio loop so the MQTT
    # thread's listener can dispatch back here.
    register_bambu_listener(state)
    yield
    if os.environ.get("MOCK") != "1":
        state.stop()


app = FastAPI(lifespan=lifespan)
app.include_router(duck_router)


def _auth(secret: str | None) -> None:
    expected = os.environ.get("RELAY_SHARED_SECRET")
    if expected and secret != expected:
        raise HTTPException(401, "bad shared secret")


@app.get("/health")
def health():
    return {"ok": True, "connected": state is not None and bool(state.snapshot())}


@app.get("/tools/printer_state")
def printer_state(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return state.snapshot()


@app.get("/tools/temperatures")
def temperatures(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return state.temperatures()


@app.get("/tools/print_history")
def print_history(n: int = 5, x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return {"history": state.history(max(1, min(n, 20)))}


@app.get("/admin/raw_state")
def raw_state():
    """Dump the FULL Bambu push_status payload so we can see what fields
    are available. No auth — local diagnostic only."""
    return state._state if state else {}


@app.post("/admin/bambu_login")
async def bambu_login_endpoint(payload: dict, x_relay_secret: str | None = Header(default=None)):
    """Log the relay into a Bambu cloud account.

    Body: {"email": str, "password": str, "code": str|""}
    On success: stops the LAN/previous MQTT client, opens a new one against
    Bambu's cloud broker (us.mqtt.bambulab.com:8883) authenticated as
    u_<userId> / <accessToken>, persists the token to tokens.json, and
    returns the chosen printer's serial.

    On 2FA-required: returns HTTP 401 with code "2fa_required" so the duck
    or duck.local recovery page can re-prompt for the code.

    Single-tenant for now: the relay holds ONE token at a time. Multi-tenant
    rework lives behind #31 — body will gain duck_id, tokens.json becomes a
    dict, MQTT clients become a per-account pool."""
    global _login_lock
    if _login_lock is None:
        _login_lock = asyncio.Lock()

    _auth(x_relay_secret)
    email = payload.get("email")
    password = payload.get("password")
    code = payload.get("code") or None
    # user_id auto-derived from /preference now (see bambu_cloud.fetch_uid).
    # Override remains as a fallback if /preference fails; body wins, env
    # BAMBU_USER_ID as fallback.
    user_id_override = payload.get("user_id") or os.environ.get("BAMBU_USER_ID")
    if not email or not password:
        raise HTTPException(400, "email and password required")

    # Serialize concurrent login attempts. Bambu has been known to crack
    # down on bot-shaped traffic; serializing keeps us from accidentally
    # firing two POSTs in quick succession.
    async with _login_lock:
        try:
            result = await bambu_cloud.login(email, password, code, user_id_override)
        except bambu_cloud.TwoFARequired as e:
            raise HTTPException(401, detail={"code": "2fa_required", "message": str(e)})
        except bambu_cloud.LoginError as e:
            raise HTTPException(401, detail={"code": "login_failed", "message": str(e)})

    # Pick which printer on the account to subscribe to. Strategy:
    #   1. If BAMBU_SERIAL env var is set AND that serial appears in the
    #      account's device list, use it (lets the operator pin a specific
    #      printer when an account has multiple).
    #   2. Otherwise prefer the first online printer.
    #   3. Otherwise fall back to the first printer in the list.
    try:
        devices = await bambu_cloud.list_devices(result["access_token"])
    except bambu_cloud.LoginError as e:
        raise HTTPException(502, detail={"code": "list_devices_failed", "message": str(e)})

    if not devices:
        raise HTTPException(404, detail={"code": "no_printers", "message": "Bambu account has no bound printers"})

    pinned = os.environ.get("BAMBU_SERIAL")
    chosen = None
    if pinned:
        chosen = next((d for d in devices if d.get("dev_id") == pinned), None)
    if chosen is None:
        chosen = next((d for d in devices if d.get("online")), devices[0])
    serial = chosen["dev_id"]

    # Persist for restart resilience BEFORE swapping MQTT — if the swap
    # fails the user can still inspect tokens.json, and a restart will
    # come up in cloud mode with the saved creds.
    _save_tokens({
        "access_token": result["access_token"],
        "refresh_token": result["refresh_token"],
        "user_id": result["user_id"],
        "serial": serial,
        "account_email": email,  # for display / debugging only
    })

    # Swap the live MQTT client to cloud. Listeners (fire_notification) and
    # active /ws/duck sessions survive — only the broker connection changes.
    state.reconfigure(
        host=DEFAULT_CLOUD_HOST,
        username=f"u_{result['user_id']}",
        password=result["access_token"],
        serial=serial,
        verify_tls=True,
    )

    return {
        "ok": True,
        "user_id": result["user_id"],
        "serial": serial,
        "printer_name": chosen.get("name", "(unknown)"),
        "online": chosen.get("online", False),
    }


@app.get("/admin/bambu_status")
def bambu_status(x_relay_secret: str | None = Header(default=None)):
    """Quick status summary — what mode the relay is in, which printer is
    bound, whether MQTT is actually connected (vs configured-but-failing).

    Auth-gated because the response includes account_email and user_id —
    not catastrophic but no reason to leak on an open LAN."""
    _auth(x_relay_secret)
    tokens = _load_tokens()
    info = {
        "mode": "cloud" if tokens else "lan",
        "host": state.host if state else None,
        "serial": state.serial if state else None,
        "user_id": tokens.get("user_id") if tokens else None,
        "account_email": tokens.get("account_email") if tokens else None,
    }
    if state is not None:
        # Live MQTT connection state (vs just "tokens.json exists").
        try:
            info["connected"] = bool(state._client.is_connected())
        except Exception:
            info["connected"] = False
        info["auth_failed"] = getattr(state, "auth_failed", False)
        info["last_message_age_ms"] = state.last_message_age_ms()
    return info
