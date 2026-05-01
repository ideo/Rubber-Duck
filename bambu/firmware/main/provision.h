#pragma once
#include <esp_err.h>

// SoftAP onboarding wizard. Call when wifi_has_creds() is false.
//
// Flow:
//   1. Scan visible APs while still in STA mode (results = the home networks
//      the user can pick from on the form).
//   2. Stop STA, switch to AP-only mode, broadcast "DuckDuckDuck-XXXX" where
//      XXXX is the last 4 hex chars of the WiFi MAC.
//   3. Spin up an HTTP server on 192.168.4.1 (the default SoftAP IP).
//   4. Serve a single HTML page: <select> populated from the scan results +
//      a password input. POST writes creds to NVS via wifi_save_creds.
//   5. On successful save, esp_restart() — the duck boots fresh with creds
//      now in NVS and falls through to the normal wifi_connect_blocking path.
//
// Blocks indefinitely. The function only returns on the failure path (couldn't
// even start the AP); on success it reboots the chip rather than return.
//
// Phase 1 deliberately skips: captive-portal DNS hijack (phones won't auto-
// pop the page — user navigates to the IP manually), multi-network NVS
// (one SSID slot today; #30 tracks the upgrade), and Bambu cloud OAuth
// (#31 will extend this same form to also collect the printer binding).
esp_err_t wifi_provision_run(void);
