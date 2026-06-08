# Re-onboard crash: duplicate default STA netif

**Status:** fix applied on branch — pending flash + test
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

Route the no-wifi provision case through the same clean-boot reboot whenever
the boot path already initialized the STA stack. In the `need_provision`
block (`main.c:273`), broaden the existing reboot branch:

```c
// was: if (wifi_connected)
if (wifi_connected || wifi_has_creds()) {
    // Boot already brought up the STA netif (creds existed, connect may
    // have failed). Running the wizard in-place would duplicate the
    // default STA netif and abort. Reboot through provision_pending so
    // the wizard starts from a clean boot that skips STA init.
    set_provision_pending(true);
    vTaskDelay(pdMS_TO_TICKS(600));   // let the settings-mode chirp finish
    esp_restart();
}
// No creds ever stored → boot never made a STA netif → safe in-place.
```

After a failed connect, `wifi_has_creds()` is still true (creds are in NVS,
just wrong for this location), so this routes the reported scenario into the
clean-boot wizard instead of the in-place crash. Fresh ducks (no creds) keep
the in-place wizard path unchanged.

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
