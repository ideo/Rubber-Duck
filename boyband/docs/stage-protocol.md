# Stage ↔ Duck wire protocol

**Authoritative on-the-wire contract** between the Stage app and the
Bambu Duck firmware. Cross-checked against:

- `bambu/relay/duck_proxy.py` (`_eleven_to_duck`, `_duck_to_eleven`,
  `ws_duck_endpoint`) — what the production relay sends
- `bambu/firmware/main/agent.c` (`on_text`, `on_binary`,
  `ws_event_handler`, `type_field_equals`) — what the firmware
  accepts

Stage's job is to be **indistinguishable from the relay** from the
firmware's point of view. If you're modifying Stage and the firmware
stops working, you've drifted from this doc — re-check against the
two files above first.

## Endpoint

- **URL pattern**: Stage listens on `ws://<host>:3334/duck/{D1|D2|D3|D4}`.
- **Plain ws://, not wss://**. The firmware's `relay_url_save`
  accepts either scheme; for boy-band local-only operation we don't
  bother with TLS. (The production relay uses wss:// because it's
  on the public internet.)
- **Path**: the relay uses `/ws/duck`; Stage uses `/duck/{ID}`. The
  firmware doesn't care what the path is — it just opens the URL it
  was given. The path discriminates which physical duck is which on
  Stage's side. See `boyband/docs/duck-id-mapping.md` for how each
  duck knows its own ID.
- **Query params**: the relay reads `?event=<type>&subtask=<name>`
  for notification-triggered sessions. Stage **ignores all query
  params** — boy-band sessions are always "bare." Don't send any.
- **One connection per duck**. Each duck holds the connection open
  for the lifetime of the show; reconnects replace any existing
  Stage-side registration for that duck ID.

## Frames (the actual contract)

### Binary frames, both directions

Raw **int16 LE PCM mono @ 16000 Hz**. No length prefix, no header,
no framing beyond WebSocket's own. One WS binary frame = one audio
chunk.

- **Stage → duck**: agent / show audio. Played through the speaker;
  drives the servo head-bob via RMS. Firmware enqueues into a 1 MB
  stream buffer; if Stage overruns, the firmware drops bytes
  **aligned to 2-byte boundaries** to avoid sample misalignment
  (would otherwise produce white noise). Don't bank on the 1 MB
  buffer — pace sends at ~real time (20 ms chunks at 20 ms intervals).
- **Duck → Stage**: mic PCM. Stage **drops these on the floor** —
  for boy band we use the Mac mic in Mode 2 and don't listen at all
  in Mode 1. The duck still sends them; just route to `/dev/null`.
  Closing the path entirely isn't supported by the firmware — it
  always emits mic when its mic is enabled.

Chunk size: anything reasonable works. The Stage sine generator
uses 320 samples (640 bytes = 20 ms) and that's a good default.
The production relay forwards whatever ElevenLabs sends, which
varies but trends similar.

WebSocket frame **opcode**: 2 (binary) for normal sends. The
firmware also accepts opcode 0 (continuation), so fragmented frames
work — but Stage shouldn't fragment unless there's a reason.

### Text frames, Stage → duck

JSON objects with a `"type"` field. The firmware matches with
`type_field_equals`, which is whitespace-tolerant: spaces or tabs
between the key, colon, and value are all accepted. Use whatever
Python `json.dumps` defaults to (one space after the colon).

| Text frame                  | Effect on firmware |
|---|---|
| `{"type":"ready"}`          | Fires `audio_mic_enable(true)`. Mic starts streaming. **Send this once per session** if you want the duck's mic on; for boy band we generally do not — see note. |
| `{"type":"interruption"}`   | `xStreamBufferReset(s_spk_stream)` — drops queued speaker audio. Mic stays on. Use this to cut a duck mid-line (interrupt button, mode flip). |

Anything else is **silently ignored** by the firmware. No error,
no log noise — just a no-op. Don't rely on unknown types for
anything.

