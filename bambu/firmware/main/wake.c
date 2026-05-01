// Tap-to-wake: detect a sharp amplitude transient on the mic and treat it
// like a button press. Pairs with a comedic servo "shake-off" animation
// kicked from main.c on tap. See issue #37.
//
// Detection algorithm (per issue):
//   1. Read mic frames continuously when no session is running.
//   2. For each frame, split into two halves (10ms @ 16kHz = 160 samples).
//   3. Compute peak abs amplitude per half.
//   4. Tap = (peak2 > TAP_PEAK_MIN) AND (peak2 - peak1 > TAP_SLOPE_MIN).
//   5. Skip while agent is speaking (its own consonants would self-trigger).
//   6. Cooldown ~1s after each detection so a single tap doesn't fire twice.
//
// Why a separate file: keeps tap detection out of agent.c (session lifecycle)
// and audio.c (I2S abstraction). Single concern: idle-time mic monitoring.
//
// Future low-power path: replace this polling task with an I2S DMA-complete
// callback (i2s_channel_register_event_callback) that computes peak in the
// ISR and gives the semaphore directly — no userspace task spinning. Or a
// dedicated piezo on the shell + GPIO interrupt, which would let the audio
// path go idle entirely between conversations. Tracked in #37.
#include "wake.h"
#include "agent.h"
#include "audio.h"
#include "config.h"

#include <string.h>

#include <driver/gpio.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>

static const char *TAG = "wake";

// Tap detector tunables.
//
// Floor is adaptive: we EMA-track the "before-tap" half of each frame as
// ambient noise, and require the "after-tap" half to be N× above that
// floor. So a quiet room and a noisy room both work without re-tuning,
// and the absolute floor (TAP_PEAK_MIN) is just a sanity backstop for the
// case where the room is truly silent (floor → ~0 means even tiny noise
// would clear the multiplier).
#define TAP_PEAK_MIN       3000   // absolute amplitude backstop
#define TAP_SLOPE_MIN      1500   // peak2 - peak1 minimum
#define TAP_FLOOR_MULT     5      // peak2 must exceed N × adaptive floor
#define TAP_FLOOR_ALPHA    0.02f  // EMA rate; ~1s adaptation at 50 frames/s
#define TAP_COOLDOWN_MS    1000

// Diagnostic log cadence. Only fires when something noisy actually
// happened (peak > FLOOR), so a quiet duck doesn't spam its own log.
#define DIAG_LOG_INTERVAL_MS 10000
#define DIAG_LOG_PEAK_FLOOR  500

static SemaphoreHandle_t s_tap_signal = NULL;
static volatile int64_t s_servo_quiet_until_ms = 0;

static int64_t now_ms(void) { return esp_timer_get_time() / 1000; }

// Compute peak absolute amplitude over a sample range. Handles negative
// extreme (-32768) by clamping — abs(-32768) overflows int16 otherwise.
static int peak_abs(const int16_t *samples, size_t n) {
    int peak = 0;
    for (size_t i = 0; i < n; i++) {
        int v = samples[i];
        if (v < 0) v = -v;
        if (v > 32767) v = 32767;
        if (v > peak) peak = v;
    }
    return peak;
}

