#include "agent.h"
#include "audio.h"
#include "config.h"
#include "servo.h"
#include "wifi.h"

#include <stdio.h>
#include <stdlib.h>

#include <driver/gpio.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <mbedtls/base64.h>
#include <nvs_flash.h>

static const char *TAG = "main";

// XIAO ESP32-S3 user LED on GPIO21 is active-LOW (LOW = on).
static void led_init(void) {
    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << LED_PIN,
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&cfg);
    gpio_set_level(LED_PIN, 1);  // off
}
static inline void led_on(void)  { gpio_set_level(LED_PIN, 0); }
static inline void led_off(void) { gpio_set_level(LED_PIN, 1); }
static void led_blink(int times, int ms) {
    for (int i = 0; i < times; i++) {
        led_on();  vTaskDelay(pdMS_TO_TICKS(ms));
        led_off(); vTaskDelay(pdMS_TO_TICKS(ms));
    }
}

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

    led_init();
    ESP_ERROR_CHECK(audio_init());
    ESP_ERROR_CHECK(servo_init());

    // (Mic-to-serial dump removed — three independent code reviews confirmed
    // the base64-over-UART path overflowed the 115200-baud TX ring at 45 KB/s,
    // producing the "grain sampler" reorder artifact. Future diagnostics
    // should stream over WebSocket to a Mac listener instead.)

    // Boot chirp: low → mid. "I'm awake."
    led_on();
    audio_chirp(500, 80);
    audio_chirp(800, 80);
    led_off();

    ESP_LOGI(TAG, "connecting to wifi (LED slow-blink while trying)...");
    // Slow blink during WiFi connect (visual: "trying"). Run in a task so it
    // doesn't block the connect itself.
    bool wifi_ok = (wifi_connect_blocking(20000) == ESP_OK);
    if (!wifi_ok) {
        ESP_LOGE(TAG, "wifi failed; one sad chirp then quiet halt");
        audio_chirp_down();
        // No looping — sit forever with LED on so we know it's stuck.
        led_on();
        while (1) vTaskDelay(pdMS_TO_TICKS(60000));
    }

    // WiFi up: happy chirp + LED solid for a beat.
    audio_chirp_up();
    led_on();
    vTaskDelay(pdMS_TO_TICKS(500));
    led_off();

    while (1) {
        ESP_LOGI(TAG, "press the button to start a conversation");
        wait_for_button_press();
        led_on();
        audio_chirp(900, 60);  // "heard the button"
        ESP_LOGI(TAG, "starting relay session");
        audio_chirp_up();
        // Path C: relay holds the ElevenAgents WS upstream; duck speaks raw
        // binary PCM to it. No signed URL fetch needed on the chip.
        agent_run_session(NULL);
        ESP_LOGI(TAG, "session ended");
        audio_chirp(600, 100);
        led_off();
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
