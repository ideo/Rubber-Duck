// Servo animation for the bambu duck.
//
// Ported (constants + spring physics + idle hop logic) from
// firmware/rubber_duck_s3_ducky/{ServoControl.ino,Easing.ino} so the head
// animation feel is identical to the existing ducks.
//
// Two layers compose into the final servo angle:
//   1. ambientCurrentOffset — subconscious wandering (idle hop clusters,
//      retargets every TTS_RETARGET_MS during speech)
//   2. beakAmplitude        — conscious layer driven by spk audio envelope
//      (only nonzero while the agent is talking)
//
// Final position: SERVO_CENTER + ambientCurrentOffset ± beakAmplitude
#include "servo.h"
#include "config.h"

#include <math.h>
#include <stdlib.h>

#include <driver/gpio.h>
#include <driver/ledc.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "servo";

// LEDC: 50Hz, 14-bit. 500us = 0°, 2400us = 180°. Same numbers as ducky.
#define SERVO_LEDC_FREQ     50
#define SERVO_LEDC_BITS     LEDC_TIMER_14_BIT
#define SERVO_LEDC_TIMER    LEDC_TIMER_0
#define SERVO_LEDC_CHANNEL  LEDC_CHANNEL_7   // high channel to dodge I2S timers
#define SERVO_LEDC_MODE     LEDC_LOW_SPEED_MODE
#define SERVO_PULSE_MIN     410   // 500us
#define SERVO_PULSE_MAX     1966  // 2400us

static volatile bool s_speaking = false;
// Block idle-hop / TTS retarget while a scripted animation (e.g. shake-off)
// is in progress so background motion doesn't fight the choreography.
static volatile bool s_animation_locked = false;

// Audio envelope state — written by spk_task via servo_feed_audio_envelope,
// read by the servo task. A simple peak-decay follower: each chunk we
// take the absolute peak, attack toward it, then decay over time.
static volatile float s_envelope = 0.0f;     // 0..1
static volatile int16_t s_recent_peak = 0;   // unsigned-ish int16 peak

// Animation state
static float ambientCurrentOffset = 0.0f;
static float ambientTargetOffset = 0.0f;
static float ambientVelocity = 0.0f;
static float beakAmplitude = 0.0f;
static int idleClusterRemaining = 0;
static int64_t nextClusterHopMs = 0;
static int64_t nextIdleHopMs = 0;
static int64_t lastTTSRetargetMs = 0;

// Idle taper — see servo_note_interaction (servo.h). Reset to "now" on
// every user-initiated wake; idle phases below ramp the next-hop window
// based on how long since this last fired. Initialized in servo_init
// to "boot is fresh interaction" so the duck wakes up alert.
static int64_t lastInteractionMs = 0;

static int64_t now_ms(void) { return esp_timer_get_time() / 1000; }
static int rand_range(int lo, int hi) { return lo + (rand() % (hi - lo + 1)); }

