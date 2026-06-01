# Audio garble / underrun — debugging status

**Status: CURRENT WORKING FIX FOUND (2026-06-01).** Two ducks can now play
the 14.6s `dialogue_*` stems and the 22.6s `moby_*` stems cleanly together
over WebSocket at 160 MHz. This doc keeps the debugging trail, but the
operational answer is now clear: use strict 20 ms Stage pacing and kick any
socket that is already backlogged before starting a cue.

> **TL;DR:** The symptom was **underrun** (audio plays slow with gaps),
> plus one distinct white-noise risk from odd-byte PCM fragment alignment.
> The working combination is:
>
> - BOYBAND firmware pinned at **160 MHz**.
> - Duck-side odd-byte PCM carry guard in `agent.c`.
> - Stage sends **640 byte / 20 ms** PCM frames with only one frame of lead.
> - Stage exposes `/health` and `/kick` so a wedged websocket can be closed
>   and the duck can reconnect before playback.
>
> **Important:** the bad socket state is real but transient. In one Mallard
> solo run, Stage showed `inFlight=250.6KB` and `lastAck=11285.9ms`; audio
> was choppy. After Stage/connection reset, both ducks played the same style
> of file cleanly. Treat a backlogged socket as poisoned: kick it and wait for
> reconnect.

## Current operator controls

Stage now supports these HTTP controls while running:

```sh
curl http://localhost:3334/health
curl http://localhost:3334/status
curl http://localhost:3334/kick/D1
curl 'http://localhost:3334/kick?duck=D2'
curl http://localhost:3334/kick      # kicks only currently unhealthy sockets
curl http://localhost:3334/play
```

`/play` runs a preflight. If any socket is already unhealthy, Stage closes
that websocket and returns `409 Conflict` instead of starting playback. The
BOYBAND firmware reconnects automatically after Stage closes the socket; wait
for `/health` to show all target ducks as `ok`, then trigger `/play` again.

Current Stage health heuristics:

| Signal | Meaning |
|---|---|
| `inFlight >= 64KB` | Stage has audio stuck behind the socket; the duck is already late. |
| `lastAck >= 1000ms` | The most recent send completion took too long; suspect the socket. |

Use `/kick/D1` or `/kick/D2` manually if a duck sounds choppy even before
the threshold catches it. Kicking during playback will interrupt that duck;
the intended use is pre-show/pre-cue recovery.

## Verified clean runs

| Run | Result |
|---|---|
| `dialogue_D2.wav` solo on Pekin | Clean; full 468480 bytes received/played. |
| `dialogue_D1.wav` + `dialogue_D2.wav` together | Clean; both ducks received/played full 468480 bytes. |
| `moby_D1.wav` + `moby_D2.wav` together | Clean; both ducks received/played full 722560 bytes. |

## ⭐ Why does this work WORSE than the internet-based Bambu duck?

The Bambu duck (WiFi → Fly.io relay → ElevenLabs, over the public
internet) plays **clean**. Ours is local and plays **worse**. Same
firmware, same `on_binary`/`spk_stream`/`spk_task` path. The only way
that's possible is a deviation in how we feed it. The deviation:

| | Bambu relay (clean) | Boy band Stage (chokes) |
|---|---|---|
| Frame size | Large — whole ElevenLabs chunks ("~320KB at once") | **640 bytes** (20ms) |
| Frames/sec | A few, big | **~50**, tiny |
| Source pacing | Bursty-large (1MB buffer absorbs it) | Steady-tiny (or prebuffer = burst of ~1100 tiny frames) |

We send ~10× the frames. The bytes/sec are identical; the **frame
count** is not. That per-frame overhead on the duck is the prime
suspect. Earlier in debugging this exact "gentler small chunks" choice
was defended — it was backwards. **Match the relay: few big frames.**

---

## The symptom (precise)

- Audio plays **"slow, with gaps"** — classic buffer **underrun**
  (the I2S DMA isn't kept fed, so playback stalls/silences between
  fragments).
