// Tap-to-wake: detect a sharp amplitude transient on the mic and treat it
// like a button press. Pairs with a comedic servo "shake-off" animation
// kicked from main.c on tap. See issues #37 (single-tap origin) + #40
// (double-tap promotion).
//
// Detection algorithm:
//   1. Read mic frames continuously when no session is running.
//   2. For each frame, split into two halves (10ms @ 16kHz = 160 samples).
//   3. Compute peak abs amplitude per half.
//   4. Raw tap = (peak2 > TAP_PEAK_MIN) AND (peak2 - peak1 > TAP_SLOPE_MIN).
//   5. Skip while agent is speaking (its own consonants would self-trigger).
//   6. Short cooldown (~200ms) after each raw detection so one physical
//      tap's decay doesn't re-register as a second tap.
//   7. **Wake gesture = TWO raw taps within DOUBLE_TAP_WINDOW_MS.** Single
//      taps are dropped silently. Music, drum hits, dropped objects can
//      cleanly produce one transient — they don't reliably produce two
//      with the right timing — so this is the false-positive moat.
//
// Why double-tap and not single: real-world ambient sources (music with
// percussion, kitchen sounds, slammed doors) routinely cleared the
// single-tap thresholds. Demanding two distinct taps within ~500ms is a
// gesture humans can do trivially but ambient sound rarely produces. The
// physical button remains the reliable single-event path.
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
//
// Asymmetric EMA — see TAP_FLOOR_ALPHA_{RISE,FALL}. Originally a single
// alpha=0.02; that crashed during brief music lulls (floor falls 1300→70
// in ~half a second of quiet → next drum hit looks like a tap against
// the now-low floor → false trigger). Asymmetric keeps the floor up when
// the room is intermittently loud.
#define TAP_PEAK_MIN          5000   // absolute amplitude backstop.
                                     // History: 3000 → 5000 → 2500 → 10000
                                     // → 5000. The 10000 setting required
                                     // tapping HARD enough to risk damaging
                                     // the duck's enclosure / mic mount;
                                     // since #40 promoted the gesture to
                                     // double-tap (false-positive moat
                                     // moved to the rhythm requirement),
                                     // we can drop the per-tap loudness
                                     // bar back down so the 2nd tap of a
                                     // pair doesn't have to be the same
                                     // hammer-strike as the 1st. Slope +
                                     // adaptive-floor checks still gate
                                     // out music / hum / speech on top.
#define TAP_SLOPE_MIN         1000   // peak2 - peak1 minimum. Lowered
                                     // alongside TAP_PEAK_MIN so a softer
                                     // 2nd tap with a slightly less sharp
                                     // onset still clears.
#define TAP_FLOOR_MULT        5      // peak2 must exceed N × adaptive floor
#define TAP_FLOOR_ALPHA_RISE  0.1f   // floor rises fast: room got louder
#define TAP_FLOOR_ALPHA_FALL  0.005f // floor falls slow: brief quiet doesn't
                                     // reset the room's "loud" reading

// Cooldown debounces a single physical tap's decay tail (impact rings
// through enclosure for ~100ms). Must be SHORTER than the double-tap
// window so a legitimate 2nd tap doesn't get swallowed. Originally
// 1000ms back when a single tap was the wake gesture — that was fine
// for "don't double-fire one tap" but blocks the double-tap path.
// 80ms admits fast knock-knock rhythms; PEAK_MIN + slope gating
// prevents a single tap's decay from re-firing inside that window.
#define TAP_COOLDOWN_MS       80

