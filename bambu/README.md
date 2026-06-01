# Bambu Duck

> **🦆 Flash a duck from your browser:**
> [ideo.github.io/Rubber-Duck/flash](https://ideo.github.io/Rubber-Duck/flash/)
> (Chrome / Edge — uses WebSerial, no install needed)
>
> All three flashing paths (web / `make` / `esptool`), what to expect
> after flash, and every gotcha that's cost time: **[docs/FLASHING.md](docs/FLASHING.md)**.

A standalone, conversational rubber duck that lives next to a Bambu 3D
printer. No Mac, no plugin, no companion app — the duck has a real
conversation through ElevenLabs Conversational AI, and can query the
printer's live state mid-sentence. It also speaks up unprompted when
notable things happen on the printer (print started, print finished,
print failed, AMS jam, etc).

> Sibling to the Mac/Claude Code duck in this repo's parent
> [`README.md`](../README.md). They share the same voice character and
> hardware lineage, but they live in different host environments and
> have no runtime overlap.

## Architecture

```
                  ┌────────────────────────────────────────────────┐
                  │                                                │
                  ▼                                                │
[duck ESP32-S3]  ──wss──→  [relay (Fly.io)]  ──wss──→  [ElevenAgents]
       ↑                          │                       (LLM, voice,
       │                          │                        tools fire
       │                          │                        webhooks back
       │                          │                        to the relay)
       └────── speaker ────────── │ ──MQTT──→ [Bambu cloud broker]──→ [printer]
```

Three independent pieces:

| Dir | What | Status |
|---|---|---|
| [`firmware/`](firmware/) | ESP-IDF v5.3.4 for ESP32-S3. Two hardware variants (custom ducky PCB + standard XIAO Seeed S3 with cobbled mic/amp). Captive-portal onboarding, embedded Opus phrases, full chirp synth, double-tap wake gesture. | Working — daily-driven on hardware |
| [`relay/`](relay/) | Python FastAPI service on Fly.io. Multi-tenant — per-duck Bambu MQTT subscription, ElevenAgents session bridging, push-notification fan-out for printer events. | Working — deployed to `duck-duck-print.fly.dev`, fully self-hostable |
| [`elevenlabs/`](elevenlabs/) | Source-of-truth ElevenAgents agent template (system prompt, tool schemas, voice). [`DEPLOY.md`](DEPLOY.md) substitutes placeholders and POSTs to ElevenLabs to create an agent. | Working — agent template is one-shot deployable |

## How the agent gets printer-aware

ElevenAgents lets you define **Server Tools** — HTTP webhooks the LLM
can call mid-conversation. The relay exposes three:

- `GET /tools/printer_state` — current stage, percent, layer, temps, HMS codes
- `GET /tools/temperatures` — nozzle / bed / chamber subset
- `GET /tools/print_history?n=N` — last N print outcomes

When the user says "how's the dragon coming along?", the LLM calls
`get_printer_state`, gets live JSON, and replies in natural language
with the duck's voice. Routing to the right tenant on a multi-duck
relay happens via an `X-Duck-Id` request header that ElevenAgents
fills from a per-session dynamic variable — see the comment in
[`elevenlabs/agent-template.json`](elevenlabs/agent-template.json) and
the `_send_init` function in [`relay/duck_proxy.py`](relay/duck_proxy.py).

## What it sounds like

- **Boot / wifi-connect / "I'm connected!"** — the chip plays embedded
  Opus phrases (pre-recorded ElevenLabs TTS, baked in flash) for the
  pre-WiFi states where the agent isn't reachable yet.
- **Wake** — single double-tap on the duck (or a button press) opens
  a conversation. A short ascending chirp confirms.
- **Conversation** — full bidirectional with the agent. Agent can
  call tools mid-sentence to read printer state, history, temperatures.
- **Printer notifications** — when a print starts, finishes, fails,
  pauses, or hits an HMS error, the relay pushes a notify event. The
  chip wakes for an agent session, the agent speaks the announcement
  in the project voice. Failed prints / HMS errors get a distinct
  "uh-uh" pre-cue chirp so the user knows it's bad news before the
  voice arrives.
- **Errors on the duck side** (wifi failed, wizard failed) get a
  randomized "uh-oh" chirp — distinct from the printer-fault uh-uh
  so the listener can tell whether the duck or the printer is the
  source of the problem.

## Onboarding (the user's experience)

1. Power on the duck. If it has no WiFi creds yet, it plays "Press
   my button when you're ready and I'll set up a WiFi network you
   can join."
2. Press the button → the chip starts a SoftAP called
   `DuckDuckDuck-XXXX`.
3. Phone joins that AP. iOS / Android auto-pop a captive portal, or
   you browse to `192.168.4.1` manually.
4. Form: home WiFi credentials, Bambu account email + password,
   (optional) ElevenLabs API key + agent ID.
5. Hit Save. The chip joins your home WiFi, calls Bambu cloud login
   on your behalf via the relay, fetches your printer list. If you
   have multiple printers, a picker page lets you select which ones
   the duck should listen to.
6. The duck speaks "All set. I'm listening for [your printers]. Get
   printing!" — and you're done.

The whole flow takes about 60 seconds.

## Hardware variants

Two builds share one source tree, switched at compile time:

| Variant | Board | Mic | Amp | Antenna | Build flag |
|---|---|---|---|---|---|
| **Ducky PCB** (default) | Custom WROOM-1 module | ICS-43432 | MAX98357A | PCB trace (strong) | (none) |
| **XIAO** | Seeed XIAO ESP32-S3 | ICS-43434 (cobbled) | MAX98357A breakout | Chip antenna (weaker) | `DUCK_VARIANT=XIAO` |

The XIAO build exists for hobbyists who want to assemble from common
parts without ordering a custom PCB. Both variants use the same
firmware, same captive portal, same agent. Performance is comparable
on strong WiFi; on weaker WiFi the XIAO sees more `mic stream full`
backpressure events (hence the 64KB ring + drop-oldest handling — see
the [#50 fix](https://github.com/ideo/Rubber-Duck/issues/50) in
`firmware/main/agent.c`).

## Build flavors

- **Default (open-source distributable)** — captive portal exposes
  ElevenLabs API key + agent ID fields. Each self-hoster brings their
  own ElevenLabs account.
- **Turnkey** (`-DBAMBU_DUCK_TURNKEY=1`) — strips the ElevenLabs fields
  from the captive portal. For ducks you flash and hand to someone
  else, where YOUR relay's Fly secrets supply shared creds. End user
  just enters WiFi + Bambu credentials.

```bash
cd bambu/firmware
source ~/esp/esp-idf/export.sh

make flash-ducky    PORT=/dev/cu.usbmodem101    # ducky PCB, default build
make flash-xiao     PORT=/dev/cu.usbmodem101    # XIAO, default build
make flash-turnkey  PORT=/dev/cu.usbmodem101    # ducky PCB, turnkey build
```

## Self-hosting (the relay)

[`DEPLOY.md`](DEPLOY.md) is a runbook written for **Claude Code as
the executor**. Drop into the repo, run `claude` inside `bambu/`,
ask "deploy a bambu duck for me." The runbook walks Claude through:

- Fly app + volume creation
- `RELAY_SHARED_SECRET` generation
- `fly deploy`
- ElevenLabs agent creation from
  [`elevenlabs/agent-template.json`](elevenlabs/agent-template.json)
- Handoff back to you to flash a chip and onboard

End-to-end: ~5 minutes. The chip side is a separate one-time flash
(see `bambu/firmware/README.md`); the captive portal handles all
per-user config.

If you'd rather drive it manually, [`relay/README.md`](relay/README.md)
covers the bare commands.

## Self-hosting (the chip)

You only need to flash a duck once — captive-portal onboarding handles
all per-user configuration after that. Walkthrough:

```bash
cd bambu/firmware
source ~/esp/esp-idf/export.sh   # ESP-IDF v5.3.4 required
make flash-ducky PORT=/dev/cu.usbmodem101    # or flash-xiao, flash-turnkey
make monitor-ducky PORT=/dev/cu.usbmodem101  # optional: tail serial logs
```

Once flashed, plug into a USB power source and follow the on-duck
onboarding flow above.

## What's intentionally not here

- **Destructive printer tools** (pause, stop, parameter changes). The
  agent is read-only by design. Adding any actuating tool requires a
  per-call authority model first; we'd rather lose convenience than
  let a malicious agent prompt accidentally cancel a 30-hour print.
- **Print-history persistence across relay restarts.** Kept in memory,
  rebuilt on MQTT reconnect. The duck doesn't need to memory-manage —
  Bambu cloud holds the durable state.
- **Wake word.** Currently button + double-tap. Wake-word ("ducky")
  via microWakeWord is on the roadmap but waiting on a few hardware
  preconditions (amp shutdown wiring) for a clean power story.
- **LAN-only mode.** The relay is built around Bambu cloud MQTT (TLS-
  verified, multi-printer per account). LAN-direct still exists in
  code as a dev fallback but isn't a supported deployment shape.

## License

Software (firmware C, relay Python, agent JSON, scripts) — [MIT
License](../LICENSE). Hardware (firmware C bound to specific ICs, PCB,
enclosure CAD) — [CERN-OHL-P-2.0](../firmware/LICENSE).

## Background reading

For the deep architecture + reverse-engineering rationale (Bambu cloud
auth, MQTT topic shape, why we picked ElevenAgents):
[`docs/BAMBU-DUCK-API-SURVEY.md`](../docs/BAMBU-DUCK-API-SURVEY.md).

For Claude Code conventions when working in this subtree:
[`CLAUDE.md`](CLAUDE.md).
