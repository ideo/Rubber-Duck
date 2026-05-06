#pragma once
#include <esp_err.h>

// Wake-source enum returned by wake_wait_for_trigger.
typedef enum {
    WAKE_BUTTON     = 0,  // physical S3 button — short press
    WAKE_TAP        = 1,  // tap-on-shell transient detected on the mic
    WAKE_LONG_PRESS = 2,  // physical S3 button held >= WAKE_LONG_PRESS_MS
                          //   main.c handles this by setting an NVS
                          //   "reprov" flag and rebooting into SoftAP
                          //   onboarding mode (re-do WiFi setup).
} wake_trigger_t;

// Hold duration that turns a button press into WAKE_LONG_PRESS instead of
// WAKE_BUTTON. ~3 seconds is the standard "you really mean it" hold time
// across consumer electronics (factory reset, paired-mode entry).
#define WAKE_LONG_PRESS_MS 3000

// Spawn the tap-monitor task and configure the button GPIO. Call once at
// boot, AFTER audio_init() so the I2S RX channel exists. Internally:
//   - Allocates a binary semaphore the tap-monitor task signals on detect.
//   - Configures BUTTON_PIN as input + pull-up (active-low to GND).
//   - Spawns a long-lived task that polls the mic when no session is
//     running, scans for a sharp amplitude transient, and signals the
//     semaphore when one fires.
esp_err_t wake_init(void);

// Block until either the user presses the button OR the tap-monitor
// detects a tap. Returns which one fired. Polls at ~50ms cadence so
// neither path adds meaningful latency. Safe to call repeatedly from
// the same task; idempotent.
wake_trigger_t wake_wait_for_trigger(void);

// Suppress tap detection for the next `ms` milliseconds. Call this around
// servo movements (especially the shake-off animation) — motor whine and
// enclosure resonance through the mic otherwise registers as a "tap" and
// would re-trigger the wake immediately after the previous one.
void wake_quiet_for_ms(int ms);