static void tap_monitor_task(void *arg) {
    int16_t buf[AUDIO_FRAME_SAMPLES];
    int64_t cooldown_until = 0;
    float ambient_floor = (float)TAP_PEAK_MIN;  // start at backstop; adapts down
    int diag_max_peak = 0;
    int diag_max_slope = 0;
    int64_t diag_next_log_ms = 0;

    while (1) {
        // ALWAYS yield each iteration — even on early-continue paths.
        // Without this, a sequence of zero-byte reads (DMA empty, timeout,
        // brief contention with mic_task during session boundaries) becomes
        // a tight loop that starves IDLE0 and trips the task watchdog.
        vTaskDelay(pdMS_TO_TICKS(20));

        // Single dumb gate: skip whenever the chip is making noise itself
        // (speaker active = chirp / agent voice / post-amp ringing) OR
        // is in a conversation (mic_task owns the I2S channel) OR a
        // recent servo move could be ringing the enclosure. Each of
        // these has a clear physical reason to suppress detection.
        if (agent_session_active() ||
            audio_speaker_active() ||
            now_ms() < s_servo_quiet_until_ms) {
            continue;
        }

        size_t n = audio_mic_read_raw(buf, AUDIO_FRAME_SAMPLES, 50);
        if (n < AUDIO_FRAME_SAMPLES) {
            continue;  // partial/zero read — try again next tick
        }

        // Slope detection: split 20ms frame into two 10ms halves, compare
        // peaks. A real tap rises from quiet to loud across the boundary.
        int half = (int)n / 2;
        int peak1 = peak_abs(buf, half);
        int peak2 = peak_abs(buf + half, n - half);
        int slope = peak2 - peak1;

        // Adaptive ambient floor: EMA-track peak1 (the "before-tap" half).
        // Only update when peak1 looks like ambient (well below current
        // floor's tap zone) so a sustained loud noise doesn't pollute the
        // estimate. Skip updating during cooldown so the tap's own decay
        // doesn't push the floor up either.
        int64_t now = now_ms();
        bool in_cooldown = now < cooldown_until;
        if (!in_cooldown && peak1 < ambient_floor * TAP_FLOOR_MULT) {
            ambient_floor += TAP_FLOOR_ALPHA * ((float)peak1 - ambient_floor);
            if (ambient_floor < 1.0f) ambient_floor = 1.0f;  // never zero
        }

        // Track diagnostics for periodic log line.
        if (peak2 > diag_max_peak) diag_max_peak = peak2;
        if (slope > diag_max_slope) diag_max_slope = slope;
        if (now >= diag_next_log_ms) {
            if (diag_max_peak >= DIAG_LOG_PEAK_FLOOR) {
                ESP_LOGI(TAG, "peak window: max_peak=%d max_slope=%d floor=%.0f",
                         diag_max_peak, diag_max_slope, ambient_floor);
            }
            diag_max_peak = 0;
            diag_max_slope = 0;
            diag_next_log_ms = now + DIAG_LOG_INTERVAL_MS;
        }

        // Tap = (peak2 above absolute backstop) AND (peak2 N× above adaptive
        // floor) AND (slope clears its threshold) AND (out of cooldown).
        int dynamic_threshold = (int)(ambient_floor * TAP_FLOOR_MULT);
        if (peak2 >= TAP_PEAK_MIN &&
            peak2 >= dynamic_threshold &&
            slope >= TAP_SLOPE_MIN &&
            !in_cooldown) {
            ESP_LOGI(TAG, "TAP DETECTED: peak1=%d peak2=%d slope=%d floor=%.0f",
                     peak1, peak2, slope, ambient_floor);
            cooldown_until = now + TAP_COOLDOWN_MS;
            xSemaphoreGive(s_tap_signal);
        }
    }
}

esp_err_t wake_init(void) {
    if (s_tap_signal == NULL) {
        s_tap_signal = xSemaphoreCreateBinary();
        if (s_tap_signal == NULL) {
            ESP_LOGE(TAG, "tap signal alloc failed");
            return ESP_ERR_NO_MEM;
        }
    }

    // Configure button as input + pull-up (active low).
    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << BUTTON_PIN,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    gpio_config(&cfg);

    xTaskCreate(tap_monitor_task, "tap_mon", 4096, NULL, 4, NULL);
    ESP_LOGI(TAG, "wake init: tap detector + button polling armed");
    return ESP_OK;
}

wake_trigger_t wake_wait_for_trigger(void) {
    // Drain any stale tap signal left over from before this call. Belt and
    // suspenders: even though we suppress detection during chirps and the
    // post-session window, a phantom signaled mid-session could otherwise
    // make the very next call to this function return immediately as if
    // a fresh tap just happened.
    xSemaphoreTake(s_tap_signal, 0);

    while (1) {
        // Button check: active-low, 0 means pressed.
        if (gpio_get_level(BUTTON_PIN) == 0) {
            while (gpio_get_level(BUTTON_PIN) == 0) {
                vTaskDelay(pdMS_TO_TICKS(20));
            }
            return WAKE_BUTTON;
        }
        // Tap check: short timeout doubles as the polling cadence.
        if (xSemaphoreTake(s_tap_signal, pdMS_TO_TICKS(50)) == pdTRUE) {
            return WAKE_TAP;
        }
    }
}

// Suppress detection for `ms`. Used after servo moves to ride out enclosure
// resonance the mic would otherwise hear as a tap. Declared in wake.h.
void wake_quiet_for_ms(int ms) {
    s_servo_quiet_until_ms = now_ms() + ms;
}
