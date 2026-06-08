<!--
Ready-to-paste GitHub issue for github.com/ideo/Rubber-Duck.
Title: Bambu duck: reboot loop when re-onboarding after a failed WiFi connect (duplicate default STA netif)
Labels: bug, firmware, bambu
-->

## Summary
An already-onboarded Bambu duck that moves to a new WiFi location gets stuck
in a reboot loop. It can't join the saved (now-stale) network, and pressing
the button to re-onboard silently crashes the chip instead of opening the
setup AP.

## Affected
- All Bambu duck builds (ducky / xiao / turnkey) — not marketing-specific.
  Latent on `main`; surfaced on the `marketing-assistant` branch.
- Hardware confirmed: ducky PCB, ESP32-S3 WROOM-1, MAC dcb4d925ac89.

## Steps to reproduce
1. Onboard a duck to network A.
2. Move it to a location where network A is unreachable (or change creds).
3. Boot → it fails to join and sits at `no wifi — press or tap to enter setup mode`.
4. Press the button to re-onboard.

**Expected:** duck enters the APSTA wizard and broadcasts `DuckDuckDuck-XXXX`.
**Actual:** chip asserts and reboots; loops forever, never opening the AP.

## Root cause
The button press is detected and the wizard starts, then aborts:

```
provision: starting APSTA onboarding wizard
E esp_netif_lwip: esp_netif_new_api: Failed to configure netif (config or if_key is NULL or duplicate key)
assert failed: esp_netif_create_default_wifi_sta wifi_default.c:422 (netif)
rst:0xc (RTC_SW_CPU_RST)
```

`wifi_provision_run()` calls `esp_netif_create_default_wifi_sta()`
(`provision.c:1330`) assuming a clean network stack. But when creds are
present, the boot path already created that singleton netif via
`wifi_connect_blocking()` (`wifi.c:298`). Re-creating the default STA netif
trips an `abort()`.

It only bites when re-onboarding from a "creds present but connect failed"
state — fresh ducks (no creds) skip boot STA init, so the wizard is the first
to create the netif and works fine. That's why first-time onboarding works
and "moved to a new place" doesn't. The wifi-up + long-press path already
dodges this by rebooting through `provision_pending`; the no-wifi path did
not.

## Fix
Broaden the `need_provision` reboot guard in `main.c` from
`if (wifi_connected)` to `if (wifi_connected || wifi_has_creds())` so a
failed-connect re-onboard reboots into a clean-boot wizard (which skips STA
init) instead of running in-place.

- Fix commit: `6628ef2`
- Writeup + test plan: `bambu/docs/reonboard-netif-crash.md`

## Status
Fix committed on `marketing-assistant`. Pending flash + on-device test
(reproduce the loop, confirm `re-onboard: setting provision_pending and
restarting` → clean wizard, no netif assert).
