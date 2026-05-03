#include "wifi.h"

#include <string.h>

#include <esp_event.h>
#include <esp_log.h>
#include <esp_netif.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <nvs.h>

static const char *TAG = "wifi";

static EventGroupHandle_t s_event_group;
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

static void wifi_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data) {
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGI(TAG, "disconnected, retrying");
        esp_wifi_connect();
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)data;
        ESP_LOGI(TAG, "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(s_event_group, WIFI_CONNECTED_BIT);
    }
}

static esp_err_t load_creds(char *ssid, size_t ssid_len, char *pass, size_t pass_len) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READONLY, &h);
    if (err != ESP_OK) return err;
    size_t s = ssid_len, p = pass_len;
    err = nvs_get_str(h, "wifi_ssid", ssid, &s);
    if (err == ESP_OK) err = nvs_get_str(h, "wifi_pass", pass, &p);
    nvs_close(h);
    return err;
}

bool wifi_has_creds(void) {
    char ssid[33] = {0};
    char pass[65] = {0};
    return load_creds(ssid, sizeof(ssid), pass, sizeof(pass)) == ESP_OK;
}

esp_err_t wifi_save_creds(const char *ssid, const char *password) {
    if (ssid == NULL || ssid[0] == '\0') return ESP_ERR_INVALID_ARG;
    if (password == NULL) password = "";  // open networks
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READWRITE, &h);
    if (err != ESP_OK) return err;
    err = nvs_set_str(h, "wifi_ssid", ssid);
    if (err == ESP_OK) err = nvs_set_str(h, "wifi_pass", password);
    if (err == ESP_OK) err = nvs_commit(h);
    nvs_close(h);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "wifi creds saved (ssid=%s)", ssid);
    } else {
        ESP_LOGE(TAG, "wifi creds save failed: %s", esp_err_to_name(err));
    }
    return err;
}

esp_err_t wifi_clear_creds(void) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READWRITE, &h);
    if (err != ESP_OK) return err;
    nvs_erase_key(h, "wifi_ssid");
    nvs_erase_key(h, "wifi_pass");
    err = nvs_commit(h);
    nvs_close(h);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "wifi creds erased");
    } else {
        ESP_LOGE(TAG, "wifi creds erase failed: %s", esp_err_to_name(err));
    }
    return err;
}

// ---- Bambu cloud creds ----

bool bambu_has_creds(void) {
    nvs_handle_t h;
    if (nvs_open("duck", NVS_READONLY, &h) != ESP_OK) return false;
    // Pass NULL out_value to query just the value size — returns ESP_OK
    // if the key exists. sz > 1 means the value is non-empty (sz counts
    // the trailing nul).
    size_t sz = 0;
    bool ok = (nvs_get_str(h, "bambu_email", NULL, &sz) == ESP_OK) && sz > 1;
    nvs_close(h);
    return ok;
}

esp_err_t bambu_load_creds(char *email_out, size_t email_cap,
                           char *pw_out, size_t pw_cap,
                           char *user_id_out, size_t user_id_cap) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READONLY, &h);
    if (err != ESP_OK) return err;

    size_t s = email_cap;
    err = nvs_get_str(h, "bambu_email", email_out, &s);
    if (err != ESP_OK) { nvs_close(h); return err; }

    // Password may be absent post-successful-login (we clear it once the
    // relay holds the access_token). Empty string is fine.
    s = pw_cap;
    if (nvs_get_str(h, "bambu_pw", pw_out, &s) != ESP_OK) {
        if (pw_cap > 0) pw_out[0] = '\0';
    }

    // user_id is optional — /preference auto-resolves it.
    s = user_id_cap;
    if (nvs_get_str(h, "bambu_uid", user_id_out, &s) != ESP_OK) {
        if (user_id_cap > 0) user_id_out[0] = '\0';
    }

    nvs_close(h);
    return ESP_OK;
}

esp_err_t bambu_save_creds(const char *email, const char *password,
                           const char *user_id) {
    if (email == NULL || email[0] == '\0') return ESP_ERR_INVALID_ARG;
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READWRITE, &h);
    if (err != ESP_OK) return err;
    err = nvs_set_str(h, "bambu_email", email);
    if (err == ESP_OK) err = nvs_set_str(h, "bambu_pw", password ? password : "");
    if (err == ESP_OK) err = nvs_set_str(h, "bambu_uid", user_id ? user_id : "");
    if (err == ESP_OK) err = nvs_commit(h);
    nvs_close(h);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "bambu creds saved (email=%s, user_id=%s%s)",
                 email, user_id && user_id[0] ? user_id : "(empty/auto)",
                 password && password[0] ? "" : ", no password");
    }
    return err;
}

