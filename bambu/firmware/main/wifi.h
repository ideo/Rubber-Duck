#pragma once
#include <esp_err.h>

// Reads SSID + password from NVS namespace "duck", keys "wifi_ssid" / "wifi_pass".
// Blocks until associated and IP acquired (or timeout). Provision via
// `idf.py monitor` console + `nvs_flash_erase` then re-flash, or via the
// flash-time helper described in README.
esp_err_t wifi_connect_blocking(int timeout_ms);
