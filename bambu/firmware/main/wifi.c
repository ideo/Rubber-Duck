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
