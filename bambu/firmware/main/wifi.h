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

// Load WiFi creds from NVS for callers other than wifi_connect_blocking
// (e.g. the captive portal's settings-only fast-path that wants to
// reuse the saved network without doing the whole connect-blocking
// dance again). ESP_OK on success; ssid/pass are NUL-terminated.
esp_err_t wifi_load_creds(char *ssid_out, size_t ssid_cap,
                          char *pw_out, size_t pw_cap);

// Erase WiFi creds from NVS. Used by the long-press "re-onboard" path: wipe
// creds, reboot, boot logic sees no creds, falls into no-WiFi mode where
// the next button press enters the SoftAP wizard.
esp_err_t wifi_clear_creds(void);

// ---- Bambu cloud account creds (collected by SoftAP captive portal,
// used by bambu_login.c to POST /admin/bambu_login on the relay). NVS
// keys live in the same "duck" namespace as the WiFi creds.
//
// 2FA code is deliberately NOT stored — captive portal can't validate
// offline (phone is on duck's AP, no internet), so the 2FA flow lives
// on the duck.local recovery page (#31 iteration C). user_id can be
// empty since /preference auto-resolves it from the access_token.

bool bambu_has_creds(void);

esp_err_t bambu_load_creds(char *email_out, size_t email_cap,
                           char *pw_out, size_t pw_cap,
                           char *user_id_out, size_t user_id_cap);

esp_err_t bambu_save_creds(const char *email, const char *password,
                           const char *user_id);

// Clear ONLY the password field. Called after a successful login —
// the relay holds the access_token now, so the password no longer
// needs to live on the chip. email + user_id stay so the recovery
// page knows who to log back in as if the token expires.
esp_err_t bambu_clear_password(void);

// Wipe all Bambu creds. Pairs with wifi_clear_creds in the long-press
// re-onboard path so re-onboarding starts fresh on both fronts.
esp_err_t bambu_clear_creds(void);

// "Open the captive portal on next boot" flag. Set by the soft long-
// press path so a user can update their config without first wiping
// what's already there: the chip reboots, sees the flag, clears it,
// and enters the wizard regardless of whether NVS still has WiFi.
// Pure NVS bool — call set_provision_pending(true) before
// esp_restart() and provision_pending_take() at the top of main to
// consume + clear it atomically.
esp_err_t set_provision_pending(bool pending);
bool provision_pending_take(void);
