# Boy Band Effort Handoff

Status as of 2026-06-01: two real ducks are playing the test cues
consistently over WebSocket after the 100 ms Stage heartbeat change. The
current best working theory is that the heartbeat keeps the ESP32 WiFi path
responsive enough to avoid the intermittent long-backlog failure that caused
Mallard to chop.

## Goal

Make multiple physical ducks play pre-rendered show audio in sync from a Mac.
The immediate production path is:

1. Stage app runs on the Mac.
2. Ducks connect to Stage over WebSocket.
3. Stage streams raw 16 kHz mono int16 PCM to each duck.
4. Ducks play PCM through their existing I2S speaker path.

The original target is four ducks at once. This handoff covers the current
two-duck validated state and the remaining four-duck watchouts.

## Current Git State

Branch: `feature/boy-band`

This file supersedes the narrower WebSocket-heartbeat-only handoff that was
first added in `2a73e99`.

Relevant pushed implementation commits:

- `6511286` — fixed Stage audio pacing, odd-byte PCM alignment, socket
  health/kick endpoints, and duck/Stage telemetry.
- `eaaee98` — added Stage WebSocket ping/pong heartbeat diagnostics.
- `9fd5ffa` — changed heartbeat cadence from 5 seconds to 100 ms for ESP32
  WiFi responsiveness.

## Hardware Seen

Real ducks used in testing:

- D1: Mallard, duck id `DCB4D92961E9`, serial port observed as
  `/dev/cu.usbmodem101`.
- D2: Pekin, duck id `DCB4D9296125`, serial port observed as
  `/dev/cu.usbmodem1101`.

Duck slot mapping lives in `boyband/duck-map.local.json` and is gitignored.
The example format is in `boyband/duck-map.example.json`.

## Architecture

Stage:

- Swift package in `boyband/stage`.
- Main executable: `BoyBandStage`.
- WebSocket/HTTP server: `boyband/stage/Sources/BoyBandStage/StageServer.swift`.
- File playback/resampling: `boyband/stage/Sources/BoyBandStage/FilePlayer.swift`.

Firmware:

- BOYBAND build is in `bambu/firmware`.
- Main WebSocket audio path is in `bambu/firmware/main/agent.c`.
- WiFi setup is in `bambu/firmware/main/wifi.c`.
- Firmware already disables ESP32 modem sleep with
  `esp_wifi_set_ps(WIFI_PS_NONE)`.

Wire format:

- Stage to duck binary WebSocket frames: raw PCM, 16 kHz, mono, int16 little
  endian.
- Duck to Stage text WebSocket frames: JSON telemetry once per second.
- Stage to duck ping frames: RFC WebSocket ping every 100 ms.
- Duck to Stage pong frames: normal WebSocket pong.

## Important Fixes Made

### Audio pacing

Stage now sends strict 20 ms PCM frames:

- `640` bytes per frame.
- `320` samples per frame.
- One frame of lead.
- Final partial frame padded to a full 20 ms block.

This avoids large WebSocket/TCP bursts and keeps the duck buffer from being
overfilled.

### Odd-byte PCM carry

Firmware now carries odd leftover bytes across WebSocket fragments instead of
allowing an int16 alignment shift. That addresses the white-noise/garble class
of failure where a dropped odd byte corrupts all following samples.

### Socket health and recovery

Stage now exposes:

- `/status` — connected ducks, sent/completed bytes, in-flight backlog, ACK
  latency, drops, pong latency.
- `/health` — concise OK/bad status for each connected duck.
- `/kick` — kick all bad sockets.
- `/kick/D1` or `/kick?duck=D1` — kick one duck socket.
- `/play` — preflights current sockets and refuses to start if it had to kick
  unhealthy ducks.
- `/stop` — stop current playback.

### Duck telemetry

Firmware sends once-per-second JSON stats over the existing WebSocket, avoiding
USB serial monitor resets and serial logging stalls.

Key fields:

- `rx_total`
- `spk_total`
- `rx_bps`
- `spk_bps`
- `rx_max_gap_ms`
- `spk_max_gap_ms`
- `spk_gap_over_80ms`
- `dropped`
- `stat_send_failures`

### 100 ms Stage heartbeat

Stage now sends WebSocket pings every 100 ms, starting 100 ms after connection.

`/status` includes:

- `pong`: latest ping-to-pong latency.
- `maxPong`: worst observed ping-to-pong latency for that socket.
- `pongAge`: age of the latest pong.

`/health` marks a socket bad if:

- Stage has >= 64 KB audio queued in flight.
- Last audio send completion is >= 1000 ms.
- Latest pong latency is >= 500 ms.
- A ping has been outstanding for >= 1000 ms.

This was the change that made the latest tests consistent.

## Debugging History

Early failures sounded like:

- White noise / garble.
- Slow playback.
- Roughly 0.5 second audio gaps.
- Mallard sometimes broken while Pekin worked.
- Later, Mallard sometimes worked after reconnect, then failed again under the
  longer Moby test.

Important observations:

- When bad, Stage showed huge send backlog and ACK latency on Mallard, for
  example hundreds of KB in flight and `lastAck` over 15 seconds.
- Duck stats showed receive and speaker gaps rising together, which pointed
  to delivery/socket timing rather than I2S playback stalling.
