# Stage ↔ Duck wire protocol

**Goal:** Stage app speaks the **exact same protocol** that the Bambu
relay (`bambu/relay/duck_proxy.py`) speaks to the firmware
(`bambu/firmware/main/agent.c`). Firmware doesn't know which one
it's connected to.

## Status

**Stub.** Filled in for real during Week 1 by reading
`bambu/relay/duck_proxy.py` and `bambu/firmware/main/agent.c`
side-by-side, then copy/pasting the concrete frame shapes here. Do
that work in Week 1 — don't try to design a new protocol.

## Endpoint

- Stage listens on `ws://0.0.0.0:3334/duck/{D1|D2|D3|D4}`.
- Duck firmware's NVS `relay_url` is set to `ws://stage.local:3334`
  (mDNS) or the Mac's static LAN IP on the show WiFi.
- Each duck opens **one** connection and holds it. Stage tracks 4
  connections by URL path.

## Frames (to be confirmed during Week 1 spike)

From the existing Bambu pipeline, expect roughly:

- **Binary frames Stage → duck:** raw PCM int16 mono @ 16 kHz, ~20ms
  chunks. Firmware enqueues into the speaker DMA ring.
- **Text frames Stage → duck:** JSON control messages — at minimum
  some equivalent of `{"type":"audio_end"}` to signal end of a
  speak block (and reset the wobble envelope). Confirm exact `type`
  strings from `agent.c`'s `type_field_equals` switch.
- **Binary frames duck → Stage:** mic PCM. **Ignored by Stage in
  Mode 1 and Mode 2** (we use the Mac mic). We may want to actively
  tell the duck to stop sending to save bandwidth — TBD whether the
  protocol supports that or we just drop on the floor.
- **Text frames duck → Stage:** status / heartbeat — log them,
  don't act on them.

## What Stage does NOT have to implement

- ElevenAgents bridge logic (we don't talk to ConvAI).
- Tool-call routing (no Bambu MQTT).
- `dynamic_variables` / `conversation_initiation_client_data`.
- Auth (`X-Relay-Secret`) — local only, no auth needed. If we ever
  expose Stage on a non-local network, this changes.

## Implementation plan (Week 1)

1. Read `bambu/relay/duck_proxy.py` end-to-end, write down every
   frame type it sends to or receives from the duck.
2. Cross-check against `agent.c`'s `on_text` / `on_binary` handlers.
3. Replace this section with a concrete table of frame types,
   directions, and payload shapes.
4. Build the smallest possible NWListener-based WebSocket server
   that accepts a connection on `/duck/D1` and streams a sine PCM
   continuously. Verify with one real duck.

## Note for future-us

If the protocol changes on the Bambu side, this doc may go stale.
Re-spike from `agent.c` before show prep starts; don't trust this
table over the source.
