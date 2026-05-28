#!/usr/bin/env python3
"""
fake-duck.py — Pretend to be a Bambu Duck for testing the Stage server.

Connects to ws://<host>:<port>/duck/<id>, reads inbound frames, writes
binary PCM to a WAV file, logs text frames to stdout. Lets us verify
Stage end-to-end without flashing or wiring a real duck.

Mirrors the firmware's side of the contract documented in
boyband/docs/stage-protocol.md:
  - Binary frames Stage→duck: raw int16 LE PCM mono @ 16 kHz
  - Text frames   Stage→duck: JSON ({"type": "..."} etc.)
  - We optionally send a {"type":"ready"} text on connect, mimicking
    what the real firmware does once it's set up speaker DMA.

Usage examples:

    # Default: connect to D1 on localhost:3334, record 10s, write captured.wav
    python3 fake-duck.py

    # Different duck slot + custom output
    python3 fake-duck.py --duck D3 --out d3-test.wav

    # Record until Ctrl-C
    python3 fake-duck.py --duration 0

    # Test the Stage running on another Mac (e.g. the show laptop)
    python3 fake-duck.py --server ws://stage.local:3334

    # Verify all four slots (one process each, in 4 terminals)
    for d in D1 D2 D3 D4; do
        python3 fake-duck.py --duck $d --out cap-$d.wav --duration 5 &
    done; wait

Dependencies:
  - websockets (already present in bambu/relay's venv; pip install websockets)
"""

import argparse
import asyncio
import json
import signal
import sys
import wave
from datetime import datetime, timezone

try:
    import websockets
except ImportError:
    print("error: 'websockets' package not installed.\n"
          "  pip install websockets   (or use bambu/relay's venv)",
          file=sys.stderr)
    sys.exit(1)


SAMPLE_RATE = 16000  # Hz, must match Stage / firmware
SAMPLE_WIDTH = 2     # int16 LE → 2 bytes
CHANNELS = 1


def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
    print(f"[{ts}] {msg}", flush=True)


async def run(args: argparse.Namespace) -> int:
    url = f"{args.server.rstrip('/')}/duck/{args.duck}"
    log(f"connecting to {url}")

    try:
        async with websockets.connect(url, max_size=2**24) as ws:
            log(f"connected as {args.duck}; writing PCM → {args.out}")

            if args.send_ready:
                await ws.send(json.dumps({"type": "ready"}))
                log("sent {type:'ready'} (mimicking firmware boot)")

            wav = wave.open(args.out, "wb")
            wav.setnchannels(CHANNELS)
            wav.setsampwidth(SAMPLE_WIDTH)
            wav.setframerate(SAMPLE_RATE)

            stop_at = None
            if args.duration > 0:
                loop = asyncio.get_running_loop()
                stop_at = loop.time() + args.duration

            bytes_written = 0
            text_frames = 0
            binary_frames = 0

            try:
                while True:
                    timeout = None
                    if stop_at is not None:
                        timeout = max(0.0, stop_at - asyncio.get_running_loop().time())
                        if timeout == 0.0:
                            break
                    try:
                        msg = await asyncio.wait_for(ws.recv(), timeout=timeout)
                    except asyncio.TimeoutError:
                        break

                    if isinstance(msg, (bytes, bytearray)):
                        wav.writeframes(msg)
                        bytes_written += len(msg)
                        binary_frames += 1
                        # Quiet by default — flood would drown out useful logs.
                        # Print a heartbeat every ~1s of audio (50 chunks @ 20ms).
                        if binary_frames % 50 == 0:
                            secs = bytes_written / (SAMPLE_RATE * SAMPLE_WIDTH * CHANNELS)
                            log(f"… {binary_frames} pcm frames, {secs:.1f}s captured")
                    else:
                        text_frames += 1
                        log(f"text: {msg}")
            finally:
                wav.close()
                secs = bytes_written / (SAMPLE_RATE * SAMPLE_WIDTH * CHANNELS)
                log(f"done. text={text_frames}  binary={binary_frames}  "
                    f"audio={secs:.2f}s  file={args.out}")
    except (websockets.exceptions.ConnectionClosedOK,
            websockets.exceptions.ConnectionClosedError) as e:
        log(f"connection closed: {e}")
        return 0
    except OSError as e:
        log(f"connect failed: {e}")
        return 1

    return 0


def main() -> int:
    p = argparse.ArgumentParser(
        description="Pretend to be a Bambu Duck against the Stage server.")
    p.add_argument("--server", default="ws://localhost:3334",
                   help="Stage server base URL (default: ws://localhost:3334)")
    p.add_argument("--duck", default="D1", choices=["D1", "D2", "D3", "D4"],
                   help="Which duck slot to claim (default: D1)")
    p.add_argument("--out", default="captured.wav",
                   help="Output WAV file for inbound PCM (default: captured.wav)")
    p.add_argument("--duration", type=float, default=10.0,
                   help="Seconds to record before exiting; 0 = until Ctrl-C "
                        "(default: 10)")
    p.add_argument("--send-ready", action="store_true",
                   help="Send {type:'ready'} on connect (mimic firmware boot)")
    args = p.parse_args()

    # Clean Ctrl-C — let asyncio cancel via KeyboardInterrupt.
    signal.signal(signal.SIGINT, signal.default_int_handler)

    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        log("interrupted")
        return 0


if __name__ == "__main__":
    sys.exit(main())
