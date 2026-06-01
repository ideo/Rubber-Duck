# Boy Band WebSocket Audio Handoff

Status as of 2026-06-01: the current best working theory is that the
Stage-initiated 100 ms WebSocket heartbeat fixed the intermittent choppy
duck playback.

## Current branch and commits

Branch: `feature/boy-band`

Relevant pushed commits:

- `6511286` — fixed Stage pacing, odd-byte PCM alignment, socket health/kick
  endpoints, and duck/Stage audio telemetry.
- `eaaee98` — added Stage WebSocket ping/pong heartbeat diagnostics.
- `9fd5ffa` — changed heartbeat cadence from 5 seconds to 100 ms for ESP32
  WiFi responsiveness.

## What changed

Stage now sends a tiny RFC WebSocket ping to each duck every 100 ms, starting
100 ms after connection. Ducks respond with normal WebSocket pong frames.

`/status` now includes:

- `pong`: latest ping-to-pong latency.
- `maxPong`: worst observed ping-to-pong latency for that socket.
- `pongAge`: age of the latest pong.

`/health` marks a duck unhealthy if:

- Stage has >= 64 KB audio queued in flight.
- Last audio send completion is >= 1000 ms.
- Latest pong latency is >= 500 ms.
- A ping has been outstanding for >= 1000 ms.

The ESP32 firmware already calls `esp_wifi_set_ps(WIFI_PS_NONE)` in
`bambu/firmware/main/wifi.c`, which disables modem sleep. The 100 ms Stage
heartbeat is a practical keep-warm/early-warning layer on top of that.

## Test evidence

All tests below used the real connected ducks:

- D1: Mallard, `DCB4D92961E9`
- D2: Pekin, `DCB4D9296125`

### Moby two-duck test

Command:

```sh
cd boyband/stage
swift run BoyBandStage --port 3334 \
  --play ../stems/test/moby_D1.wav D1 \
  --play ../stems/test/moby_D2.wav D2 \
  --wait-trigger
```

Preflight:

- D1 pong around 15 ms, healthy.
- D2 pong around 16 ms, healthy.

After playback:

- D1: full `1129/705.6KB`, `0` drops, `0B` in flight, max ACK `1.3ms`.
- D2: full `1129/705.6KB`, `0` drops, `0B` in flight, max ACK `1.3ms`.
- Duck telemetry: both reached full `722560` bytes, no drops, no send
  failures.

### Original dialogue two-duck test

Command:

```sh
cd boyband/stage
swift run BoyBandStage --port 3334 \
  --play ../stems/test/dialogue_D1.wav D1 \
  --play ../stems/test/dialogue_D2.wav D2 \
  --wait-trigger
```

Preflight:

- D1 pong around 15 ms, healthy.
- D2 pong around 16 ms, healthy.

After playback:

- D1: full `732/457.5KB`, `0` drops, `0B` in flight, max ACK `2.2ms`.
- D2: full `732/457.5KB`, `0` drops, `0B` in flight, max ACK `2.3ms`.
- Duck telemetry during playback stayed near the target 32 KB/s with no drops
  or send failures.

## Operator commands

Start a two-duck cue:

```sh
cd boyband/stage
swift run BoyBandStage --port 3334 \
  --play ../stems/test/dialogue_D1.wav D1 \
  --play ../stems/test/dialogue_D2.wav D2 \
  --wait-trigger
```

Check health before playing:

```sh
curl http://localhost:3334/status
curl http://localhost:3334/health
```

Trigger:

```sh
curl http://localhost:3334/play
```

Kick a bad socket and wait for reconnect:

```sh
curl http://localhost:3334/kick/D1
curl http://localhost:3334/health
```

## Interpreting results

Good preflight:

- `health=ok`
- `inFlight=0/0B`
- `pong` usually tens of milliseconds
- `pongAge` below roughly 100 ms because heartbeat cadence is 100 ms

Bad preflight:

- `bad(inFlight=...)`
- `bad(lastAck=...)`
- `bad(pong=...)`
- `bad(missingPong=...)`

If a duck is bad before playback, kick it and wait for reconnect before
triggering the cue.

## Crash versus reconnect

The tests above did not intentionally reboot ducks. Restarting Stage or using
`/kick` closes only the WebSocket; BOYBAND firmware then reconnects.

Opening a USB serial monitor can reset an ESP32 via DTR/RTS, but these
playback tests did not use serial monitoring.

If a duck crashes, expect USB boot logs, brownout/panic output, or the device
to disappear/reappear on `/dev/cu.usbmodem*`. The clean test logs looked like
normal WebSocket reconnects, not chip crashes.

## Four-duck watchouts

Two good ducks does not prove four good ducks, but this fix addresses the
specific failure pattern observed on Mallard: long send backlog, huge ACK
latency, and audible underruns.

Before relying on four ducks:

- Flash all ducks with the same firmware build.
- Run `/health` and verify all four pongs stay fresh.
- Run the longest four-duck cue at least twice.
- Watch `maxPong`, `maxAck`, `inFlight`, and duck-side `rx_max_gap_ms`.
- Keep serial transport as the backup if WiFi becomes inconsistent again.

## SSE and serial decision

SSE is not recommended for showtime audio. It would still be TCP over WiFi,
would not remove the ESP32/WiFi timing risk, and is worse for raw binary audio.

USB serial remains the reliability fallback because it bypasses WiFi entirely.
For four ducks, the raw audio payload is about 128 KB/s total at 16 kHz mono
int16, which is trivial for USB through a powered hub. The work would be a
new Stage serial sender and a firmware USB receive mode.
