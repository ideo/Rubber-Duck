#pragma once
#include <stdbool.h>
#include <esp_err.h>

// Reads SSID + password from NVS namespace "duck", keys "wifi_ssid" / "wifi_pass".
// Blocks until associated and IP acquired (or timeout). If creds are missing
// from NVS, returns ESP_ERR_NVS_NOT_FOUND immediately — the caller (main.c)
// is responsible for routing to the SoftAP onboarding flow in that case.
esp_err_t wifi_connect_blocking(int timeout_ms);

// True if both wifi_ssid and wifi_pass are present in NVS. Pure read, never
// modifies. Caller uses this to choose between wifi_connect_blocking() and
// the SoftAP onboarding wizard at boot.
bool wifi_has_creds(void);

// Persist creds to NVS namespace "duck" (keys wifi_ssid + wifi_pass). Used
// by the SoftAP provisioning flow's POST handler. ssid up to 32 chars,
// password up to 64 chars (WPA2/3 max). Returns ESP_OK on success.
esp_err_t wifi_save_creds(const char *ssid, const char *password);

// Erase WiFi creds from NVS. Used by the long-press "re-onboard" path: wipe
// creds, reboot, boot logic sees no creds, falls into no-WiFi mode where
// the next button press enters the SoftAP wizard.
esp_err_t wifi_clear_creds(void);
