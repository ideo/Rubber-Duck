"""Bambu cloud account API client — login + device enumeration.

There is no documented OAuth2 flow for third-party Bambu integrations. The
community-standard pattern (used by ha-bambulab, bambu-farm, OctoEverywhere,
etc.) is a password-based login API:

    POST https://api.bambulab.com/v1/user-service/user/login
         { "account": "<email>", "password": "<pw>", "code": "<2fa-or-empty>" }
    -> { "accessToken": "<jwt>", "refreshToken": "...", "expiresIn": ... }

The accessToken is a JWT whose `username` claim is `u_<userId>` — the same
value used as the MQTT username on Bambu's cloud broker:

    broker:    us.mqtt.bambulab.com:8883  (or eu./cn. regional)
    username:  u_<userId>
    password:  <accessToken>
    topics:    device/<serial>/report  (same as LAN protocol)

This module is the relay's sole interface to Bambu's HTTP APIs. MQTT lives
in bambu_state.py.

Token refresh is TODO (#31 follow-up). Tokens last ~30 days from observation;
v1 just stores the access_token and re-prompts the user when it expires.
"""
from __future__ import annotations

import base64
import json
import logging
from typing import Any, Optional

import httpx

logger = logging.getLogger("bambu_cloud")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:bambu_cloud: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False

LOGIN_URL = "https://api.bambulab.com/v1/user-service/user/login"
DEVICES_URL = "https://api.bambulab.com/v1/iot-service/api/user/bind"
PREFERENCE_URL = "https://api.bambulab.com/v1/design-user-service/my/preference"


def _safe_response_summary(text: str) -> str:
    """Truncate + redact obvious token-ish substrings from a response body
    before letting it appear in log lines or HTTP error details. Bambu's
    error responses aren't supposed to contain tokens, but defensive."""
    s = text[:200]
    # Anything that looks like a long base64-ish string after "token" gets
    # masked. Cheap heuristic — tokens here are 100+ chars of base64.
    import re
    s = re.sub(r'("(?:access|refresh)Token"\s*:\s*")[^"]+(")', r'\1<redacted>\2', s, flags=re.IGNORECASE)
    return s


class LoginError(Exception):
    """Bambu's login API rejected the credentials, returned a non-200, or the
    response was malformed. Message includes the underlying detail."""


class TwoFARequired(LoginError):
    """Bambu requires a 2FA code and the form was submitted without one. The
    captive portal can re-prompt or the duck.local recovery page can collect
    the code and retry."""


async def login(email: str, password: str, code: Optional[str] = None,
                user_id_override: Optional[str] = None) -> dict[str, Any]:
    """POST credentials to Bambu's login endpoint.

    Bambu's API has changed shape across firmware revisions — sometimes the
    accessToken is a JWT (with `username = u_<userId>` claim), sometimes
    opaque, sometimes user_id appears as a top-level field in the response.
    To stay resilient, the caller can pass user_id_override (e.g. from an
    env var or user-typed setup field — Bambu shows it on
    bambulab.com/account). When provided, we skip extraction entirely.

    Returns:
        {"access_token": str, "refresh_token": str, "expires_in": int, "user_id": str}

    Raises:
        TwoFARequired — Bambu wants a 2FA code (re-call with code= set).
        LoginError    — anything else: bad password, network, malformed response.
    """
    body = {"account": email, "password": password, "code": code or ""}
    headers = {"Content-Type": "application/json"}
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            r = await client.post(LOGIN_URL, json=body, headers=headers)
        except httpx.HTTPError as e:
            raise LoginError(f"login HTTP error: {e}") from e

    if r.status_code != 200:
        # Pass through the body but with the access_token redacted in case
        # Bambu ever returns a partial token alongside an error. Belt and
        # suspenders — historically their error responses don't include
        # tokens, but this prevents log/HTTP-detail leakage if that changes.
        raise LoginError(f"login HTTP {r.status_code}: {_safe_response_summary(r.text)}")

    try:
        data = r.json()
    except json.JSONDecodeError:
        raise LoginError(f"login non-JSON response: {r.text[:200]}")

    token = data.get("accessToken")
    if not token:
        # No accessToken in a 200 response means the login was structurally OK
        # but rejected with an error code. Sniff for 2FA-ish text + use
        # the documented `loginType="verifyCode"` signal. Don't dump the
        # raw `data` dict in the error — it could contain a tfaKey or any
        # future credential-shaped field; whitelist safe keys only.
        err_msg = str(data.get("error", data.get("message", "")))
        if (data.get("loginType") == "verifyCode"
                or "verify" in err_msg.lower()
                or "2fa" in err_msg.lower()
                or "two-factor" in err_msg.lower()):
            raise TwoFARequired(err_msg or "verification code required")
        raise LoginError(
            f"login response missing accessToken; "
            f"loginType={data.get('loginType')!r} error={err_msg!r}"
        )

    # Resolve user_id. Order of preference:
    #   1. Caller-provided override (bombproof — user reads it off bambulab.com).
    #   2. /preference endpoint (clean — auto-derives from access_token).
    #   3. JWT parse (legacy — works only when Bambu still ships JWT tokens).
    #   4. Known response body fields.
    # Each falls through to the next on failure. (3) and (4) are dead in
    # current Bambu firmware but kept as forward-compat in case they fix.
    logger.info("login response keys: %s", sorted(data.keys()))
    user_id: Optional[str] = None

    if user_id_override:
        cleaned = user_id_override.strip().lower()
        if cleaned.startswith("user_"):
            cleaned = cleaned[5:]
        elif cleaned.startswith("u_"):
            cleaned = cleaned[2:]
        if cleaned and cleaned.isdigit():
            user_id = cleaned
            logger.info("user_id from override = %s", user_id)
        else:
            logger.warning("user_id_override %r isn't bare digits after strip — ignoring",
                           user_id_override)

    if not user_id:
        # /preference endpoint — the canonical path. Costs one extra HTTPS GET.
        user_id = await fetch_uid(token)
        if user_id:
            logger.info("user_id from /preference = %s", user_id)

    if not user_id:
        try:
            user_id = _user_id_from_jwt(token)
            logger.info("user_id from JWT (legacy) = %s", user_id)
        except LoginError:
            pass

    if not user_id:
        for key in ("uid", "userId", "user_id", "id"):
            v = data.get(key)
            if v:
                user_id = str(v)
                logger.info("user_id from response[%r] = %s", key, user_id)
                break

    if not user_id:
        raise LoginError(
            "login succeeded but user_id could not be resolved. "
            "Try passing user_id explicitly (find it at bambulab.com/account)."
        )
    logger.info("login OK for user_id=%s", user_id)
    return {
        "access_token": token,
        "refresh_token": data.get("refreshToken", ""),
        "expires_in": int(data.get("expiresIn", 0)),
        "user_id": user_id,
    }


