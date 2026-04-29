#include "elevenlabs.h"
#include "config.h"

#include <stdio.h>
#include <string.h>

#include <cJSON.h>
#include <esp_crt_bundle.h>
#include <esp_http_client.h>
#include <esp_log.h>
#include <nvs.h>

static const char *TAG = "elevenlabs";

#define RESP_BUF_SZ 1024

typedef struct {
    char *buf;
    size_t len;
    size_t cap;
} resp_t;

static esp_err_t http_event_cb(esp_http_client_event_t *evt) {
    resp_t *r = evt->user_data;
    if (evt->event_id == HTTP_EVENT_ON_DATA && r) {
        size_t want = r->len + evt->data_len + 1;
        if (want > r->cap) return ESP_FAIL;
        memcpy(r->buf + r->len, evt->data, evt->data_len);
        r->len += evt->data_len;
        r->buf[r->len] = '\0';
    }
    return ESP_OK;
}

static esp_err_t load_api_key(char *out, size_t out_len) {
    nvs_handle_t h;
    esp_err_t err = nvs_open("duck", NVS_READONLY, &h);
    if (err != ESP_OK) return err;
    size_t l = out_len;
    err = nvs_get_str(h, "el_api_key", out, &l);
    nvs_close(h);
    return err;
}

esp_err_t elevenlabs_get_signed_url(char *out_url, size_t out_url_len) {
    char api_key[128] = {0};
    esp_err_t err = load_api_key(api_key, sizeof(api_key));
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "no API key in NVS (namespace=duck, key=el_api_key)");
        return err;
    }

    char path[256];
    snprintf(path, sizeof(path), SIGNED_URL_PATH_FMT, BAMBU_DUCK_AGENT_ID);

    char resp_buf[RESP_BUF_SZ] = {0};
    resp_t r = {.buf = resp_buf, .len = 0, .cap = sizeof(resp_buf)};

    esp_http_client_config_t cfg = {
        .host = ELEVENLABS_API_HOST,
        .path = path,
        .transport_type = HTTP_TRANSPORT_OVER_SSL,
        .crt_bundle_attach = esp_crt_bundle_attach,
        .event_handler = http_event_cb,
        .user_data = &r,
        .timeout_ms = 10000,
    };
    esp_http_client_handle_t client = esp_http_client_init(&cfg);
    esp_http_client_set_header(client, "xi-api-key", api_key);

    err = esp_http_client_perform(client);
    int status = esp_http_client_get_status_code(client);
    esp_http_client_cleanup(client);

    if (err != ESP_OK || status != 200) {
        ESP_LOGE(TAG, "signed-url fetch failed: err=%s status=%d body=%s",
                 esp_err_to_name(err), status, resp_buf);
        return ESP_FAIL;
    }

    cJSON *root = cJSON_Parse(resp_buf);
    if (!root) return ESP_FAIL;
    cJSON *url_node = cJSON_GetObjectItem(root, "signed_url");
    err = ESP_FAIL;
    if (cJSON_IsString(url_node) && url_node->valuestring) {
        strncpy(out_url, url_node->valuestring, out_url_len - 1);
        out_url[out_url_len - 1] = '\0';
        err = ESP_OK;
    }
    cJSON_Delete(root);
    return err;
}
