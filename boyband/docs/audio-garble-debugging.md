# Audio garble / underrun — debugging status

**Status: UNRESOLVED. Pinned to revisit.** Two ducks (and now even one
duck) playing a streamed PCM track over WiFi degrade into choppy,
"slow-with-gaps" audio. This doc is the honest record of what we tried,
what's ruled out, and what to do next — written so anyone (Devin, Jenna,
their Claude) can pick it up cold without re-walking the whole maze.

> **TL;DR:** The symptom is **underrun** (audio plays slow with gaps),
> NOT white-noise corruption. We threw a lot of fixes at it (CPU pin,
> zero-mic, prebuffer, per-duck queues, drop-frames) and **it still
> chokes — even on a single duck.**
>
> **LEADING HYPOTHESIS (not yet tested): WS FRAME SIZE.** The Bambu relay
> streams the *same* duck firmware cleanly over the internet from
> ElevenLabs — so we must have deviated from how it feeds the duck. We
> did: the relay sends **few, large** binary frames (ElevenLabs chunks;
> firmware comment notes "~320KB arrives at once"), while Stage sends
> **~50 tiny 640-byte frames/sec**. Each WS frame costs the duck a fixed
> per-frame overhead (WS event callback → `on_binary` → stream push →
> servo update); 50 tiny frames/sec is ~10× the relay's frame load and
> likely swamps the duck's WS event loop → choppy delivery into
> `spk_stream` → underrun. **Fix to try first: make Stage send large
> frames (16–32 KB), like the relay. Stage-only, no reflash.**

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
- A **short** track (~14.6s) was mostly OK ("a few good runs, minor
  dropped frames"). A **longer** track (~22.6s) reliably chokes.
- Initially looked like it only happened with **two** ducks; **then a
  single duck choked too.** So it is NOT purely two-duck contention.
- The WS connection stays **up** throughout (verified via
  `netstat -an | grep .3334` showing ESTABLISHED the whole run — no
  disconnects). No `spk stream full` overflow logged on the duck.

## What is DEFINITIVELY ruled out (with evidence)

| Ruled out | Evidence |
|---|---|
| Stage send logic broken | Streaming to `fake-duck.py` over loopback delivers a clean, exact-real-time sine/track (measured: 4.08s audio in ~4s wall, correct frequency). Stage → a software receiver is perfect. |
| White-noise / byte misalignment / buffer **overflow** | Symptom is underrun (gaps), not white noise. No `spk stream full` logged. |
| Duck disconnecting mid-play | `netstat` shows ESTABLISHED for the entire run, every time. |
| Mac CPU / sender flooding | Measured real-time send rate to fake-duck; Mac is not flooding or choking. |
| DFS dropping CPU to 80 MHz (the bambu-garble-fix theory) | Firmware now **pins CPU at 160 MHz, DFS off** (BOYBAND build) — still chokes. |
| CPU clock too low (would 240 help?) | No. 160 MHz is ample for one 16kHz mono stream (~32KB/s is trivial). Choke persists at a steady 160 ⇒ not clock-bound. 240 also **browns out** (documented in sdkconfig.defaults) so it's off the table regardless. |
| Console logging blocking on a full USB-CDC TX buffer | Firmware now **silences all logging** (`esp_log_level_set("*", ESP_LOG_NONE)`) in BOYBAND — still chokes. (Was a real hazard worth removing, just not THE cause.) |
| Mic task starving the speaker on the shared full-duplex I2S | Firmware now spawns **zero mic/ws-send/mute tasks** in BOYBAND and bumps `spk_task` to priority 7 — still chokes. (Also a real improvement — mic_task at prio 7 *was* above spk_task at 6 — just not THE cause on its own.) |

## What's currently deployed (the firmware + Stage state right now)

**Firmware (`BAMBU_DUCK_BOYBAND` build, both ducks flashed):**
- CPU pinned at 160 MHz, DFS off (`main.c`).
- All runtime logging silenced (`main.c`).
- Zero mic: `agent_run_session` spawns only `spk_task` (prio 7) in
  BOYBAND; no `mic_task` / `ws_send_task` / `mute_timer_task` (`agent.c`).
- (I2S is still initialized full-duplex; the RX/mic side just isn't read.
  Making it TX-only is a not-yet-done further step.)

**Stage (`boyband/stage`):**
- FilePlayer **prebuffers** the whole track into the duck's 1 MB buffer
  (wall-clock pace + 700 KB lead).
- DuckConnection: per-duck send queue (isolation) + `maxInFlight=1500`
  backstop (effectively buffer-don't-drop, for pre-recorded playback).
- Control channel: `/play`, `/stop`, `/status` — no Stage restarts
  between runs.

**None of it fixed the underrun.**

## The key unanswered question

If a track is **fully prebuffered into the duck's 1 MB local buffer**,
WiFi delivery should be irrelevant to playback — yet it still underruns.
That points at the duck's **playback path** (spk_task → I2S) stalling for
a non-CPU, non-mic reason… **OR** the prebuffer never actually fills
(data isn't arriving fast/steadily enough even for one duck). **We have
not measured which.** That is the gap.

## What we should have done (and should do next): MEASURE BOTH ENDS

We can instrument both sides simultaneously — we just haven't:

1. **Mac side:** log bytes-sent-per-second per duck and the NWConnection
   send-completion timing (are sends actually completing, and at what
   rate?). Add a counter to `DuckConnection.sendPCM`.
2. **Duck side:** add a **non-blocking** stat path (NOT the USB console —
   that blocks; send a tiny WS *text* frame back to Stage, or a UDP stat
   packet) reporting every ~1s: bytes received, `s_spk_stream` fill level,
   and an I2S underrun counter (increment when `i2s_channel_write` had to
   pad/wait or the stream was empty).
3. Run one track and **compare the two timelines.** This definitively
   localizes the break: if the duck's received-bytes/s tracks 32KB/s but
   the spk_stream still empties → playback-path bug. If received-bytes/s
   sags below 32KB/s → it's delivery (WiFi), even for one duck.

This is ~30 min of instrumentation and would end the guessing.

## Other untried levers (in rough priority)

- **TX-only I2S** in BOYBAND (don't init the mic/RX half at all) — removes
  any residual full-duplex RX-DMA interaction with the speaker TX.
- **Opus compression** over the wire (~24 kbps vs 256 kbps raw). The duck
  already has an Opus decoder (used for embedded phrases). 10× less data
  makes WiFi delivery a non-issue and is how the sibling `uram` project
  reportedly streams. Bigger change (Stage encodes, firmware decodes on
  the agent path), but likely the most robust real fix if delivery is the
  problem.
- **Dedicated network** (travel router) instead of congested IDEO-Guest —
  the show plan anyway; cheap to test with a phone hotspot.
- **Serial / USB-CDC transport** — bypass WiFi entirely (ducks are
  USB-tethered for power). Rock-solid bandwidth, and a clean diagnostic:
  if serial-streamed audio plays clean, the problem was WiFi; if it still
  chokes, it's the playback path. **Explicitly deferred for now per
  Devin (2026-06-01) — do NOT build serial yet.**

## Recommendation

Stop tweaking. Do the **bilateral instrumentation** (§"MEASURE BOTH
ENDS") first — it will tell us whether this is delivery or playback in
one run, and every further fix follows from that answer.

---
*Last updated 2026-06-01. Ducks: Mallard (D1), Pekin (D2). All the
deployed fixes above are committed on `feature/boy-band`.*