async def list_devices(access_token: str) -> list[dict]:
    """GET the user's bound printers. Returns the raw list, each item
    typically including dev_id (serial), name, online (bool), dev_model_name,
    and other metadata. Caller picks which printer to subscribe to."""
    headers = {"Authorization": f"Bearer {access_token}"}
    async with httpx.AsyncClient(timeout=15.0) as client:
        r = await client.get(DEVICES_URL, headers=headers)
    if r.status_code != 200:
        raise LoginError(f"list devices HTTP {r.status_code}: {_safe_response_summary(r.text)}")
    return r.json().get("devices", [])


async def fetch_uid(access_token: str) -> Optional[str]:
    """GET /v1/design-user-service/my/preference — returns user info
    including `uid` (an integer). The MQTT username is `u_<uid>`. Used to
    auto-resolve the user_id without making the user type it.

    This is the one Bambu API path that reliably returns user_id given
    only the access_token (the access_token itself is no longer a
    parseable JWT, and the login response body doesn't include user_id).
    Source: OpenBambuAPI/cloud-http.md and pybambu's BambuUrl.PREFERENCE.

    Returns the bare uid as a string, or None if the call fails (caller
    falls back to user_id_override or a re-prompt)."""
    headers = {"Authorization": f"Bearer {access_token}"}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            r = await client.get(PREFERENCE_URL, headers=headers)
        if r.status_code != 200:
            logger.warning("/preference HTTP %s; falling back to override path",
                           r.status_code)
            return None
        data = r.json()
    except (httpx.HTTPError, json.JSONDecodeError) as e:
        logger.warning("/preference fetch failed: %s; falling back to override", e)
        return None
    uid = data.get("uid")
    if uid is None:
        logger.warning("/preference response missing 'uid'; keys=%s",
                       sorted(data.keys()))
        return None
    return str(uid)


def _user_id_from_jwt(jwt: str) -> str:
    """Extract `username` from the JWT payload — Bambu's tokens carry it as
    `u_<userId>`. We only read the claim; signature verification isn't
    necessary because the token's authenticity is established by the
    successful login round-trip and confirmed when MQTT auth succeeds with
    the resulting credentials.
    """
    parts = jwt.split(".")
    if len(parts) != 3:
        raise LoginError("malformed JWT (expected 3 parts)")
    # Re-pad the base64 payload — JWT uses urlsafe-b64 without padding.
    payload_b64 = parts[1] + "=" * (-len(parts[1]) % 4)
    try:
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
    except Exception as e:
        raise LoginError(f"JWT payload decode failed: {e}") from e
    username = payload.get("username") or payload.get("sub", "")
    if not username:
        raise LoginError(f"JWT payload missing username: {payload}")
    # Strip the `u_` prefix so callers can compose the MQTT username
    # themselves (it's always `u_<userId>` — the prefix is constant).
    return username[2:] if username.startswith("u_") else username
