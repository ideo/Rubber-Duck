#pragma once
#include <esp_err.h>

// APSTA onboarding wizard — see provision.c for the flow narrative.
//
// One continuous browser session: phone joins duck's AP, captive portal
// pops up, user fills WiFi + Bambu creds, page transitions through
// "connecting" → "logging in" → maybe "2FA" → "done." No reboot in the
// middle. Chip never makes outbound HTTPS — credentials forwarded to
// the relay over the existing /ws/notify WebSocket (plain WS, no TLS).
//
// Returns ESP_OK with the chip in STA mode connected to home WiFi and
// the long-lived /ws/notify task running. Returns non-OK only if AP
// startup itself failed (very rare — caller can chirp_down + retry).
esp_err_t wifi_provision_run(void);