// Inter-tap window for the double-tap gesture. A second raw tap must
// land within this window of the first (after the cooldown) or the
// sequence resets. 750ms is forgiving for casual users while keeping
// the false-positive moat (ambient noise can't reliably produce two
// distinct slope-clearing impacts in under 750ms with the 5x adaptive
// floor in front).
#define DOUBLE_TAP_WINDOW_MS  750

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
    // Double-tap accumulator: timestamp of the first raw tap in the
    // current candidate sequence. 0 means "no sequence in progress."
    // The second raw tap fires the public signal; otherwise the
    // sequence resets when the window expires.
    int64_t first_tap_ms = 0;

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
        //
        // Asymmetric: when peak1 > floor (room got louder), rise fast.
        // When peak1 < floor (room got quieter), fall slow. Without this,
        // music with rhythmic gaps crashes the floor between beats and
        // the next beat trips the tap detector.
        int64_t now = now_ms();
        bool in_cooldown = now < cooldown_until;
        if (!in_cooldown && peak1 < ambient_floor * TAP_FLOOR_MULT) {
            float delta = (float)peak1 - ambient_floor;
            float alpha = (delta > 0) ? TAP_FLOOR_ALPHA_RISE : TAP_FLOOR_ALPHA_FALL;
            ambient_floor += alpha * delta;
            if (ambient_floor < 1.0f) ambient_floor = 1.0f;  // never zero
        }

        // Track diagnostics for periodic log line. Demoted to DEBUG —
        // every 10s of idle was producing a noisy "peak window:..." at
        // INFO that the operator doesn't want to read. The actual TAP
        // DETECTED line below stays at INFO since that's the event
        // worth seeing. Bring back INFO with `idf.py menuconfig` log
        // level if you're chasing tap-sensitivity tuning.
        if (peak2 > diag_max_peak) diag_max_peak = peak2;
        if (slope > diag_max_slope) diag_max_slope = slope;
        if (now >= diag_next_log_ms) {
            if (diag_max_peak >= DIAG_LOG_PEAK_FLOOR) {
                ESP_LOGD(TAG, "peak window: max_peak=%d max_slope=%d floor=%.0f",
                         diag_max_peak, diag_max_slope, ambient_floor);
            }
            diag_max_peak = 0;
            diag_max_slope = 0;
            diag_next_log_ms = now + DIAG_LOG_INTERVAL_MS;
        }

        // Raw tap = (peak2 above absolute backstop) AND (peak2 N× above
        // adaptive floor) AND (slope clears its threshold) AND (out of
        // cooldown). Each raw tap is a candidate, not yet a wake event —
        // the double-tap accumulator below decides whether to signal.
        int dynamic_threshold = (int)(ambient_floor * TAP_FLOOR_MULT);
        bool raw_tap = peak2 >= TAP_PEAK_MIN &&
                       peak2 >= dynamic_threshold &&
                       slope >= TAP_SLOPE_MIN &&
                       !in_cooldown;
        if (raw_tap) {
            cooldown_until = now + TAP_COOLDOWN_MS;
            // Stale-check: if a prior 1st tap is sitting on the books
            // past the window, treat THIS tap as the new 1st of a fresh
            // sequence rather than the 2nd of an expired one.
            if (first_tap_ms != 0 &&
                (now - first_tap_ms) > DOUBLE_TAP_WINDOW_MS) {
                ESP_LOGD(TAG, "tap window expired (Δ=%lldms) — resetting",
                         now - first_tap_ms);
                first_tap_ms = 0;
            }
            if (first_tap_ms == 0) {
                // First tap of a candidate sequence. Hold; don't emit.
                // Demoted to DEBUG once the gesture's tuned — bring back
                // to INFO via menuconfig if you're chasing tap behavior.
                first_tap_ms = now;
                ESP_LOGD(TAG, "tap 1/2: peak2=%d slope=%d (waiting for 2nd)",
                         peak2, slope);
            } else {
                // Second tap inside the window — wake gesture confirmed.
                int64_t gap = now - first_tap_ms;
                ESP_LOGI(TAG,
                    "DOUBLE-TAP: gap=%lldms peak2=%d slope=%d floor=%.0f",
                    gap, peak2, slope, ambient_floor);
                first_tap_ms = 0;
                xSemaphoreGive(s_tap_signal);
            }
        } else if (first_tap_ms != 0 &&
                   (now - first_tap_ms) > DOUBLE_TAP_WINDOW_MS) {
            // No second tap arrived in time — silently reset so a noisy
            // moment ago doesn't pair with a deliberate tap minutes from
            // now into an accidental wake.
            ESP_LOGD(TAG, "tap window expired without 2nd tap");
            first_tap_ms = 0;
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
            // Time the press. WAKE_LONG_PRESS fires the moment we
            // cross WAKE_LONG_PRESS_MS — caller's chirp gives the
            // user immediate feedback that "yes, you held long
            // enough, you can let go." For a short press we still
            // wait for release so a quick tap doesn't get reported
            // before the user's finger leaves the button.
            int64_t pressed_at = now_ms();
            while (gpio_get_level(BUTTON_PIN) == 0) {
                vTaskDelay(pdMS_TO_TICKS(20));
                if ((now_ms() - pressed_at) >= WAKE_LONG_PRESS_MS) {
                    // Fire NOW. The button may still be held down
                    // when we return, but main.c's wake_quiet_for_ms
                    // suppression and the immediate reboot handle
                    // any stale gpio read cleanly.
                    return WAKE_LONG_PRESS;
                }
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
