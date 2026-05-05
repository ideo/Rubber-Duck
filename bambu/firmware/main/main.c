#include "agent.h"
#include "audio.h"
#include "config.h"
#include "phrases.h"
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

    // Boot bend: low "wuh" — single note bending up a fifth. Reads
    // more like a duck and less like a beeper. Boot/connect cues
    // share this lower register so the whole "powering on" arc
    // reads as one continuous moment — wizard / setup-mode chirps
    // stay in the higher register to be clearly distinct.
    led_on();
    audio_chirp_bend(280, 380, 180);
    led_off();

    // Soft-reonboard hand-off: a previous boot's long-press set the
    // provision_pending flag and rebooted. Honor it now — skip the
    // normal "connect to saved WiFi" path and force entry into the
    // wizard regardless of NVS contents. The wizard's form lets the
    // user update WiFi/Bambu/ElevenLabs without first wiping anything.
    bool force_provision = provision_pending_take();
    if (force_provision) {
        ESP_LOGI(TAG, "provision_pending flag was set — entering wizard fresh");
    }

    // Try WiFi only if creds exist AND we aren't being forced into the
    // wizard. No auto-entry into SoftAP — the user owns that decision
    // via a button press. Keeps the duck from broadcasting an AP
    // unprompted and keeps the boot quiet.
    bool wifi_connected = false;
    if (!force_provision && wifi_has_creds()) {
        ESP_LOGI(TAG, "connecting to wifi...");
        if (wifi_connect_blocking(20000) == ESP_OK) {
            wifi_connected = true;
            // Connect bend: rises a touch higher than the boot bend,
            // staying in the boot's low register so the two read as
            // a sequence ("waking up" → "got there") rather than two
            // unrelated cues. Not the bright high chirp_up that
            // elsewhere means "wizard succeeded".
            led_on();
            audio_chirp_bend(320, 520, 200);
            // Half-second beat before the spoken line so the chirp
            // tail and amp settle, and the speech reads as a
            // separate thought rather than colliding with the chirp.
            vTaskDelay(pdMS_TO_TICKS(500));
            // Spoken confirmation ("I'm connected!"). Static phrase
            // because there's no agent yet at this point and no
            // printer-name context to weave in. No-op if phrases
            // haven't been generated.
            phrase_play(PHRASE_WIFI_CONNECTED);
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
            // Chip-internal failure → uh-oh (concerned, randomized) so
            // it's distinguishable from the neutral chirp_down hangup.
            audio_chirp_uh_oh();
            // Fall through to no-wifi idle. Long-press will wipe creds + reboot
            // for a clean re-onboard; short press / tap will enter SoftAP.
        }
    } else if (force_provision) {
        // Long-press → soft re-onboard. NVS has WiFi + Bambu binding
        // intact; we just chose not to connect because the wizard is
        // about to run anyway. "Settings mode" bend — rising fifth in
        // the mid register, distinct from the boot/connect bends
        // below and from the "I need help" descending bend.
        ESP_LOGI(TAG, "settings mode — entering wizard with current creds preserved");
        audio_chirp_bend(380, 580, 220);
    } else {
        ESP_LOGI(TAG, "no wifi creds — press button or tap to set up");
        // "I need help" bend: descending — sad/inquisitive tone vs
        // the happy ascending boot/connect bends. Followed by the
        // spoken hint that tells the user what to physically do.
        // Phrase no-ops if phrases haven't been generated yet.
        audio_chirp_bend(450, 280, 280);
        phrase_play(PHRASE_TAP_TO_START);
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
        wake_trigger_t trigger;
        if (force_provision) {
            // Long-press → soft re-onboard already announced user
            // intent. Skip wake_wait_for_trigger so the user doesn't
            // have to tap a SECOND time to actually enter the wizard
            // after the long-press chirp + reboot. Synthesize a
            // button trigger so the routing matrix below routes us
            // into the wizard path. One-shot.
            ESP_LOGI(TAG, "force_provision: skipping wake_wait, going straight to wizard");
            force_provision = false;
            trigger = WAKE_BUTTON;
        } else {
            trigger = wake_wait_for_trigger();
        }
        led_on();
        wake_quiet_for_ms(1500);  // suppress tap detector through chirps + setup

        // Routing matrix:
        //   no wifi + any wake     → SoftAP wizard (in-place, no reboot)
        //   wifi up + long press   → soft re-onboard (preserves creds,
        //                             flag-and-reboot into wizard)
        //   wifi up + short / tap  → conversation
        // For "factory reset" — wipe everything cleanly — use POST /restart
        // from inside the wizard with the "forget WiFi" checkbox active.
        bool need_provision = !wifi_connected || (trigger == WAKE_LONG_PRESS);
        if (need_provision) {
            if (wifi_connected) {
                // Long-press while connected: enter the wizard on next
                // boot WITHOUT wiping anything. The wizard's form lets
                // the user update WiFi / Bambu / ElevenLabs piecemeal,
                // and POST /restart from inside the wizard wipes only
                // what the user explicitly checks.
                //
                // Reboot is the simplest way to get back into APSTA mode
                // without unwinding the netif/event-loop singletons that
                // wifi_provision_run created on first boot. Cheap (~3s)
                // and the user has triggered the action so a brief drop-
                // out is expected.
                ESP_LOGI(TAG, "long-press: setting provision_pending and restarting");
                // "Settings mode" bend — same shape as the
                // force_provision branch up top, since this is the
                // same user intent ("take me to settings").
                audio_chirp_bend(380, 580, 220);
                set_provision_pending(true);
                vTaskDelay(pdMS_TO_TICKS(600));  // let chirp finish
                esp_restart();
            }
            // No wifi: enter the APSTA wizard now. It blocks until the
            // user has finished onboarding (WiFi connected + optionally
            // Bambu signed in). Returns ESP_OK with WiFi STA up and
            // notify_task running. We then drop into the normal idle
            // loop without needing to reboot.
            ESP_LOGI(TAG, "entering APSTA onboarding wizard");
            // Wizard-entry bend: wide upward sweep. Covers more
            // register than the settings-mode bend ("going somewhere
            // bigger") to differentiate the two.
            audio_chirp_bend(320, 680, 320);
            esp_err_t err = wifi_provision_run();
            if (err == ESP_ERR_TIMEOUT) {
                // Wizard timed out (user opened the portal but never
                // submitted, or held by accident and closed the panel).
                // STA is still up via the fast-path's reconnect, so we
                // can drop straight back to idle without rechirping
                // "I'm broken." Just a quiet ack chirp.
                ESP_LOGI(TAG, "wizard timed out without changes — back to idle");
                wifi_connected = wifi_has_creds();
                // Quiet flat ack — no bend, just "yep, back to idle".
                audio_chirp(500, 100);
                vTaskDelay(pdMS_TO_TICKS(500));
                continue;
            }
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "provisioning failed: %s", esp_err_to_name(err));
                // Chip-internal failure → uh-oh (vs neutral chirp_down).
                audio_chirp_uh_oh();
                vTaskDelay(pdMS_TO_TICKS(2000));
                continue;
            }
            // Wizard succeeded. STA is connected, notify_task is running,
            // Bambu may be set up. Mark wifi_connected and chirp success.
            //
            // The "all set, I'm listening for X and Y" spoken confirmation
            // (#34) rides the existing notify pipeline now: relay sees
            // the set_printers ack land, fires a setup_complete notify
            // event, chip wakes for an agent session like any other
            // printer-event notification. No bespoke TTS path on chip.
            wifi_connected = true;
            audio_chirp_up();
            ESP_LOGI(TAG, "onboarding complete; back to normal idle");
            continue;
        }

        // Routing for non-provision wakes:
        //   WAKE_BUTTON (short press) → volume cycle. Audible chirp at
        //     the new level, persisted to NVS. Skip session entirely.
        //   WAKE_TAP (double-tap)     → conversation. Shake-off animation
        //     first, then session.
        // Long-press is handled in the need_provision branch above
        // (re-onboard / settings mode).
        if (trigger == WAKE_BUTTON) {
            ESP_LOGI(TAG, "button: cycling volume");
            audio_cycle_volume();
            led_off();
            // Brief tap-quiet so the announce chirp's amp ring + I2S
            // tail don't trigger the tap detector when the user lets
            // go of the button.
            wake_quiet_for_ms(800);
            continue;
        }

        // Conversation flow (double-tap path).
        ESP_LOGI(TAG, "tap detected — shaking it off");
        servo_shake_off();

        ESP_LOGI(TAG, "starting relay session");
        // Wake bend — same chirp_up the rest of the firmware uses
        // for "ready to talk" moments. Single ascending pitch bend.
        audio_chirp_up();
        // Path C: relay holds the ElevenAgents WS upstream; duck speaks raw
        // binary PCM to it. No signed URL fetch needed on the chip.
        agent_run_session(NULL, NULL);
        ESP_LOGI(TAG, "session ended");
        // Hangup bend — descending counterpart to the wake bend.
        audio_chirp_down();
        led_off();
        // Speaker DMA + amp ring keep producing audio for ~1s after the
        // session closes (peaks ~19k seen in idle-peak diagnostics). Silence
        // the tap detector through that window so a phantom doesn't fire.
        wake_quiet_for_ms(800);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
