#include "duck_id.h"

#include <stdio.h>
#include <string.h>
#include <esp_mac.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

static const char *TAG = "duck_id";

// 12 hex chars + NUL.
static char s_id[13] = {0};
static SemaphoreHandle_t s_mtx = NULL;

const char *duck_id_get(void) {
    // Lazy mutex init. Called from the boot path before tasks spawn,
    // so first-call contention is unrealistic — but the mutex protects
    // any future race (a tap-to-wake task plus the notify task both
    // calling this on first session).
    if (s_mtx == NULL) {
        s_mtx = xSemaphoreCreateMutex();
    }
    xSemaphoreTake(s_mtx, portMAX_DELAY);
    if (s_id[0] == '\0') {
        uint8_t mac[6] = {0};
        // ESP_MAC_WIFI_SOFTAP matches what provision.c uses for the AP
        // SSID derivation, keeping operator-visible duck names aligned.
        esp_read_mac(mac, ESP_MAC_WIFI_SOFTAP);
        snprintf(s_id, sizeof(s_id), "%02x%02x%02x%02x%02x%02x",
                 mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        ESP_LOGI(TAG, "duck_id=%s", s_id);
    }
    xSemaphoreGive(s_mtx);
    return s_id;
}