- **NOT white noise.** This rules out the byte-misalignment overflow
  path (odd-byte drop in the firmware's `on_binary`). Confirmed by ear
  repeatedly.
- With 80 ms chunks and/or large lead, short clips stretched into seconds
  and exposed ~0.5s receive/playback gaps.
- With strict 20 ms chunks and one-frame lead, the checked-in 14.6s and
  22.6s two-duck stems play through cleanly.
- A socket can stay **connected** while behaving badly; the tell is Stage
  send backlog/latency, not TCP disconnect state.

## What is DEFINITIVELY ruled out (with evidence)

| Ruled out | Evidence |
|---|---|
| Stage send logic broken | Streaming to `fake-duck.py` over loopback delivers a clean, exact-real-time sine/track (measured: 4.08s audio in ~4s wall, correct frequency). Stage → a software receiver is perfect. |
| White-noise / byte misalignment / buffer **overflow** | Symptom is underrun (gaps), not white noise. No `spk stream full` logged. |
| Duck disconnecting mid-play | `netstat` shows ESTABLISHED for the entire run, every time. |
| Mac CPU / sender flooding | Measured real-time send rate to fake-duck; Mac is not flooding or choking. |
| DFS dropping CPU to 80 MHz (the bambu-garble-fix theory) | Firmware pins CPU at 160 MHz, DFS off. A 240 MHz diagnostic did not fix bad delivery, so 160 MHz is the target. |
| CPU clock too low | 160 MHz is enough for two raw 16kHz mono streams when the socket is healthy. |
| Mic task starving the speaker on the shared full-duplex I2S | BOYBAND spawns only `spk_task` plus diagnostics; clean two-duck playback confirms mic contention is not required for the symptom. |
| Stage 80 ms chunks / lead | This was a real cause. D2 received a 0.5s clip over 2317 ms with ~467 ms gaps. Strict 20 ms / 640-byte pacing fixed the measured gap pattern. |

## What's currently deployed (the firmware + Stage state right now)

**Firmware (`BAMBU_DUCK_BOYBAND` build, both ducks flashed):**
- CPU pinned at 160 MHz, DFS off (`main.c`).
- All runtime logging silenced (`main.c`).
- Zero mic: `agent_run_session` spawns only `spk_task` (prio 7) in
  BOYBAND; no `mic_task` / `ws_send_task` / `mute_timer_task` (`agent.c`).
- (I2S is still initialized full-duplex; the RX/mic side just isn't read.
  Making it TX-only is a not-yet-done further step.)

**Stage (`boyband/stage`):**
- FilePlayer sends strict **640-byte / 20 ms** PCM frames with one frame
  of lead and pads the final partial frame with silence.
- DuckConnection: per-duck send queue (isolation), send counters, and
  health detection for wedged sockets.
- Control channel: `/play`, `/stop`, `/status`, `/health`, `/kick`,
  `/kick/D1`, `/kick/D2`.

## Key diagnosis

The duck plays exactly what it receives. When playback has audible gaps,
duck `rx_max_gap_ms` and `spk_max_gap_ms` rise together, and the speaker
stream stays empty rather than filling. That points to delivery/socket
timing, not I2S playback stalling.

When Stage shows high `inFlight` or `lastAck`, that socket is already bad.
Close it and let the BOYBAND firmware reconnect before starting the cue.

## Measure both ends

Both sides are now instrumented:

1. **Mac side:** Stage's `/status` now reports per-duck send counters:
   queued frames/bytes, completed frames/bytes, in-flight bytes, dropped
   bytes, and NWConnection completion latency.
2. **Duck side:** BOYBAND firmware now sends a tiny WS text frame once
   per second:
   `{"type":"duck_stats","rx_bps":...,"spk_bps":...,"fill":...}`.
   Stage logs this through the existing inbound text handler. This avoids
   USB-console logging, which can block if nobody is draining it.
3. Run one track and **compare the timelines.**

Interpretation:

| Pattern | Meaning | Next move |
|---|---|---|
| Stage completed bytes keep climbing, duck `rx_bps` falls below ~32000, `fill` drains, `empty_waits` climbs | Delivery/WiFi is the bottleneck | Try clean network / hotspot / travel router, then consider Opus or serial |
| Duck `rx_bps` is healthy or bursty-high, but `fill` still drains and `empty_waits` climbs | Playback path is stalling | Try BOYBAND TX-only I2S, then instrument `audio_spk_write` deeper |
| Duck `fill` rises near 1 MB and `dropped` increases | We are overflowing the duck buffer | Reduce Stage prebuffer lead or pace closer to real time |
| Stage `inFlight` and `maxAck` climb while duck `rx_bps` sags | Mac→duck TCP/WiFi backpressure | Network problem, not I2S |

Use these counters during rehearsals and before show cues; they are now the
source of truth.

## Backup levers

- **Opus compression** over the wire (~24 kbps vs 256 kbps raw). The duck
  already has an Opus decoder (used for embedded phrases). 10× less data
  would make WiFi delivery much less sensitive. Bigger change: Stage encodes,
  firmware decodes on the agent path.
- **Dedicated network** (travel router) instead of congested IDEO-Guest —
  the show plan anyway; cheap to test with a phone hotspot.
- **Serial / USB-CDC transport** — bypass WiFi entirely (ducks are
  USB-tethered for power). Rock-solid bandwidth, and a clean diagnostic:
  if serial-streamed audio plays clean, the problem was WiFi; if it still
  chokes, it's the playback path. **Explicitly deferred for now per
  Devin (2026-06-01) — do NOT build serial yet.**

## Recommendation

Run show cues with the current 20 ms Stage pacing. Before triggering, check:

```sh
curl http://localhost:3334/health
curl http://localhost:3334/status
```

If a duck reports unhealthy, run `curl http://localhost:3334/kick/D1` (or
D2), wait for reconnect, then trigger `/play`.

## Four-duck watchouts

Four ducks at raw 16kHz mono int16 is about **128 KB/s** of audio payload
before WebSocket/TCP/WiFi overhead. That is still small for normal WiFi, but
it gives less margin on congested guest networks and makes per-duck socket
health checks more important.

Watch these before any four-duck cue:

- `/health` must show every target duck as `ok`.
- `/status` should show `inFlight=0/0B` before the trigger.
- If any duck reports unhealthy or has stale in-flight bytes, kick only that
  duck and wait for it to reconnect.
- Keep all ducks on the same 160 MHz BOYBAND firmware image.
- Use a dedicated router/hotspot for show conditions if possible. IDEO-Guest
  worked for the two-duck Moby run, but four simultaneous sockets double the
  current load.
- Avoid restarting Stage between cues unless you mean to reset every socket.
  Use `/kick/Dx` for one bad duck.

During playback, a single duck can still have a transient bad socket. If that
happens, do not expect buffering to recover the current line cleanly; stop or
finish the cue, kick that duck, wait for reconnect, then rerun.

---
*Last updated 2026-06-01. Ducks: Mallard (D1), Pekin (D2).*
