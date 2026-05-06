"""HMS error code → friendly TTS phrase lookup (#43).

Bambu's MQTT push_status includes `hms` arrays of {attr, code} entries.
Each pair concatenates to a 16-char uppercase hex key matching the
codes published by Bambu / mirrored in the Home Assistant Bambu Lab
integration.

Source: greghesp/ha-bambulab `hms_en.json` (decompressed `device_hms`
map, ~5000 entries), filtered to severity ≥1, paraphrased for short
TTS-friendly delivery (under 50 chars, conversational, specific
about which slot/axis when the code carries that info).

Coverage: top ~95 codes covering AMS A tangle/runout/RFID/buffer
issues, AMS Lite + AMS HT slot motor overloads, hotend/heatbed
heater faults, X/Y/Z homing failures, build plate detection,
nozzle clogs, fan stalls, network + module + storage faults, front
door, fire extinguisher (H2D), external spool runout. Codes not in
this dict either fall outside our top-50-of-real-world set or are
severity 0 (info chatter we filter out before lookup anyway).

For codes we don't have a phrase for, callers fall back to a
generic "the printer is reporting an error" — the original behavior
before this lookup landed.
"""

# duck_id-style 16-char uppercase hex keys.
HMS_CODES: dict[str, str] = {
    # --- Heatbed (0300_0001) ---
    "0300010000010001": "heatbed heater short circuit",
    "0300010000010002": "heatbed heater open circuit",
    "0300010000010003": "heatbed over temperature",
    "0300010000010005": "heatbed control fault, power off now",
    "0300010000010006": "heatbed temp sensor short circuit",
    "0300010000010008": "heatbed heating abnormal",
    "030001000001000A": "heatbed AC board may be broken",
    "030001000002000F": "chamber temp set too high vs heatbed",

    # --- Hotend / nozzle temp (0300_0002) ---
    "0300020000010001": "nozzle heater short circuit",

    # --- Hotend cooling fan (0300_0003) ---
    "0300030000010001": "hotend cooling fan stopped",
    "0300030000020002": "hotend cooling fan running slow",

    # --- Part cooling fan (0300_0004) ---
    "0300040000020001": "part cooling fan stopped",

    # --- Driver / motor cooling (0300_0005) ---
    "0300050000010001": "motor driver overheating",

    # --- Extrusion / extruder (0300_0009) ---
    "0300090000020001": "extruder motor overloaded, possible clog",
    "0300090000020002": "extrusion resistance abnormal, possible clog",
    "0300090000020003": "extruder extruding abnormally",
    "0300090000020004": "extrusion resistance abnormal",
    "0300090000020005": "extruder extruding abnormally",
    "0300090000030007": "filament extrusion glitch, auto-recovering",

    # --- Heatbed force sensors (0300_000A / 0300_000B) ---
    "03000A0000010002": "heatbed force sensor 1 weak signal",
    "03000A0000010005": "force sensor 1 sees stuck heatbed",
    "03000B0000010002": "heatbed force sensor 2 weak signal",

    # --- Build plate / Z homing (0300_000D) ---
    "03000D0000010002": "heatbed homing failed, too much vibration",
    "03000D0000010003": "build plate not placed properly",
    "03000D0000010004": "build plate not placed properly",
    "03000D0000010005": "build plate not placed properly",
    "03000D000001000B": "Z axis motor stuck, check for obstruction",
    "03000D000001000C": "heatbed leveling data abnormal",

    # --- Resonance / belts (0300_0010 / 0300_0011) ---
    "0300100000020001": "X axis timing belt may be loose",
    "0300110000020001": "Y axis timing belt may be loose",

    # --- Toolhead front cover (0300_0012) ---
    "0300120000020001": "toolhead front cover fell off",

    # --- Hotend fan slow (0300_0017) ---
    "0300170000020002": "hotend cooling fan slow, needs cleaning",

    # --- Toolhead / nozzle install (0300_0018) ---
    "0300180000010005": "Z axis stuck during movement",
    "0300180000010006": "heatbed leveling data abnormal",
    "0300180000010008": "nozzle hitting heatbed, residue stuck",
    "030018000001000B": "nozzle not installed properly",
    "030018000001000D": "nozzle clump calibration: too much force",
    "030018000001000E": "nozzle clump calibration missed metal sheet",

    # --- Nozzle clog (0300_001A) ---
    "03001A0000020001": "nozzle covered in filament or plate crooked",
    "03001A0000020002": "nozzle is clogged",

    # --- XY homing (0300_0020) ---
    "0300200000010002": "Y axis homing failed, heatbed may be stuck",
    "0300200000010003": "X axis homing failed, belt loose",
    "0300200000010004": "Y axis homing failed, belt loose",

    # --- Z slider (0300_0025 / 0300_0026) ---
    "0300250000010005": "Z axis stuck, check Z slider",
    "0300260000010005": "Z axis stuck, check Z slider",
    "030025000001000B": "right nozzle not installed properly",
    "030026000001000B": "left nozzle not installed properly",

    # --- Cutter Z homing (0300_0028) ---
    "0300280000010005": "cutter mode Z homing failed",
    "0300280000010008": "Z homing failed, blade holder stuck",

    # --- Air door / damper (0300_002B) ---
    "03002B0000020001": "air door calibration failed",

    # --- High-temp bed level (0300_002D) ---
    "03002D0000010006": "heatbed leveling failed, foreign object?",

    # --- Chamber fans (0300_0033 / 0300_0036) ---
    "0300330000010001": "chamber exhaust fan stopped",
    "0300330000020002": "chamber exhaust fan slow, needs cleaning",
    "0300360000010001": "chamber circulation fan stopped",
    "0300360000020002": "chamber circulation fan slow",

    # --- Part cooling fan, alt (0300_0031) ---
    "0300310000010001": "part cooling fan stopped",

    # --- Serial bus (0300_0040) ---
    "0300400000020001": "serial port data transmission abnormal",

    # --- Firmware/system codes from Bambu standard ABL/AutoLevel ---
    "0300400000010002": "auto bed leveling failed",
    "0300400000010005": "hotend cooling fan abnormal",
    "0300400000010006": "nozzle is clogged",
    "0300400000010008": "AMS failed to change filament",
    "0300400000010009": "XY axis homing failed",
    "030040000001000A": "resonance calibration failed",
    "030040000001000C": "task was cancelled",
    "030040000001000D": "resume after power loss failed",
    "030040000001000E": "motor self-check failed",
    "030040000001000F": "power supply voltage mismatch",
    "0300400000010010": "nozzle offset calibration failed",
    "0300400000010011": "flow dynamics calibration failed",

    # --- Front door (0300_0096) ---
    "0300960000010001": "front door is open, print paused",
    "0300960000010002": "front door upper hall sensor fault",
    "0300960000010003": "front door lower hall sensor fault",

    # --- Chamber cool warning (0300_0094) ---
    "0300940000030001": "chamber cooling slow, open door to help",

    # --- Fire extinguisher (H2D) (0300_00D4 / D6) ---
    "0300D40000010002": "fire extinguisher sensor fault",
    "0300D60000010007": "fire extinguisher motor jammed",

    # --- Module faults (0500_0003) ---
    "0500030000010001": "MC module fault, restart printer",
    "0500030000010002": "toolhead module fault, restart",
    "0500030000010003": "AMS module fault, restart",
    "0500030000010004": "filament buffer module fault",
    "0500030000010005": "internal service fault, restart",
    "0500030000010006": "system panic, restart",
    "0500030000010008": "system hang, restart",
    "050003000001000B": "screen fault, restart",
    "050003000001000C": "MC motor controller fault",
    "0500030000010024": "too cold, heating up before printing",

    # --- Network / cloud (0500_0002) ---
    "0500020000020001": "no internet, check network",
    "0500020000020002": "device login failed",
    "0500020000020004": "unauthorized user, check account",

    # --- Storage (0500_0001) ---
    "0500010000020001": "media pipeline fault, restart",
    "0500010000020002": "live view camera not connected",
    "0500010000030004": "MicroSD card full",
    "0500010000030005": "MicroSD card is read-only",
    "0500010000030007": "no MicroSD card detected",

    # --- AMS slot tangles (0700_AABB) — AABB encodes unit + slot ---
    "0700100000020002": "filament tangled in AMS slot 1",
    "0700110000020002": "filament tangled in AMS slot 2",
    "0700120000020002": "filament tangled in AMS slot 3",
    "0700130000020002": "filament tangled in AMS slot 4",
    "0700100000010001": "AMS slot 1 motor slipping",
    "0700110000010001": "AMS slot 2 motor slipping",
    "0700120000010001": "AMS slot 3 motor slipping",
    "0700130000010001": "AMS slot 4 motor slipping",

    # --- AMS feed timeout ---
    "0700200000020010": "AMS slot 1 feed timeout",
    "0700210000020010": "AMS slot 2 feed timeout",
    "0700220000020010": "AMS slot 3 feed timeout",
    "0700230000020010": "AMS slot 4 feed timeout",

    # --- AMS RFID ---
    "0700200000010084": "AMS slot 1 RFID read failed",
    "0700210000010084": "AMS slot 2 RFID read failed",
    "0700220000010084": "AMS slot 3 RFID read failed",
    "0700230000010084": "AMS slot 4 RFID read failed",

    # --- AMS buffer overload ---
    "0700600000020001": "AMS slot 1 buffer overloaded, possible tangle",
    "0700610000020001": "AMS slot 2 buffer overloaded, possible tangle",
    "0700620000020001": "AMS slot 3 buffer overloaded, possible tangle",
    "0700630000020001": "AMS slot 4 buffer overloaded, possible tangle",

    # --- AMS assist motor ---
    "0700010000010001": "AMS assist motor slipping",
    "0700010000020002": "AMS assist motor overloaded",

    # --- AMS Lite slot tangles (1200_AABB) ---
    "1200100000020002": "AMS Lite slot 1 motor overloaded",
    "1200110000020002": "AMS Lite slot 2 motor overloaded",
    "1200120000020002": "AMS Lite slot 3 motor overloaded",
    "1200130000020002": "AMS Lite slot 4 motor overloaded",
    "1200800000020001": "AMS Lite slot 1 filament tangled",
    "1201800000020001": "AMS Lite slot 2 filament tangled",
    "1202800000020001": "AMS Lite slot 3 filament tangled",
    "1203800000020001": "AMS Lite slot 4 filament tangled",

    # --- AMS HT slot tangles (1800_AABB) ---
    "1800100000020002": "AMS HT slot 1 motor overloaded",
    "1800110000020002": "AMS HT slot 2 motor overloaded",
    "1800120000020002": "AMS HT slot 3 motor overloaded",
    "1800130000020002": "AMS HT slot 4 motor overloaded",
    "1800600000020001": "AMS HT slot 1 buffer overloaded, tangled",
    "1800610000020001": "AMS HT slot 2 buffer overloaded, tangled",

    # --- External spool (07FE / 07FF) ---
    "07FE200000020002": "no filament detected on external spool",
}


def lookup_phrase(attr: int | None, code: int | None = None) -> str | None:
    """Resolve a Bambu HMS pair to a friendly phrase. Returns None when
    no match — callers fall back to "the printer's reporting an error."

    Accepts a couple of input shapes that surface in our codebase:
      - lookup_phrase(attr, code) — the canonical MQTT push form, two
        32-bit ints concatenated big-endian to 16 hex chars
      - lookup_phrase(attr_only) — when only one number is around
        (older code paths that just stored `attr`); we treat it as the
        full 64-bit value and format directly. Round-trip-safe for
        codes that fit in 32 bits.
    """
    if attr is None:
        return None
    if code is None:
        # Some callers give us a single int — could be 32-bit attr only
        # or a packed 64-bit value. Try the 64-bit form first.
        if attr <= 0xFFFFFFFF:
            return None  # 32 bits alone isn't enough to look up
        key = f"{attr:016X}"
    else:
        key = f"{attr:08X}{code:08X}"
    return HMS_CODES.get(key)
