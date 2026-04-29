#include "agent.h"
#include "audio.h"
#include "config.h"
#include "elevenlabs.h"
#include "wifi.h"

#include <driver/gpio.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <nvs_flash.h>

static const char *TAG = "main";

static void wait_for_button_press(void) {
    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << BUTTON_PIN,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&cfg);
    while (gpio_get_level(BUTTON_PIN) == 1) {
        vTaskDelay(pdMS_TO_TICKS(50));
    }
}

void app_main(void) {
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    ESP_ERROR_CHECK(audio_init());

    if (wifi_connect_blocking(20000) != ESP_OK) {
        ESP_LOGE(TAG, "wifi failed; halting");
        return;
    }

    while (1) {
        ESP_LOGI(TAG, "press the button to start a conversation");
        wait_for_button_press();
        ESP_LOGI(TAG, "fetching signed URL");

        char signed_url[512] = {0};
        if (elevenlabs_get_signed_url(signed_url, sizeof(signed_url)) != ESP_OK) {
            ESP_LOGE(TAG, "signed URL fetch failed; retrying in 5s");
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }

        ESP_LOGI(TAG, "starting agent session");
        agent_run_session(signed_url);
        ESP_LOGI(TAG, "session ended");
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