esp_err_t bambu_clear_password(void) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READWRITE, &h);
    if (err != ESP_OK) return err;
    nvs_set_str(h, "bambu_pw", "");  // intentionally not erase_key — keep slot
    err = nvs_commit(h);
    nvs_close(h);
    if (err == ESP_OK) ESP_LOGI(TAG, "bambu password cleared (relay has token now)");
    return err;
}

esp_err_t bambu_clear_creds(void) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READWRITE, &h);
    if (err != ESP_OK) return err;
    nvs_erase_key(h, "bambu_email");
    nvs_erase_key(h, "bambu_pw");
    nvs_erase_key(h, "bambu_uid");
    err = nvs_commit(h);
    nvs_close(h);
    if (err == ESP_OK) ESP_LOGI(TAG, "bambu creds erased");
    return err;
}

esp_err_t set_provision_pending(bool pending) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READWRITE, &h);
    if (err != ESP_OK) return err;
    if (pending) {
        err = nvs_set_u8(h, "prov_pending", 1);
    } else {
        // Treat absent and 0 the same; erase rather than write 0 so
        // provision_pending_take's read-default returns false cleanly.
        nvs_erase_key(h, "prov_pending");
        err = ESP_OK;
    }
    if (err == ESP_OK) err = nvs_commit(h);
    nvs_close(h);
    return err;
}

bool provision_pending_take(void) {
    nvs_handle_t h;
    if (nvs_open("duck", NVS_READWRITE, &h) != ESP_OK) return false;
    uint8_t v = 0;
    if (nvs_get_u8(h, "prov_pending", &v) != ESP_OK) {
        nvs_close(h);
        return false;
    }
    // Atomic-ish take: clear the flag now so a crash mid-wizard
    // doesn't trap us in a re-provision loop on every boot.
    nvs_erase_key(h, "prov_pending");
    nvs_commit(h);
    nvs_close(h);
    return v != 0;
}

// ---- WiFi connect ----

esp_err_t wifi_connect_blocking(int timeout_ms) {
    char ssid[33] = {0};
    char pass[65] = {0};
    esp_err_t err = load_creds(ssid, sizeof(ssid), pass, sizeof(pass));
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "no wifi creds in NVS (namespace=duck, keys=wifi_ssid/wifi_pass): %s",
                 esp_err_to_name(err));
        return err;
    }

    s_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                                       wifi_event_handler, NULL, NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                                       wifi_event_handler, NULL, NULL));

    wifi_config_t wifi_cfg = {0};
    strncpy((char *)wifi_cfg.sta.ssid, ssid, sizeof(wifi_cfg.sta.ssid));
    strncpy((char *)wifi_cfg.sta.password, pass, sizeof(wifi_cfg.sta.password));
    // Drop the auth threshold so WPA2/WPA3 mixed-mode + WPA3-only APs work.
    wifi_cfg.sta.threshold.authmode = WIFI_AUTH_OPEN;
    // PMF capable but not required — works on both WPA2-only and WPA3 APs.
    // Many home routers in transition mode silently reject clients without PMF.
    wifi_cfg.sta.pmf_cfg.capable = true;
    wifi_cfg.sta.pmf_cfg.required = false;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_cfg));
    ESP_ERROR_CHECK(esp_wifi_start());
    // CRITICAL for real-time audio over WSS: disable modem sleep. Default
    // (WIFI_PS_MIN_MODEM) buffers TX in DTIM bursts every ~100ms, which
    // produces the "abrupt loudness jumps" and "audio duration mismatch"
    // ElevenLabs reports. Costs ~80mA but mandatory for streaming. URAM
    // does this for the same reason.
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    EventBits_t bits = xEventGroupWaitBits(s_event_group, WIFI_CONNECTED_BIT,
                                           pdFALSE, pdFALSE, pdMS_TO_TICKS(timeout_ms));
    return (bits & WIFI_CONNECTED_BIT) ? ESP_OK : ESP_ERR_TIMEOUT;
}