- Restarting Stage or kicking a socket caused WebSocket reconnects, not ESP
  reboots.
- Opening USB serial can reset ESP32 via DTR/RTS, but serial monitoring was
  not used for the final playback tests.

Failed or partial attempts:

- 240 MHz diagnostic round did not solve it; user requested staying at 160 MHz.
- WebSocket kick/reconnect helped with stale/bad sockets but did not by itself
  prevent Mallard from falling behind again on Moby.
- 5 second heartbeat was too slow for the ESP32 WiFi responsiveness concern.

Working pattern:

- 100 ms WebSocket heartbeat plus the pacing/alignment fixes produced clean
  Moby and dialogue runs on D1 and D2.

## Validated Tests

All tests below used the real D1/D2 ducks.

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

## Build and Flash

Stage build:

```sh
cd boyband/stage
swift build
```

Known warning:

- Swift reports pre-existing sendability warnings in
  `boyband/stage/Sources/BoyBandStage/main.swift` around captured `loaded`.
  Builds still pass.

BOYBAND firmware build:

```sh
cd bambu/firmware
make build-boyband STAGE_URL=ws://10.5.128.41:3334 VOL_STEP=2
```

Flash one duck:

```sh
cd bambu/firmware
make flash-boyband PORT=/dev/cu.usbmodem101 STAGE_URL=ws://10.5.128.41:3334 VOL_STEP=2
```

Flash simultaneously when possible by running separate terminal jobs, one per
port, after verifying which physical duck is on each port.

## Operator Runbook

Start a two-duck cue:

```sh
cd boyband/stage
swift run BoyBandStage --port 3334 \
  --play ../stems/test/dialogue_D1.wav D1 \
  --play ../stems/test/dialogue_D2.wav D2 \
  --wait-trigger
```

Check before triggering:

```sh
curl http://localhost:3334/status
curl http://localhost:3334/health
```

Good preflight:

- `health=ok`
- `inFlight=0/0B`
- `pong` usually tens of milliseconds.
- `pongAge` below roughly 100 ms.

Trigger:

```sh
curl http://localhost:3334/play
```

Stop:

```sh
curl http://localhost:3334/stop
```

Kick a bad socket and wait for reconnect:

```sh
curl http://localhost:3334/kick/D1
curl http://localhost:3334/health
```

Bad health examples:

- `bad(inFlight=...)`
- `bad(lastAck=...)`
- `bad(pong=...)`
- `bad(missingPong=...)`

If a duck is bad before playback, kick it and wait for reconnect before
triggering the cue.

## Crash Versus Reconnect

The final tests did not intentionally reboot ducks.

These operations are normal WebSocket reconnects, not chip reboots:

- Restarting Stage.
- Stopping Stage.
- `/kick/D1`.
- `/kick/D2`.

Opening a USB serial monitor can reset an ESP32 via DTR/RTS. Avoid serial
monitoring during playback tests unless specifically diagnosing boot/crash
behavior.

If a duck actually crashes, expect one or more of:

- USB boot logs.
- Brownout or panic traces.
- Device disappearing/reappearing on `/dev/cu.usbmodem*`.
- Stage showing a full disconnect followed by a fresh boot-era reconnect.

## Four-Duck Watchouts

Two good ducks does not prove four good ducks. Four ducks at 16 kHz mono int16
is about 128 KB/s of raw audio before WebSocket/TCP/WiFi overhead. That should
be reasonable on clean WiFi, but four devices increase airtime, contention,
and the chance one duck has a marginal connection.

Before relying on four ducks:

- Flash all ducks with the same firmware build.
- Confirm all four map correctly to D1-D4.
- Run `/health` and verify all four pongs stay fresh.
- Run the longest four-duck cue at least twice.
- Watch `maxPong`, `maxAck`, `inFlight`, and duck-side `rx_max_gap_ms`.
- Test from the actual show network or a dedicated travel router/hotspot.
- Keep USB serial transport as the fallback if WiFi becomes inconsistent.

## SSE and Serial Decision

SSE is not recommended for showtime audio. It is still TCP over WiFi, does not
remove the ESP32/WiFi timing risk, and is worse for raw binary audio because
audio would need base64 or another text framing scheme. It also gives up the
simple bidirectional WebSocket path unless a second channel is added.

USB serial remains the reliability fallback because it bypasses WiFi entirely.
For four ducks, the raw payload is about 128 KB/s total at 16 kHz mono int16,
which is trivial for USB through a powered hub.

Serial fallback would require:

- A Stage serial sender that opens all duck ports.
- A stable serial port to duck-slot mapping.
- A firmware USB receive mode.
- Careful DTR/RTS handling because opening ESP32 serial ports can reset chips.
- Shared-clock 20 ms frame writes, same as the WebSocket path.

## Files to Read Next

- `boyband/stage/Sources/BoyBandStage/StageServer.swift`
- `boyband/stage/Sources/BoyBandStage/FilePlayer.swift`
- `bambu/firmware/main/agent.c`
- `bambu/firmware/main/wifi.c`
- `boyband/docs/audio-garble-debugging.md`
- `boyband/docs/show-runbook.md`
- `boyband/docs/duck-id-mapping.md`
