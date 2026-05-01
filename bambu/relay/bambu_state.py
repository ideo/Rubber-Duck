"""Subscribe to a Bambu printer's local MQTT broker and keep a live state snapshot.

Bambu's `push_status` is delta-push: a full snapshot lands on subscribe, then
only changed fields. We merge into a single dict that tools can read.

Also fires registered listener callbacks when notable events happen (FINISH /
FAILED transitions, new HMS errors). The notification proxy uses these to
push events to connected ducks.
"""
from __future__ import annotations

import json
import logging
import ssl
import threading
import time
from collections import deque
from typing import Any, Callable, List

import paho.mqtt.client as mqtt

logger = logging.getLogger("bambu_state")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:bambu_state: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False


class BambuState:
    """Subscribes to a Bambu MQTT broker and accumulates `print` push_status
    deltas into a single state snapshot.

    Two broker modes (same code path, different auth):
      LAN mode    — host=<printer-ip>, username="bblp", password=<access_code>
                    self-signed cert (verify disabled).
      Cloud mode  — host="us.mqtt.bambulab.com", username=f"u_{user_id}",
                    password=<access_token from bambu_cloud.login>.
                    Real publicly-trusted cert (verify enabled).

    Switching modes happens via reconfigure() — same instance, listeners
    survive, callers (duck_proxy.py) don't need to know which broker we're
    talking to.
    """

    def __init__(self, host: str, username: str, password: str, serial: str,
                 verify_tls: bool = False):
        self.host = host
        self.username = username
        self.password = password
        self.serial = serial
        self.verify_tls = verify_tls
        self._lock = threading.Lock()
        self._state: dict[str, Any] = {}
        self._history: deque[dict] = deque(maxlen=20)
        self._last_stage: str | None = None
        self._last_hms: set | None = None  # set of HMS codes seen on prior payload
        self._listeners: List[Callable[[dict], None]] = []
        # auth_failed surfaces "Bambu rejected our credentials" (CONNACK
        # rc=5/4) so /admin/bambu_status and the duck.local recovery page
        # can prompt for re-login. Without this, an expired token just
        # makes paho retry forever in silence.
        self.auth_failed: bool = False
        self._last_message_ts: float = 0.0  # epoch seconds of last on_message
        self._client = self._build_client()

    def add_listener(self, cb: Callable[[dict], None]) -> None:
        """Register a callback fired on notable events. Called with a dict like
        {"type": "finish", "subtask": "..."} or {"type": "failed", "subtask": "..."}.
        Callback runs on the MQTT thread — keep it fast / non-blocking."""
        self._listeners.append(cb)

    def _fire(self, event: dict) -> None:
        for cb in list(self._listeners):
            try:
                cb(event)
            except Exception:
                pass

    def _build_client(self) -> mqtt.Client:
        c = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"duck-relay-{int(time.time())}")
        c.username_pw_set(self.username, self.password)
        ctx = ssl.create_default_context()
        if not self.verify_tls:
            # LAN-mode default: printer ships self-signed cert. Cloud mode
            # passes verify_tls=True and uses the real CA chain.
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
        c.tls_set_context(ctx)
        c.on_connect = self._on_connect
        c.on_disconnect = self._on_disconnect
        c.on_message = self._on_message
        # Auto-reconnect: paho retries on disconnect with exponential backoff,
        # capped at 60s. Combined with connect_async, this means the relay
        # weathers the printer being briefly unreachable (WiFi roam, AP
        # change, brief power blip) without operator intervention.
        c.reconnect_delay_set(min_delay=1, max_delay=60)
        return c

    def start(self) -> None:
        # connect_async + loop_start = non-blocking initial connect. If the
        # broker is unreachable when the relay boots, the relay still starts
        # and serves /ws/duck etc — the MQTT loop keeps trying in the
        # background. Was previously synchronous .connect() which raised on
        # any failure and crashed uvicorn lifespan startup.
        logger.info("connecting to MQTT %s:8883 as %s (async, will retry on failure)",
                    self.host, self.username)
        self._client.connect_async(self.host, 8883, keepalive=60)
        self._client.loop_start()

    def stop(self) -> None:
        self._client.loop_stop()
        self._client.disconnect()

    def reconfigure(self, host: str, username: str, password: str, serial: str,
                    verify_tls: bool = False) -> None:
        """Swap broker / credentials at runtime. Used by /admin/bambu_login
        when the user signs in to Bambu cloud — relay transitions from LAN
        mode (or unconfigured) to cloud mode without restarting the process,
        which means listeners (fire_notification) survive and active /ws/duck
        sessions don't drop. Stops the old MQTT client first to avoid two
        clients ever being live simultaneously."""
        logger.info("reconfiguring MQTT: %s@%s (serial=%s, verify_tls=%s)",
                    username, host, serial, verify_tls)
        self.stop()
        # Reset incremental state — the previous broker's last_stage/_last_hms
        # would otherwise leak into the cloud session and suppress legitimate
        # transitions (e.g. relay would skip the first FINISH event because
        # _last_stage already says "FINISH" from the LAN session).
        with self._lock:
            self._last_stage = None
            self._last_hms = None
            self._state = {}
        self.host = host
        self.username = username
        self.password = password
        self.serial = serial
        self.verify_tls = verify_tls
        self._client = self._build_client()
        self.start()

    def _on_disconnect(self, _client, _ud, _flags, rc, _props=None):
        # paho will auto-reconnect (reconnect_delay_set above). This callback
        # is purely so we can SEE drops in the log.
        logger.warning("MQTT disconnected (rc=%s) — paho will auto-reconnect", rc)

    def _on_connect(self, client, _ud, _flags, rc, _props=None):
        if rc == 0:
            self.auth_failed = False
            logger.info("MQTT connected; subscribing to device/%s/report and requesting pushall",
                        self.serial)
            client.subscribe(f"device/{self.serial}/report")
            # nudge printer to send a full snapshot
            client.publish(
                f"device/{self.serial}/request",
                json.dumps({"pushing": {"sequence_id": "0", "command": "pushall"}}),
            )
        else:
            # rc 4 = bad username/password (legacy MQTT 3.1)
            # rc 5 = not authorized (legacy MQTT 3.1)
            # rc 134 = bad user name or password (MQTT 5)
            # rc 135 = not authorized (MQTT 5)
            # All four mean Bambu rejected our credentials; the access_token
            # has expired or the user revoked the device. Surface via
            # auth_failed so /admin/bambu_status reports it and the recovery
            # path on duck.local can prompt for re-login.
            if rc in (4, 5, 134, 135):
                self.auth_failed = True
                logger.warning("MQTT auth rejected (rc=%s) — token likely expired; "
                               "set self.auth_failed=True", rc)
            else:
                logger.warning("MQTT connect callback rc=%s (non-zero = failure)", rc)

    def _on_message(self, _client, _ud, msg):
        self._last_message_ts = time.time()
        try:
            payload = json.loads(msg.payload)
        except json.JSONDecodeError:
            return
        self.handle_payload(payload)

    def last_message_age_ms(self) -> int | None:
        """How long ago we got an MQTT message, in ms. None if never received.
        Used by /admin/bambu_status as a "is data still flowing?" check —
        a long age while connected=True suggests the printer is offline
        or we subscribed to the wrong serial."""
        if self._last_message_ts == 0.0:
            return None
        return int((time.time() - self._last_message_ts) * 1000)

    def handle_payload(self, payload: dict) -> None:
        """Merge a push_status payload into state. Public so tests/mocks can inject."""
        push = payload.get("print")
        if not push:
            return
        with self._lock:
            self._state.update(push)
            stage = push.get("gcode_state")
            subtask = self._state.get("subtask_name")

            if stage and stage != self._last_stage:
                # Record terminal-state arrival as history.
                if stage in ("FINISH", "FAILED"):
                    self._history.append({
                        "ts": time.time(),
                        "outcome": stage,
                        "subtask": subtask,
                        "duration_min": self._state.get("mc_print_sub_stage"),
                    })

                # Fire notifications on real transitions only (not startup-seed).
                if self._last_stage is not None:
                    # Print started (was idle/finished, now actively prepping/running)
                    if stage in ("PREPARE", "RUNNING") and \
                       self._last_stage in ("IDLE", "FINISH", "FAILED", None):
                        self._fire({"type": "start", "subtask": subtask})
                    elif stage == "FINISH":
                        self._fire({"type": "finish", "subtask": subtask})
                    elif stage == "FAILED":
                        self._fire({"type": "failed", "subtask": subtask})
                    elif stage == "PAUSE":
                        self._fire({"type": "pause", "subtask": subtask})
                    elif stage == "RUNNING" and self._last_stage == "PAUSE":
                        self._fire({"type": "resume", "subtask": subtask})

                self._last_stage = stage

            # HMS error code arrivals (was clear, now flagging something).
            # Skip the field entirely if the push didn't include hms — Bambu
            # delta-pushes mean a missing key just means "no change".
            if "hms" in push:
                new_hms = {h.get("attr") for h in (push.get("hms") or []) if h.get("attr")}
                if self._last_hms is None:
                    # First snapshot — seed without firing
                    self._last_hms = new_hms
                else:
                    added = new_hms - self._last_hms
                    if added:
                        self._fire({"type": "hms", "codes": list(added), "subtask": subtask})
                    self._last_hms = new_hms

    # ---- read-side helpers (called from web thread) ----

    def snapshot(self) -> dict:
        with self._lock:
            s = self._state
            return {
                "stage": s.get("gcode_state"),
                "subtask": s.get("subtask_name"),
                "percent": s.get("mc_percent"),
                "layer": s.get("layer_num"),
                "total_layers": s.get("total_layer_num"),
                "remaining_min": s.get("mc_remaining_time"),
                "nozzle_target_c": s.get("nozzle_target_temper"),
                "nozzle_c": s.get("nozzle_temper"),
                "bed_target_c": s.get("bed_target_temper"),
                "bed_c": s.get("bed_temper"),
                "chamber_c": s.get("chamber_temper"),
                "hms_codes": [h.get("attr") for h in (s.get("hms") or [])],
            }

    def temperatures(self) -> dict:
        s = self.snapshot()
        return {k: v for k, v in s.items() if k.endswith("_c") or k.endswith("_target_c")}

    def history(self, n: int) -> list[dict]:
        with self._lock:
            return list(self._history)[-n:]
