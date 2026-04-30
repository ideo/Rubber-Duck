"""Subscribe to a Bambu printer's local MQTT broker and keep a live state snapshot.

Bambu's `push_status` is delta-push: a full snapshot lands on subscribe, then
only changed fields. We merge into a single dict that tools can read.

Also fires registered listener callbacks when notable events happen (FINISH /
FAILED transitions, new HMS errors). The notification proxy uses these to
push events to connected ducks.
"""
from __future__ import annotations

import json
import ssl
import threading
import time
from collections import deque
from typing import Any, Callable, List

import paho.mqtt.client as mqtt


class BambuState:
    def __init__(self, host: str, access_code: str, serial: str):
        self.host = host
        self.access_code = access_code
        self.serial = serial
        self._lock = threading.Lock()
        self._state: dict[str, Any] = {}
        self._history: deque[dict] = deque(maxlen=20)
        self._last_stage: str | None = None
        self._listeners: List[Callable[[dict], None]] = []
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
        c.username_pw_set("bblp", self.access_code)
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE  # printer ships self-signed cert
        c.tls_set_context(ctx)
        c.on_connect = self._on_connect
        c.on_message = self._on_message
        return c

    def start(self) -> None:
        self._client.connect(self.host, 8883, keepalive=60)
        self._client.loop_start()

    def stop(self) -> None:
        self._client.loop_stop()
        self._client.disconnect()

    def _on_connect(self, client, _ud, _flags, rc, _props=None):
        if rc == 0:
            client.subscribe(f"device/{self.serial}/report")
            # nudge printer to send a full snapshot
            client.publish(
                f"device/{self.serial}/request",
                json.dumps({"pushing": {"sequence_id": "0", "command": "pushall"}}),
            )

    def _on_message(self, _client, _ud, msg):
        try:
            payload = json.loads(msg.payload)
        except json.JSONDecodeError:
            return
        self.handle_payload(payload)

    def handle_payload(self, payload: dict) -> None:
        """Merge a push_status payload into state. Public so tests/mocks can inject."""
        push = payload.get("print")
        if not push:
            return
        with self._lock:
            self._state.update(push)
            stage = push.get("gcode_state")
            if stage and stage != self._last_stage:
                # Record terminal-state arrival as history. Note: this triggers
                # on the FIRST snapshot too if the printer is already FINISHed
                # when we subscribe — fixes #24's startup race where prints
                # completed before the relay was running were invisible.
                if stage in ("FINISH", "FAILED"):
                    self._history.append({
                        "ts": time.time(),
                        "outcome": stage,
                        "subtask": self._state.get("subtask_name"),
                        "duration_min": self._state.get("mc_print_sub_stage"),
                    })
                    # Only fire notification on a real transition (not the
                    # startup-seed case where _last_stage was None).
                    if self._last_stage is not None:
                        self._fire({
                            "type": stage.lower(),  # "finish" or "failed"
                            "subtask": self._state.get("subtask_name"),
                        })
                self._last_stage = stage

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