**Note on `ready`**: For boy band Mode 1 (piano roll) and Mode 2
(FAQ), we never want the duck's mic — the audience mic is on the
Mac. Stage should **not** send `{"type":"ready"}` by default. The
fake-duck test script (`boyband/scripts/fake-duck.py`) has a
`--send-ready` flag for exercising the path, but normal Stage
operation skips it.

### Text frames, duck → Stage

Per the firmware comment block at the top of `agent.c`: "duck →
relay : reserved (currently unused)". The firmware doesn't emit any
text frames in normal operation. The relay's `_duck_to_eleven`
debug-logs any it sees (`logger.debug("duck text: %s", ...)`) but
doesn't act on them.

Stage logs incoming text via the `onText` callback. Treat as
diagnostic only; don't build show logic on top of unsolicited duck
text.

## WebSocket control frames

Standard RFC 6455:

- **Ping → Pong**: the firmware's IDF websocket client may send
  pings. Stage's `StageServer` already echoes payloads back as pong
  (opcode 0xA) — nothing to do.
- **Close (0x8)**: either side can initiate. Stage closes its
  registry slot for that duck on disconnect.

The production relay doesn't send pings (it relies on the IDF
client side); Stage doesn't either. Either is fine.

## What Stage does NOT have to implement

- ElevenAgents bridge logic (`_eleven_to_duck` / `_duck_to_eleven`)
   — we don't talk to ConvAI.
- `_silence_pump` (keeps the upstream session alive when chip is
  mute) — ConvAI requirement, not a firmware requirement.
- `conversation_initiation_metadata` → `{"type":"ready"}`
  translation — the relay does this when ConvAI signals session
  start. For boy band, send `ready` only if you want the duck's mic
  on (you almost never do).
- Tool-call routing (`/tools/printer_state/{duck_id}` etc.) —
  Bambu MQTT integration, unrelated.
- `X-Duck-Id` header / `dynamic_variables` — multi-tenant ConvAI
  plumbing.
- Auth (`X-Relay-Secret`) — local-only, no auth.
- Notify channel (`/ws/notify`) — printer-event push, unused for
  boy band.

## Audio pacing — practical guidance

The firmware's speaker drain task pulls from `s_spk_stream` and
pushes into I2S DMA. At 16 kHz mono int16 that's 32000 bytes/sec
sustained. A 1 MB buffer = ~32 s of headroom, but burst-sending all
of it is unwise:

- A burst delays interruption — if Stage sends 30 s of audio in one
  go and an interrupt button is hit, the duck will keep playing
  whatever's in its buffer until `interruption` clears it. Sending
  in real time (20 ms chunks at 20 ms intervals) keeps interrupt
  latency under 50 ms.
- WiFi retransmits can stall briefly. Real-time pacing means the
  buffer fills slightly during a stall and drains during recovery,
  which is graceful. Bursty sends amplify stalls into audible gaps.

The Stage `SineGenerator` already paces at 20 ms via
`DispatchSource.makeTimerSource`. New audio sources (BlackHole,
TTS) should do the same.

## Sample-aligned drops

If Stage somehow overruns the 1 MB buffer, the firmware drops bytes
**aligned to an even count**. This matters because the buffer holds
int16 samples (2 bytes each). An odd-count drop would shift every
subsequent sample's high/low bytes — turning the rest of the
utterance into white noise. The aligned-drop logic in `on_binary`
(`free_bytes & ~(size_t)1`) prevents that.

So an overrun sounds like a brief silent skip, not garbage. Still
shouldn't happen in practice — but if you hear a hiccup during
testing, that's the symptom.

## Sanity check before changing anything

The end-to-end test in `boyband/scripts/fake-duck.py` exercises:

- Connect on `/duck/D2`
- Receive Stage's binary PCM (sine), write to WAV
- Send `{"type":"ready"}` text frame upstream (Stage logs it)
- Disconnect cleanly

Run it after any protocol-affecting change. Frequency analysis of
the output WAV confirms byte-level correctness (no endianness slip,
no sample-rate drift). See `STATE.md` "Where we are" for the
verified-correct numbers.
