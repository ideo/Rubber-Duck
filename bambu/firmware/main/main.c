#include "agent.h"
#include "audio.h"
#include "config.h"
#include "provision.h"
#include "servo.h"
#include "wake.h"
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

// Note: wait_for_button_press() removed. wake.c now owns both button polling
// and tap-on-shell detection behind a single wake_wait_for_trigger() entry.

void app_main(void) {
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    led_init();
    ESP_ERROR_CHECK(audio_init());
    ESP_ERROR_CHECK(servo_init());
    // wake_init() is deferred until AFTER the boot+wifi chirps so the tap
    // detector isn't armed during sounds the duck makes to itself.

    // (Mic-to-serial dump removed — three independent code reviews confirmed
    // the base64-over-UART path overflowed the 115200-baud TX ring at 45 KB/s,
    // producing the "grain sampler" reorder artifact. Future diagnostics
    // should stream over WebSocket to a Mac listener instead.)

    // Boot chirp: low → mid. "I'm awake."
    led_on();
    audio_chirp(500, 80);
    audio_chirp(800, 80);
    led_off();

    // Try WiFi only if creds exist. No auto-entry into SoftAP — the user
    // owns that decision via a button press. Keeps the duck from
    // broadcasting an AP unprompted and keeps the boot quiet.
    bool wifi_connected = false;
    if (wifi_has_creds()) {
        ESP_LOGI(TAG, "connecting to wifi...");
        if (wifi_connect_blocking(20000) == ESP_OK) {
            wifi_connected = true;
            audio_chirp_up();
            led_on();
            vTaskDelay(pdMS_TO_TICKS(500));
            led_off();
            // Long-lived notification channel — relay pushes printer events
            // here, the task triggers a session with event+subtask params.
            //
            // Bambu cloud login is NOT attempted here. By the time we reach
            // this branch, either (a) the relay already has tokens.json from
            // a previous onboarding and is in cloud mode, or (b) the user
            // hasn't done Bambu setup yet and the duck just runs in LAN
            // mode. Initial Bambu setup happens during the APSTA captive
            // portal flow in provision.c — that's the only place chip-side
            // creds touch the relay.
            notify_task_start();
        } else {
            ESP_LOGE(TAG, "wifi creds present but connect failed");
            audio_chirp_down();
            // Fall through to no-wifi idle. Long-press will wipe creds + reboot
            // for a clean re-onboard; short press / tap will enter SoftAP.
        }
    } else {
        ESP_LOGI(TAG, "no wifi creds — press button or tap to set up");
        // "I need help" chirp: low-low-mid, distinct from the happy
        // chirp_up that means "connected and ready."
        audio_chirp(450, 100);
        audio_chirp(450, 100);
        audio_chirp(700, 150);
    }

    // Wake monitor armed regardless of WiFi state — needed for both:
    //   - WiFi-up: tap / button → conversation
    //   - No WiFi: tap / button → enter SoftAP wizard
    ESP_ERROR_CHECK(wake_init());

    while (1) {
        if (wifi_connected) {
            ESP_LOGI(TAG, "idle — press / tap to talk; long-press to re-onboard WiFi");
        } else {
            ESP_LOGI(TAG, "no wifi — press or tap to enter setup mode");
        }
        wake_trigger_t trigger = wake_wait_for_trigger();
        led_on();
        wake_quiet_for_ms(1500);  // suppress tap detector through chirps + setup

        // Routing matrix:
        //   no wifi + any wake     → SoftAP wizard
        //   wifi up + long press   → wipe creds + reboot (clean re-onboard)
        //   wifi up + short / tap  → conversation
        bool need_provision = !wifi_connected || (trigger == WAKE_LONG_PRESS);
        if (need_provision) {
            if (wifi_connected) {
                // Long-press while connected: clear all setup state and reboot.
                // Next boot sees no creds → no-wifi idle → next press enters
                // wizard with a fresh radio init. We wipe BOTH wifi and bambu
                // creds so the re-onboard wizard starts fully clean — partial
                // state would be confusing ("why is it asking for WiFi but
                // remembered my old Bambu account?").
                ESP_LOGI(TAG, "long-press: clearing wifi+bambu creds and restarting");
                audio_chirp(700, 100);
                audio_chirp(500, 100);
                audio_chirp(300, 200);
                wifi_clear_creds();
                bambu_clear_creds();
                vTaskDelay(pdMS_TO_TICKS(800));  // let chirps finish
                esp_restart();
            }
            // No wifi: enter the APSTA wizard now. It blocks until the
            // user has finished onboarding (WiFi connected + optionally
            // Bambu signed in). Returns ESP_OK with WiFi STA up and
            // notify_task running. We then drop into the normal idle
            // loop without needing to reboot.
            ESP_LOGI(TAG, "entering APSTA onboarding wizard");
            audio_chirp(700, 100);
            audio_chirp(900, 100);
            audio_chirp(1100, 150);
            esp_err_t err = wifi_provision_run();
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "provisioning failed: %s", esp_err_to_name(err));
                audio_chirp_down();
                vTaskDelay(pdMS_TO_TICKS(2000));
                continue;
            }
            // Wizard succeeded. STA is connected, notify_task is running,
            // Bambu may be set up. Mark wifi_connected and chirp success.
            wifi_connected = true;
            audio_chirp_up();
            ESP_LOGI(TAG, "onboarding complete; back to normal idle");
            continue;
        }

        // Conversation flow.
        if (trigger == WAKE_TAP) {
            ESP_LOGI(TAG, "tap detected — shaking it off");
            servo_shake_off();
        } else {
            audio_chirp(900, 60);  // "heard the button"
        }

        ESP_LOGI(TAG, "starting relay session");
        audio_chirp_up();
        // Path C: relay holds the ElevenAgents WS upstream; duck speaks raw
        // binary PCM to it. No signed URL fetch needed on the chip.
        agent_run_session(NULL, NULL);
        ESP_LOGI(TAG, "session ended");
        audio_chirp(600, 100);
        led_off();
        // Speaker DMA + amp ring keep producing audio for ~1s after the
        // session closes (peaks ~19k seen in idle-peak diagnostics). Silence
        // the tap detector through that window so a phantom doesn't fire.
        wake_quiet_for_ms(800);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
