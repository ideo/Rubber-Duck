"""Subscribe to a Bambu user's MQTT broker and accumulate per-printer state.

Bambu's `push_status` is delta-push: a full snapshot lands on subscribe, then
only changed fields. We merge per-printer (#41) so a duck bound to multiple
printers in the same Bambu account keeps independent state per device.

Also fires registered listener callbacks when notable events happen (FINISH /
FAILED transitions, new HMS errors). Each event carries `printer_name` so
the notification proxy can identify which printer fired it.
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

from hms_codes import lookup_phrase as _hms_lookup_phrase

logger = logging.getLogger("bambu_state")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:bambu_state: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False


def _age_human(age_sec: int) -> str:
    """Human-readable age string suitable for the agent to read aloud.
    Coarse-grained on purpose — the agent should say "yesterday" or
    "3 days ago" not "1 day, 4 hours, 17 minutes ago." The buckets
    align with how a human would naturally narrate elapsed time when
    glancing at a print job log."""
    if age_sec < 60:
        return "just now"
    if age_sec < 60 * 60:
        m = age_sec // 60
        return "1 minute ago" if m == 1 else f"{m} minutes ago"
    if age_sec < 60 * 60 * 24:
        h = age_sec // 3600
        return "1 hour ago" if h == 1 else f"{h} hours ago"
    if age_sec < 60 * 60 * 48:
        return "yesterday"
    days = age_sec // (60 * 60 * 24)
    if days < 7:
        return f"{days} days ago"
    if days < 14:
        return "a week ago"
    if days < 30:
        weeks = days // 7
        return f"{weeks} weeks ago"
    if days < 60:
        return "a month ago"
    months = days // 30
    return f"{months} months ago"


def _hms_severity(attr: int) -> int:
    """Decode the severity nibble from a Bambu HMS uint32 `attr`. Format
    (per community reverse-engineering of Bambu's MQTT protocol):
        bits 31-16  module + severity (severity = lower nibble of upper16)
        bits 15-0   error code within that module
    Severity values:
        0 — NONE / INFO  (status notice, e.g. "AMS opened" or stale info)
        1 — FATAL
        2 — SERIOUS
        3 — COMMON       (warning)
    Filtering level-0 out keeps the agent from reporting "the printer is
    flagging errors" when it's actually just background noise that the
    printer screen never shows the user. Real user-visible issues are
    level 1 and up."""
    return (attr >> 16) & 0xF


class _PrinterState:
    """One printer's slice of state — push_status accumulator + history +
    HMS tracking. Held inside BambuState's per-serial dict.

    Why a separate class instead of a dict-of-dicts: clearer ownership of
    `_last_stage` / `_last_hms` (the transition trackers that drive the
    fire-once-on-edge listener semantics), and a natural place to attach
    the printer_name without scattering it through the parent."""

    def __init__(self, serial: str, printer_name: str = ""):
        self.serial = serial
        self.printer_name = printer_name
        self.state: dict[str, Any] = {}
        self.history: deque[dict] = deque(maxlen=20)
        self.last_stage: str | None = None
        self.last_hms: set | None = None
        self.last_message_ts: float = 0.0
        # Wall-clock start time of the *current* print (None when idle).
        # Captured on transition into RUNNING — preferentially from
        # Bambu's gcode_start_time field (UNIX seconds as string),
        # falling back to time.time() if the field's missing. Used to
        # compute history duration on FINISH/FAILED. Was previously
        # `mc_print_sub_stage` which is a sub-stage enum, not a
        # duration — yielded nonsense in history entries.
        self.print_start_ts: float | None = None
        # Bambu's per-print task identifier. Tracked so the FINISH-
        # before-subscribe race (issue #24) is detectable: if the very
        # first snapshot after relay reconnect shows FINISH/FAILED, we
        # can record a history entry instead of silently missing it.
        self.last_subtask_id: str | None = None


class BambuState:
    """Subscribes to a Bambu MQTT broker and accumulates per-printer state
    deltas. One BambuState per duck; one MQTT connection (auth'd as the
    user) holding subscriptions for ALL the printers that duck cares about.

    Two broker modes (same code path, different auth):
      LAN mode    — host=<printer-ip>, username="bblp", password=<access_code>
                    self-signed cert. Bambu's per-printer cert isn't in
                    any public CA chain and rotates with firmware, so
                    LAN callers must opt out of TLS verification by
                    explicitly passing verify_tls=False. Threat model:
                    LAN-only attacker on the same broadcast domain,
                    accepted as the cost of a hobby device. Single-
                    printer only.
      Cloud mode  — host="us.mqtt.bambulab.com", username=f"u_{user_id}",
                    password=<access_token from bambu_cloud.login>.
                    Publicly-trusted CA-signed cert, full TLS
                    verification (default). Multi-printer via N
                    subscriptions on the same connection.

    Switching modes / printer set happens via reconfigure() — same instance,
    listeners survive, the registry in main.py doesn't need to know.

    Default for `verify_tls` is True so callers fail-secure: anyone
    adding a new BambuState() construction won't accidentally inherit
    verify-off. The two LAN-mode call sites (dev fallback in main.py +
    any future LAN-only deployments) set it explicitly to False with
    a one-line comment justifying the LAN-only threat model.
    """

    def __init__(self, host: str, username: str, password: str,
                 serials: list[str] | None = None,
                 printer_names: list[str] | None = None,
                 verify_tls: bool = True,
                 # Legacy single-printer convenience for callers that
                 # haven't migrated to lists yet (LAN dev paths). Either
                 # this OR `serials` should be set.
                 serial: str = "",
                 printer_name: str = ""):
        self.host = host
        self.username = username
        self.password = password
        # Normalize to list form. List wins if both are provided.
        if serials:
            self.serials = list(serials)
            self.printer_names = list(printer_names) if printer_names else \
                [""] * len(serials)
        elif serial:
            self.serials = [serial]
            self.printer_names = [printer_name or ""]
        else:
            self.serials = []
            self.printer_names = []
        self.verify_tls = verify_tls
        self._lock = threading.Lock()
        # Per-printer state, keyed by serial. Built up on construction;
        # reconfigure() rebuilds it.
        self._printers: dict[str, _PrinterState] = {
            s: _PrinterState(s, n)
            for s, n in zip(self.serials, self.printer_names)
        }
        self._listeners: List[Callable[[dict], None]] = []
        # auth_failed surfaces "Bambu rejected our credentials" (CONNACK
        # rc=5/4) so /admin/bambu_status and the duck.local recovery page
        # can prompt for re-login. Without this, an expired token just
        # makes paho retry forever in silence.
        self.auth_failed: bool = False
        self._client = self._build_client()

    # ---- Back-compat shims for code paths that still expect singular
    # `serial` / `printer_name` attributes (mostly /admin/bambu_status
    # endpoints that haven't been multi-printer-aware'd yet). Always
    # returns the FIRST serial / name; callers that care about the
    # full list go through .serials / .printer_names.
    @property
    def serial(self) -> str:
        return self.serials[0] if self.serials else ""

    @property
    def printer_name(self) -> str:
        return self.printer_names[0] if self.printer_names else ""

    def add_listener(self, cb: Callable[[dict], None]) -> None:
        """Register a callback fired on notable events. Called with a dict like
        {"type": "finish", "subtask": "...", "printer_name": "..."}.
        Callback runs on the MQTT thread — keep it fast / non-blocking."""
        self._listeners.append(cb)

    def _fire(self, event: dict) -> None:
        # printer_name should already be stamped by the caller
        # (handle_payload routes via serial → _PrinterState which knows
        # its name). Keep the fallback for synthetic /admin events.
        if "printer_name" not in event:
            event["printer_name"] = self.printer_name
        for cb in list(self._listeners):
            try:
                cb(event)
            except Exception as e:  # noqa: BLE001 — listener fanout
                # Listener fanout runs on the MQTT thread. Re-raising
                # would crash the thread and we'd stop receiving printer
                # events for this duck — bad. So we keep this broad.
                # BUT log the exception type explicitly so a buggy
                # listener (TypeError from a refactor, KeyError from a
                # missing field) shows up as something other than
                # silence. Was previously a bare `except Exception: pass`
                # which masked real bugs entirely (#39).
                logger.warning("listener raised %s: %s",
                                type(e).__name__, e)

    def _build_client(self) -> mqtt.Client:
        c = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                         client_id=f"duck-relay-{int(time.time())}")
        c.username_pw_set(self.username, self.password)
        ctx = ssl.create_default_context()
        if not self.verify_tls:
            # LAN-mode opt-out: printer ships a self-signed cert that's
            # rotated with firmware, so there's no public CA path to
            # validate against. Verification is disabled here only when
            # the caller explicitly chose LAN mode (host is a private IP
            # and the threat model is "anyone on this LAN can see MQTT
            # already"). WARN-loud at construction so the choice is
            # visible in logs / audits — silent verify-off would be the
            # really bad version of this.
            logger.warning(
                "MQTT TLS verification DISABLED for host=%s — LAN mode "
                "(self-signed cert, threat model: LAN-only attacker)",
                self.host)
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
        c.tls_set_context(ctx)
        c.on_connect = self._on_connect
        c.on_disconnect = self._on_disconnect
        c.on_message = self._on_message
        c.reconnect_delay_set(min_delay=1, max_delay=60)
        return c

    def start(self) -> None:
        # connect_async + loop_start = non-blocking initial connect. Even
        # if the broker is unreachable when the relay boots, the relay
        # still starts and serves /ws/duck etc — the MQTT loop keeps
        # trying in the background.
        logger.info("connecting to MQTT %s:8883 as %s for %d printer(s) "
                    "(async, will retry on failure)",
                    self.host, self.username, len(self.serials))
        self._client.connect_async(self.host, 8883, keepalive=60)
        self._client.loop_start()

    def stop(self) -> None:
        self._client.loop_stop()
        self._client.disconnect()

    def reconfigure(self, host: str, username: str, password: str,
                    serials: list[str], printer_names: list[str],
                    verify_tls: bool = True) -> None:
        """Swap broker / credentials / printer set at runtime. Used by
        /admin/bambu_login when the user signs in to Bambu cloud, and by
        the multi-printer picker (Phase B of #41) when the user changes
        their selection. Stops the old MQTT client first to avoid two
        clients ever being live simultaneously."""
        logger.info("reconfiguring MQTT: %s@%s, %d printer(s), verify_tls=%s",
                    username, host, len(serials), verify_tls)
        self.stop()
        self.host = host
        self.username = username
        self.password = password
        self.serials = list(serials)
        self.printer_names = list(printer_names)
        self.verify_tls = verify_tls
        # Wipe per-printer state — previous broker's transitions would
        # otherwise leak into the new session and suppress legit events.
        with self._lock:
            self._printers = {
                s: _PrinterState(s, n)
                for s, n in zip(self.serials, self.printer_names)
            }
        self._client = self._build_client()
        self.start()

    def _on_disconnect(self, _client, _ud, _flags, rc, _props=None):
        logger.warning("MQTT disconnected (rc=%s) — paho will auto-reconnect", rc)

    def _on_connect(self, client, _ud, _flags, rc, _props=None):
        if rc == 0:
            self.auth_failed = False
            if not self.serials:
                logger.warning("MQTT connected but no serials to subscribe to")
                return
            for serial in self.serials:
                topic = f"device/{serial}/report"
                logger.info("MQTT subscribing to %s", topic)
                client.subscribe(topic)
                # nudge each printer to send a full snapshot
                client.publish(
                    f"device/{serial}/request",
                    json.dumps({"pushing": {"sequence_id": "0",
                                             "command": "pushall"}}),
                )
        else:
            # rc 4/5 (MQTT 3.1) and 134/135 (MQTT 5) all mean Bambu rejected
            # our credentials. Surface via auth_failed so /admin/bambu_status
            # reports it and the captive portal can prompt for re-login.
            if rc in (4, 5, 134, 135):
                self.auth_failed = True
                logger.warning("MQTT auth rejected (rc=%s) — token likely "
                               "expired; auth_failed=True", rc)
            else:
                logger.warning("MQTT connect callback rc=%s (non-zero = failure)",
                               rc)

    def _on_message(self, _client, _ud, msg):
        # Topic shape: device/<serial>/report. Extract the serial so we
        # know which _PrinterState to update.
        parts = msg.topic.split("/")
        if len(parts) < 3 or parts[0] != "device":
            return
        serial = parts[1]
        printer = self._printers.get(serial)
        if printer is None:
            # Subscribed to a serial we don't track — shouldn't happen
            # since we only subscribe to ones in self.serials, but log
            # if it does.
            logger.warning("MQTT message for untracked serial %s", serial)
            return
        printer.last_message_ts = time.time()
        try:
            payload = json.loads(msg.payload)
        except json.JSONDecodeError:
            return
        self._handle_payload(printer, payload)

    # Public method used by mock_printer.py — preserves the old single-
    # printer entry point for tests / dev. Routes to the only printer
    # we know about (or the first if multiple).
    def handle_payload(self, payload: dict) -> None:
        if not self._printers:
            return
        printer = next(iter(self._printers.values()))
        self._handle_payload(printer, payload)

    def _handle_payload(self, printer: _PrinterState, payload: dict) -> None:
        push = payload.get("print")
        if not push:
            return
        with self._lock:
            printer.state.update(push)
            stage = push.get("gcode_state")
            subtask = printer.state.get("subtask_name")
            subtask_id = printer.state.get("subtask_id")

            # Capture print-start timestamp on transition INTO RUNNING.
            # Bambu publishes gcode_start_time as a string of UNIX
            # seconds; parse it if present, else use the local clock as
            # a usable approximation. Reset to None on IDLE so a stale
            # value doesn't leak into the next print's duration.
            if stage == "RUNNING" and printer.last_stage in (
                    "IDLE", "PREPARE", "FINISH", "FAILED", None):
                start_str = push.get("gcode_start_time")
                try:
                    printer.print_start_ts = (
                        float(start_str) if start_str else time.time())
                except (TypeError, ValueError):
                    printer.print_start_ts = time.time()
            elif stage == "IDLE":
                printer.print_start_ts = None

            if stage and stage != printer.last_stage:
                if stage in ("FINISH", "FAILED"):
                    duration_sec = None
                    if printer.print_start_ts is not None:
                        duration_sec = int(time.time() - printer.print_start_ts)
                    # ts: when did this print actually finish? Two cases:
                    #   - We saw the RUNNING→FINISH transition live →
                    #     time.time() is the right answer (within ~ms).
                    #   - We're race-recovering on the first snapshot
                    #     and the print finished BEFORE the relay
                    #     restarted. time.time() would lie ("just now"
                    #     for a print that finished days ago). Fall
                    #     back to gcode_start_time which is in the same
                    #     ballpark — not the end time, but at least the
                    #     right day/week. Detected via last_stage being
                    #     None at this point in the dispatch.
                    finish_ts = time.time()
                    if printer.last_stage is None:
                        start_str = push.get("gcode_start_time")
                        try:
                            if start_str:
                                finish_ts = float(start_str)
                        except (TypeError, ValueError):
                            pass
                    printer.history.append({
                        "ts": finish_ts,
                        "outcome": stage,
                        "subtask": subtask,
                        "subtask_id": subtask_id,
                        # duration_sec is None when we missed the RUNNING
                        # transition (relay reconnect mid-print, or
                        # FINISH-on-first-snapshot race below). Better
                        # than the bogus mc_print_sub_stage value the
                        # old code recorded as "duration_min".
                        "duration_sec": duration_sec,
                    })
                    # print_start_ts gets cleared on the next IDLE — keep
                    # it here so a duplicate FINISH-before-IDLE doesn't
                    # synthesize a second nonsense entry.
                if printer.last_stage is not None:
                    if stage in ("PREPARE", "RUNNING") and \
                       printer.last_stage in ("IDLE", "FINISH", "FAILED", None):
                        self._fire({"type": "start", "subtask": subtask,
                                    "printer_name": printer.printer_name})
                    elif stage == "FINISH":
                        self._fire({"type": "finish", "subtask": subtask,
                                    "printer_name": printer.printer_name})
                    elif stage == "FAILED":
                        self._fire({"type": "failed", "subtask": subtask,
                                    "printer_name": printer.printer_name})
                    elif stage == "PAUSE":
                        self._fire({"type": "pause", "subtask": subtask,
                                    "printer_name": printer.printer_name})
                    elif stage == "RUNNING" and printer.last_stage == "PAUSE":
                        self._fire({"type": "resume", "subtask": subtask,
                                    "printer_name": printer.printer_name})
                else:
                    # FINISH-before-subscribe race (issue #24): the
                    # first snapshot after the relay (re)connects shows
                    # the printer already at FINISH/FAILED. Old code
                    # gated all listener fires + the history append
                    # behind `last_stage is not None` — meaning a
                    # print that completed in the gap between MQTT
                    # disconnect and reconnect was lost entirely.
                    # The history append above already runs (no
                    # last_stage gate on it), so the print at least
                    # appears in the print_history tool response; we
                    # deliberately DON'T fire a finish/failed event
                    # because the user already saw the result on the
                    # printer panel and a delayed "your print just
                    # finished" announcement would be more confusing
                    # than helpful.
                    if stage in ("FINISH", "FAILED"):
                        logger.info(
                            "first-snapshot %s (race-recovered): "
                            "subtask=%r subtask_id=%r — recorded in "
                            "history, no listener fired",
                            stage, subtask, subtask_id)
                printer.last_stage = stage

            if subtask_id and subtask_id != printer.last_subtask_id:
                printer.last_subtask_id = subtask_id

            if "hms" in push:
                # Build a {attr → (attr, code)} map so we can look up
                # the full 16-char form for any newly-arrived attr. The
                # `_last_hms` set still tracks just attr-IDs (since
                # that's what determines "is this fault new or stale").
                hms_pairs = {h.get("attr"): (h.get("attr"), h.get("code"))
                             for h in (push.get("hms") or [])
                             if h.get("attr")
                             and _hms_severity(h.get("attr", 0)) >= 1}
                new_hms = set(hms_pairs.keys())
                if printer.last_hms is None:
                    printer.last_hms = new_hms
                else:
                    added = new_hms - printer.last_hms
                    if added:
                        added_list = list(added)
                        phrases = [_hms_lookup_phrase(*hms_pairs[a])
                                   for a in added_list]
                        self._fire({"type": "hms",
                                    "codes": added_list,
                                    "phrases": phrases,
                                    "subtask": subtask,
                                    "printer_name": printer.printer_name})
                    printer.last_hms = new_hms

    def last_message_age_ms(self) -> int | None:
        """Most-recent activity across all this duck's printers, in ms.
        None if we've never seen a message from any of them."""
        if not self._printers:
            return None
        latest = max((p.last_message_ts for p in self._printers.values()),
                     default=0.0)
        if latest == 0.0:
            return None
        return int((time.time() - latest) * 1000)

    # ---- read-side helpers (called from web thread) ----

    def _printer_snapshot(self, printer: _PrinterState) -> dict:
        s = printer.state
        active_hms = [h for h in (s.get("hms") or [])
                      if h.get("attr")
                      and _hms_severity(h.get("attr", 0)) >= 1]
        stage = s.get("gcode_state")
        # Only RUNNING / PREPARE / PAUSE represent actively-running
        # work. IDLE / FINISH / FAILED still have stale subtask /
        # percent fields lingering from the last job — Bambu doesn't
        # clear them on completion. The old snapshot exposed those
        # stale fields in the same shape as live ones, and the agent
        # would describe a 2-hour-old finished print as if it were
        # current. Now we segregate: live fields only when the stage
        # is actually live, otherwise null. The "last_*" block carries
        # the most recent completed print's name + outcome + age so
        # the agent can mention it as past-tense if the user asks.
        is_live = stage in ("RUNNING", "PREPARE", "PAUSE")
        snap: dict = {
            "stage": stage,
            "subtask":         s.get("subtask_name") if is_live else None,
            "percent":         s.get("mc_percent") if is_live else None,
            "layer":           s.get("layer_num") if is_live else None,
            "total_layers":    s.get("total_layer_num") if is_live else None,
            "remaining_min":   s.get("mc_remaining_time") if is_live else None,
            "nozzle_target_c": s.get("nozzle_target_temper"),
            "nozzle_c":        s.get("nozzle_temper"),
            "bed_target_c":    s.get("bed_target_temper"),
            "bed_c":           s.get("bed_temper"),
            "chamber_c":       s.get("chamber_temper"),
            "hms_codes":   [h["attr"] for h in active_hms],
            # Friendly TTS phrases parallel to hms_codes — same length,
            # same order. Entries are None when we don't have a phrase
            # for that code (caller falls back to a generic message).
            # See hms_codes.py for the lookup table source.
            "hms_phrases": [_hms_lookup_phrase(h.get("attr"), h.get("code"))
                            for h in active_hms],
        }
        # Most recent completed print (FINISH or FAILED), if we have
        # one in history. Pulled out separately so the agent can say
        # "C3-P0 finished a print 2 hours ago" without confusing it
        # with current activity. Empty/None when no history yet.
        last_done = None
        for h in reversed(printer.history):
            if h.get("outcome") in ("FINISH", "FAILED"):
                last_done = h
                break
        if last_done is not None:
            now = time.time()
            age_sec = max(0, int(now - last_done.get("ts", now)))
            snap["last_print_subtask"]   = last_done.get("subtask")
            snap["last_print_outcome"]   = last_done.get("outcome")
            snap["last_print_age_human"] = _age_human(age_sec)
        else:
            snap["last_print_subtask"]   = None
            snap["last_print_outcome"]   = None
            snap["last_print_age_human"] = None
        return snap

    def snapshot(self) -> dict:
        """Multi-printer snapshot. Returns
            {<printer_name or serial>: {<state fields>}}
        keyed by printer name (or serial when name is empty). Single-
        printer ducks get a 1-key dict — agent template's job to read
        whichever shape it gets.
        """
        with self._lock:
            return {
                (p.printer_name or p.serial): self._printer_snapshot(p)
                for p in self._printers.values()
            }

    def temperatures(self) -> dict:
        out = {}
        for label, snap in self.snapshot().items():
            out[label] = {k: v for k, v in snap.items()
                          if k.endswith("_c") or k.endswith("_target_c")}
        return out

    def history(self, n: int) -> list[dict]:
        """Most-recent N events across ALL printers, merged + sorted by ts.
        Each entry includes printer_name so the agent can attribute,
        plus age_min (int minutes since the event) and age_human
        ("just now" / "3 hours ago" / "yesterday" / "3 days ago") so
        the agent can contextualize without doing arithmetic on raw
        unix timestamps. The agent's system prompt instructs it to
        prefer age_human in spoken responses."""
        now = time.time()
        with self._lock:
            merged: list[dict] = []
            for p in self._printers.values():
                for h in p.history:
                    age_sec = max(0, int(now - h.get("ts", now)))
                    merged.append({
                        **h,
                        "printer_name": p.printer_name,
                        "age_min": age_sec // 60,
                        "age_human": _age_human(age_sec),
                    })
            merged.sort(key=lambda h: h.get("ts", 0))
            return merged[-n:]

    # Raw-state dump for /admin/raw_state — exposes the underlying push
    # dicts per-printer for diagnostic purposes.
    @property
    def _state(self) -> dict:
        with self._lock:
            return {
                (p.printer_name or p.serial): dict(p.state)
                for p in self._printers.values()
            }
