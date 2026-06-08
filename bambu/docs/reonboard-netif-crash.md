# Re-onboard crash: duplicate default STA netif

**Status:** RESOLVED — flashed to the ducky PCB (turnkey) and verified. After
moving to a new network the duck now reaches the setup AP, accepts new WiFi,
and connects. No `esp_netif_create_default_wifi_sta` assert, no reboot loop.

> Follow-up (separate bug, found while testing this one): submitting the WiFi
> form can abort in `save_handler` — `esp_wifi_set_config(WIFI_IF_STA)` returns
> `ESP_ERR_WIFI_STATE` ("sta is connecting") under `ESP_ERROR_CHECK`
> (`provision.c:809`) when the wizard's STA is mid-reconnect. Creds are saved
> to NVS just before, so a reboot self-recovers and the duck connects — but it
> crashes to get there. Tracked separately.
**Branch:** `marketing-assistant`
**Affected:** all Bambu duck builds (not marketing-specific; latent on `main` too)

## Symptom

Duck has been onboarded, then moves to a new location with different WiFi.
On boot it can't join the saved network and sits at `no wifi — press or
tap to enter setup mode`. Pressing the button to re-onboard appears to do
nothing — the duck doesn't talk and never brings up its `DuckDuckDuck-XXXX`
setup AP. It silently reboots and lands back at the same prompt, looping.

## Root cause

The button press *is* detected and the wizard *does* start — then the chip
hits a hard assert and resets:

```
provision: starting APSTA onboarding wizard
E esp_netif_lwip: esp_netif_new_api: Failed to configure netif (config or if_key is NULL or duplicate key)
assert failed: esp_netif_create_default_wifi_sta wifi_default.c:422 (netif)
rst:0xc (RTC_SW_CPU_RST)
```

`wifi_provision_run()` assumes a clean network stack and calls
`esp_netif_create_default_wifi_sta()` (`provision.c:1330`). But the boot
path already created that singleton netif (`wifi.c:298`) when it tried the
stored creds. A second default STA netif trips an `abort()` → reboot →
loop.

### Why moving locations triggers it

Boot guard (`main.c:141`):

```c
if (!force_provision && wifi_has_creds()) {
    wifi_connect_blocking(...);   // creates the default STA netif
}
```

- **Fresh duck (no creds):** boot skips this, never makes a STA netif. The
  wizard makes the first one → works. (Why first-time onboarding is fine.)
- **Onboarded duck, new location (creds present, connect fails):** boot
  *does* make the STA netif, fails to connect, then the no-wifi branch runs
  `wifi_provision_run()` **in-place** → duplicate netif → crash.

The "wifi-up + long-press" re-onboard path already dodges this by rebooting
through the `provision_pending` flag (`main.c:286–293`) so the wizard runs
from a clean boot. The **no-wifi** branch (`main.c:295–305`) does not — that
omission is the bug.

## Fix

Route the no-wifi provision case through the same clean-boot reboot **only
when this boot actually brought up the STA stack**. Track that with a
`boot_initialized_sta` flag set when boot enters the `wifi_connect_blocking()`
branch (`main.c`), and gate the reboot on it in the `need_provision` block:

```c
bool boot_initialized_sta = false;
if (!force_provision && wifi_has_creds()) {
    boot_initialized_sta = true;     // boot created the default STA netif
    ... wifi_connect_blocking() ...
}
...
if (need_provision) {
    if (wifi_connected || boot_initialized_sta) {
        // Boot brought up the STA netif; running the wizard in-place would
        // duplicate it and abort. Reboot through provision_pending so the
        // next boot skips STA init and the wizard runs on a clean stack.
        set_provision_pending(true);
        vTaskDelay(pdMS_TO_TICKS(600));
        esp_restart();
    }
    // STA netif was never created this boot → safe to run wizard in-place.
}
```

### Why not `wifi_has_creds()` (a wrong first attempt)

The first fix gated on `wifi_has_creds()`. That **caused an infinite reboot
loop**: after the `provision_pending` reboot, `force_provision` makes boot
skip the connect (so no STA netif), but the creds are *still in NVS*, so
`wifi_has_creds()` stays true → the synthesized re-onboard press hits the
reboot branch again → reboot forever, never opening the AP.

`boot_initialized_sta` is the correct signal: it is **false** on the clean
`force_provision` boot (we skipped the connect), so that boot falls through to
the safe in-place wizard. It is **true** only when boot genuinely created the
STA netif (creds present, not force_provision), which is exactly when the
in-place wizard would double-create and crash.

## Immediate workarounds (no firmware change)

1. **Recreate the old network** — phone hotspot with the *old* SSID +
   password. Duck connects → long-press → it reboots into a clean wizard →
   enter the new WiFi.
2. **Erase + reflash** via the web flasher (clears NVS creds → boot skips STA
   init → wizard works). See `bambu/docs/FLASHING.md`.

## Test plan

1. Flash the fix to a duck that has saved creds for an unreachable network.
2. Boot → confirm `wifi creds present but connect failed`.
3. Press the button → expect: settings-mode chirp, `set provision_pending`,
   reboot, then `provision_pending flag was set — entering wizard fresh` and
   the `DuckDuckDuck-XXXX` AP comes up (no `esp_netif_create_default_wifi_sta`
   assert).
4. Join the AP, submit new creds → duck connects to the new network.
5. Regression: fresh duck (erased NVS) still onboards in-place without a
   reboot.