// Pick the next idle-hop window (min..max ms) based on how long the
// duck has been idle since user interaction. Four phases — alert /
// settling / drowsy / dormant. The first phase mirrors config.h's
// IDLE_HOP_MIN/MAX; later phases are absolute timings tuned by ear
// for "duck has been ignored a while, settle down already." User
// interaction (servo_note_interaction) resets to the alert phase.
static void next_hop_window(int64_t now, int *out_min_ms, int *out_max_ms) {
    int64_t idle = now - lastInteractionMs;
    if (idle < 2LL * 60 * 1000) {
        // Alert (0–2 min): 4–15 s — the original cadence.
        *out_min_ms = IDLE_HOP_MIN_MS;
        *out_max_ms = IDLE_HOP_MAX_MS;
    } else if (idle < 10LL * 60 * 1000) {
        // Settling (2–10 min): 30–60 s.
        *out_min_ms = 30 * 1000;
        *out_max_ms = 60 * 1000;
    } else if (idle < 60LL * 60 * 1000) {
        // Drowsy (10 min – 1 hr): 25 – 60 min between hops.
        *out_min_ms = 25 * 60 * 1000;
        *out_max_ms = 60 * 60 * 1000;
    } else {
        // Dormant (1 hr+): one hop every ~12 hours. Effectively
        // "asleep" — the duck waits to be touched.
        *out_min_ms = 12 * 60 * 60 * 1000;
        *out_max_ms = 12 * 60 * 60 * 1000;
    }
}
static float clampf(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static void servo_write_angle(int angle) {
    if (angle < 0) angle = 0;
    if (angle > 180) angle = 180;
    uint32_t duty = SERVO_PULSE_MIN +
                    (uint32_t)((SERVO_PULSE_MAX - SERVO_PULSE_MIN) * angle) / 180;
    ledc_set_duty(SERVO_LEDC_MODE, SERVO_LEDC_CHANNEL, duty);
    ledc_update_duty(SERVO_LEDC_MODE, SERVO_LEDC_CHANNEL);
}

static void update_animation(void) {
    int64_t now = now_ms();

    // Scripted-animation lock: skip all autonomous target changes. The lerp
    // toward ambientTargetOffset still runs (so the choreography reaches its
    // pose), but idle hops and TTS retargets stay out of the way.
    if (s_animation_locked) {
        ambientCurrentOffset += (ambientTargetOffset - ambientCurrentOffset) * AMBIENT_LERP_RATE;
        int pos = (int)(SERVO_CENTER + ambientCurrentOffset);
        if (pos < SERVO_MIN) pos = SERVO_MIN;
        if (pos > SERVO_MAX) pos = SERVO_MAX;
        servo_write_angle(pos);
        return;
    }

    // Cluster micro-hop (tight follow-up after main idle hop). Allowed during
    // speech too — fires rarely enough that it just occasionally tilts the
    // head bigger mid-sentence, on top of TTS retargets.
    if (idleClusterRemaining > 0 && now > nextClusterHopMs) {
        float raw = ((float)rand_range(-100, 100) / 100.0f) * IDLE_CLUSTER_DELTA;
        float delta = (raw >= 0) ? fmaxf(raw, IDLE_CLUSTER_MIN_DELTA)
                                 : fminf(raw, -IDLE_CLUSTER_MIN_DELTA);
        ambientTargetOffset = clampf(ambientTargetOffset + delta,
                                     -(IDLE_HOP_RANGE + IDLE_CLUSTER_DELTA),
                                     (IDLE_HOP_RANGE + IDLE_CLUSTER_DELTA));
        ambientVelocity = 0;
        idleClusterRemaining--;
        if (idleClusterRemaining > 0) {
            nextClusterHopMs = now + rand_range(IDLE_CLUSTER_GAP_MIN, IDLE_CLUSTER_GAP_MAX);
        }
    }

    // Top-level idle hop — schedule new cluster (also during speech)
    if (idleClusterRemaining == 0 && now > nextIdleHopMs) {
        int roll = rand_range(0, 99);
        int clusterSize = (roll < 50) ? 1 : (roll < 90) ? 2 : 3;
        ambientTargetOffset = ((float)rand_range(-100, 100) / 100.0f) * IDLE_HOP_RANGE;
        ambientVelocity = 0;
        idleClusterRemaining = clusterSize - 1;
        if (idleClusterRemaining > 0) {
            nextClusterHopMs = now + rand_range(IDLE_CLUSTER_GAP_MIN, IDLE_CLUSTER_GAP_MAX);
        }
        // Tapered window: hop frequency falls off as user idle time
        // grows. Resets the moment the user double-taps / button-presses
        // (servo_note_interaction).
        int hop_min, hop_max;
        next_hop_window(now, &hop_min, &hop_max);
        nextIdleHopMs = now + rand_range(hop_min, hop_max);
    }

    // While speaking: retarget the head every TTS_RETARGET_MS so it looks
    // alive — same trick the ducky firmware uses for TTS.
    if (s_speaking && (now - lastTTSRetargetMs) >= TTS_RETARGET_MS) {
        lastTTSRetargetMs = now;
        ambientTargetOffset = ((float)rand_range(-100, 100) / 100.0f) * TTS_HOP_RANGE;
    }

    // Ambient layer: simple ease toward target.
    ambientCurrentOffset += (ambientTargetOffset - ambientCurrentOffset) * AMBIENT_LERP_RATE;

    // Beak amplitude: envelope follow with attack/release.
    // Sample peak (s_recent_peak) is captured in the audio path; we just
    // smooth it here. ~+ when peak rises fast, ~- otherwise.
    float peak = (float)s_recent_peak / 32768.0f;  // 0..1
    if (s_speaking) {
        float rate = (peak > s_envelope) ? BEAK_ATTACK : BEAK_RELEASE;
        s_envelope = s_envelope + (peak - s_envelope) * rate;
    } else {
        // Bleed envelope to zero when not speaking so beak relaxes.
        s_envelope *= 0.85f;
    }
    s_recent_peak = (int16_t)((float)s_recent_peak * 0.7f);  // peak decays in audio domain

    // Beak amplitude maps envelope to angle (signed: oscillate around center).
    // We do a simple alternating sign by mapping envelope through a slow
    // oscillation so the beak opens-closes-opens instead of one-sided pull.
    static float beak_phase = 0.0f;
    beak_phase += 0.35f;  // ~3Hz at 20ms tick
    beakAmplitude = sinf(beak_phase) * s_envelope * BEAK_RANGE;

    // Compose final angle.
    int pos = (int)(SERVO_CENTER + ambientCurrentOffset + beakAmplitude);
    if (pos < SERVO_MIN) pos = SERVO_MIN;
    if (pos > SERVO_MAX) pos = SERVO_MAX;
    servo_write_angle(pos);
}

static void servo_task(void *arg) {
    while (1) {
        update_animation();
        vTaskDelay(pdMS_TO_TICKS(SERVO_UPDATE_MS));
    }
}

void servo_set_speaking(bool speaking) {
    s_speaking = speaking;
    if (!speaking) {
        // Reset retarget timer so next speech-start retargets immediately.
        lastTTSRetargetMs = 0;
    }
}

void servo_feed_audio_envelope(const int16_t *pcm, size_t samples) {
    int16_t peak = 0;
    for (size_t i = 0; i < samples; i++) {
        int16_t v = pcm[i];
        if (v < 0) v = -v;
        if (v > peak) peak = v;
    }
    if (peak > s_recent_peak) s_recent_peak = peak;
}

void servo_shake_off(void) {
    // Lock out idle hops + TTS retargets so they don't fight the script.
    s_animation_locked = true;
    // Big kick one way, counter-swing the other, small overshoot, settle.
    // Numbers from issue #37; the ambient lerp smooths each step into the
    // next so this looks like a snappy shake instead of three teleports.
    ambientTargetOffset = 50.0f;  vTaskDelay(pdMS_TO_TICKS(80));
    ambientTargetOffset = -30.0f; vTaskDelay(pdMS_TO_TICKS(60));
    ambientTargetOffset = 15.0f;  vTaskDelay(pdMS_TO_TICKS(40));
    ambientTargetOffset = 0.0f;   vTaskDelay(pdMS_TO_TICKS(40));
    s_animation_locked = false;
    // Push the next idle hop out so it doesn't fire immediately on the
    // heels of the shake — gives the duck a beat to "be still" first.
    nextIdleHopMs = now_ms() + IDLE_HOP_MIN_MS;
}

void servo_note_interaction(void) {
    lastInteractionMs = now_ms();
}

esp_err_t servo_init(void) {
    ledc_timer_config_t timer_cfg = {
        .speed_mode = SERVO_LEDC_MODE,
        .duty_resolution = SERVO_LEDC_BITS,
        .timer_num = SERVO_LEDC_TIMER,
        .freq_hz = SERVO_LEDC_FREQ,
        .clk_cfg = LEDC_AUTO_CLK,
    };
    ESP_ERROR_CHECK(ledc_timer_config(&timer_cfg));

    ledc_channel_config_t ch_cfg = {
        .gpio_num = SERVO_PIN,
        .speed_mode = SERVO_LEDC_MODE,
        .channel = SERVO_LEDC_CHANNEL,
        .timer_sel = SERVO_LEDC_TIMER,
        .duty = 0,
        .hpoint = 0,
        .intr_type = LEDC_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(ledc_channel_config(&ch_cfg));

    servo_write_angle(SERVO_CENTER);
    // Hold dead-center through the entire boot arc — boot bend, wifi
    // connect (up to 20s), wizard handshake, the "I'm connected" /
    // "All set" spoken confirmations. Original Teensy duck did the
    // same ("dead level" period). Without this the head was fidgeting
    // mid-boot, which read as agitation rather than the intended
    // "powering up" gravitas. 20s covers the worst-case wifi-connect
    // timeout; idle hops resume after.
    nextIdleHopMs = now_ms() + 20000;
    // Treat power-on as a fresh interaction so the duck starts in
    // the "alert" hop phase. From there it tapers down by itself
    // unless the user double-taps / button-presses to wake it back up.
    lastInteractionMs = now_ms();

    xTaskCreate(servo_task, "servo", 4096, NULL, 3, NULL);
    ESP_LOGI(TAG, "servo init on GPIO%d (LEDC ch%d)", SERVO_PIN, SERVO_LEDC_CHANNEL);
    return ESP_OK;
}
