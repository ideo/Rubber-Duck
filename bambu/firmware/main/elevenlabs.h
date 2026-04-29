#pragma once
#include <esp_err.h>
#include <stddef.h>

// Fetches a signed wss:// URL for the configured agent. Reads the API key
// from NVS (namespace="duck", key="el_api_key"). Result is written into
// `out_url` (must be at least 512 bytes). Returns ESP_OK on success.
esp_err_t elevenlabs_get_signed_url(char *out_url, size_t out_url_len);
