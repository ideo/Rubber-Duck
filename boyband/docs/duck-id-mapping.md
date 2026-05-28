# Duck ID mapping

How each physical duck knows whether it's D1, D2, D3, or D4 on stage.

## The constraint

The Bambu Duck firmware **already** opens `<relay_url>/ws/duck` and
identifies itself with an `X-Duck-Id: <chip MAC>` header during the
WebSocket handshake. See `bambu/firmware/main/agent.c` ~line 363:

```c
snprintf(url, sizeof(url), "%s/ws/duck", relay_base);
// ...
"X-Duck-Id: %s\r\n", duck_id_get()
```

The chip MAC is a stable, unique 12-hex-char string. The boy-band
rule (`CLAUDE.md`) is **don't modify firmware**. So the design
question is: how does Stage map four MACs to D1..D4?

## Options considered

| | Approach | Verdict |
|---|---|---|
| A | NVS-bake a `boyband_duck_id` field at provisioning time, change firmware to append it to the URL path | ❌ Needs firmware change |
| B | Claim-on-connect (first to connect = D1, etc.) | ❌ Order-fragile; depends on boot/WiFi timing; operator can't predict which is which |
| C | Stage maps the existing chip-MAC `X-Duck-Id` to a slot via a config file | ✅ **Chosen.** Zero firmware change, stable across reboots, operator-explicit |
| D | Hold a button on boot to claim a slot | ❌ Re-claimable but easy to fat-finger; physical UI we don't have |

## The design

Stage accepts **two URL shapes**:

1. **Production**: `ws://<host>:3334/ws/duck` + `X-Duck-Id: <MAC>`
   header → Stage looks up MAC in `duck-map.local.json`, routes to
   the assigned slot. **This is what real ducks do.**
2. **Test/dev**: `ws://<host>:3334/duck/{D1|D2|D3|D4}` → Stage uses
   the path-suffix as the slot directly. **This is what
   `fake-duck.py` and manual testing use.** It bypasses the MAC
   map. Real firmware never hits this path because the firmware
   hardcodes `/ws/duck`.

Both shapes resolve to the same `DuckConnection` registry slot. From
that point on, Stage treats them identically.

### Config file

`boyband/duck-map.local.json` (gitignored, per-Mac), keyed by chip
MAC, value is the slot:

```json
{
  "A0B7657ECC10": "D1",
  "A0B7657ECCE4": "D2",
  "A0B7657FA38C": "D3",
  "A0B7657FB504": "D4"
}
```

MACs are case-insensitive; Stage uppercases on lookup. Format
matches what `duck_id_get()` returns in `bambu/firmware/main/duck_id.c`
(uppercase hex, no separators).

A committed `boyband/duck-map.example.json` documents the format
without leaking specific MACs from individual developer hardware.

### How to find a duck's MAC

Three ways, ordered by convenience:

1. **From Stage logs**: connect the duck once; if its MAC isn't in
   the map, Stage closes the WS with a clear log line
   (`reject MAC=A0B7657ECC10 — not in duck-map.local.json`). Copy
   the MAC from the log into the file, restart, reconnect.
2. **From the Bambu relay's SQLite** (`bambu/relay/ducks.db`) if
   the duck has been onboarded to a relay. `SELECT duck_id, ...`.
3. **From `idf.py monitor` serial logs** during boot — the chip
   logs its `duck_id` early in startup.

### CLI overrides for sound-check

```sh
# Force a specific map file (default: boyband/duck-map.local.json)
swift run BoyBandStage --duck-map ./my-show-map.json

# Run without a map at all (test/dev mode — only /duck/{ID} works,
# /ws/duck connections are rejected)
swift run BoyBandStage --no-duck-map
```

### What happens at the venue

1. T-2 hours, operator plugs in four ducks. They join WiFi, attempt
   to connect to `ws://stage.local:3334/ws/duck`.
2. If the map is right, all four show up as D1..D4 in Stage's UI/log
   within ~5 seconds of boot.
3. If a MAC isn't in the map, that duck shows up in the log with a
   "rejected — not in map" line and the operator adds it.
4. If a MAC is in the map but pointed at the wrong physical
   position, the operator swaps physical ducks (or edits the file
   + restarts Stage) until D1 is on the left.

The map is the **only** thing that ties physical ducks to slot IDs.
Keeping it in a JSON file means an operator can hand-edit on the
fly — no rebuild, no firmware reflash, no NVS write tools.

## What this rules out (intentionally)

- **Hot-swapping ducks mid-show without restart.** If a duck dies
  and you replace it, Stage will see the new MAC and reject it
  unless the map is edited and Stage is restarted. Acceptable for a
  one-time show; an irritation for repeat runs.
- **Operator confusion about which duck is which.** The map is the
  source of truth. If you can't tell which physical duck is D1, the
  operator's first move is `tail -f stage.log` and watch for
  connect logs.

## Future: if this is wrong

If the show day arrives and the map approach is fighting us,
fallback is **option B (claim-on-connect)** behind a `--no-duck-map
--auto-assign` pair of flags. Each new MAC gets the next free slot.
Order then depends on boot order, which we can control by
power-cycling ducks in sequence.

We don't ship this fallback now — premature. But knowing it's a
30-line addition to `StageServer.swift` makes the chosen design
less risky to commit to.
