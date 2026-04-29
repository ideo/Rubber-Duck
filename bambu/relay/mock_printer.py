"""Drive a BambuState with realistic push_status payloads — no MQTT broker needed.

Walks through a print: IDLE → PREPARE → RUNNING (heating, then progressing
through layers) → FINISH → IDLE again. Lets you exercise the relay endpoints
end-to-end without a real printer. Enable with MOCK=1.
"""
from __future__ import annotations

import threading
import time
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from bambu_state import BambuState


def _push(state: "BambuState", **fields) -> None:
    state.handle_payload({"print": fields})


def _run(state: "BambuState") -> None:
    """One full print cycle, ~30s of fake activity, then loop."""
    while True:
        # Idle
        _push(state, gcode_state="IDLE", mc_percent=0, layer_num=0)
        time.sleep(2)

        # Prepare / heating
        _push(
            state,
            gcode_state="PREPARE",
            subtask_name="benchy_v3.gcode.3mf",
            total_layer_num=120,
            nozzle_target_temper=220,
            bed_target_temper=60,
            chamber_temper=28,
        )
        for nozzle, bed in [(80, 30), (140, 50), (200, 60), (220, 60)]:
            _push(state, nozzle_temper=nozzle, bed_temper=bed)
            time.sleep(1)

        # Running
        _push(state, gcode_state="RUNNING", mc_remaining_time=22)
        for layer in range(1, 121, 10):
            percent = int(layer / 120 * 100)
            _push(
                state,
                layer_num=layer,
                mc_percent=percent,
                mc_remaining_time=max(1, 22 - layer // 6),
            )
            time.sleep(1)

        # Finish — triggers history append
        _push(state, gcode_state="FINISH", mc_percent=100, layer_num=120)
        time.sleep(3)


def drive_in_thread(state: "BambuState") -> threading.Thread:
    t = threading.Thread(target=_run, args=(state,), daemon=True, name="mock-printer")
    t.start()
    return t


if __name__ == "__main__":
    # Standalone smoke test: print state snapshots as the mock walks the cycle.
    from bambu_state import BambuState

    s = BambuState("mock", "mock", "mock")
    drive_in_thread(s)
    for _ in range(20):
        time.sleep(1.5)
        snap = s.snapshot()
        print(f"stage={snap['stage']:<8} pct={snap['percent']} layer={snap['layer']} "
              f"nozzle={snap['nozzle_c']}/{snap['nozzle_target_c']}")
