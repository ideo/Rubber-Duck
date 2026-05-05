// Audio for the ducky PCB: single I2S port in full-duplex mode.
// Mic and speaker share BCLK + WS pins; only data pins differ.
// Mirrors firmware/rubber_duck_s3_ducky/AudioStream.ino.
//
//   ICS-43432 (mic):   16-bit data in LEFT slot, MONO RX
//   MAX98357 (speaker): 16-bit STEREO Philips (we duplicate mono → L/R)
#include "audio.h"
#include "config.h"

#include <math.h>
#include <string.h>

#include <driver/i2s_std.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>

static const char *TAG = "audio";

static i2s_chan_handle_t s_tx = NULL;  // speaker
static i2s_chan_handle_t s_rx = NULL;  // mic
static volatile bool s_mic_enabled = false;

// Serializes i2s_channel_read across audio_mic_read (session mic_task) and
// audio_mic_read_raw (tap-monitor task). I2S DMA is single-consumer; without
// this mutex two concurrent reads could split a single DMA descriptor and
// silently corrupt both consumers' frames during the brief overlap when a
// session is starting / ending.
static SemaphoreHandle_t s_mic_lock = NULL;

// Speaker-busy deadline (epoch milliseconds). Extended on every spk_write.
// audio_speaker_active() returns true while now() < this.
//
// The 800ms decay accounts for the MAX98357A amp + speaker cone ringing
// after the last DMA frame lands. Empirical: peak ~19000 in raw int16 was
// observed ~1s after a session-end chirp, with idle returning to peak ~300
// by the 2nd second. 800ms is a safety-margin on real-world decay.
#define AMP_DECAY_MS 800
static volatile int64_t s_spk_active_until_ms = 0;
static inline int64_t audio_now_ms(void) { return esp_timer_get_time() / 1000; }

// DC removal + gain (ported from rubber_duck_s3_ducky/MicCapture.ino).
// ICS-43432 in 16-bit mode is quiet; default gain 8× brings speech up to
// usable amplitude. Calibration in audio_init() may bump up to 64× based
// on noise floor.
static float s_mic_dc = 0.0f;
static float s_mic_gain = 8.0f;
static const float MIC_DC_ALPHA = 0.001f;

// High-shelf biquad to compensate for the muffled enclosure response.
// RBJ cookbook coefficients computed in audio_init() at Fc=2kHz, Q=0.7,
// gain=+6dB. Applied per-sample after DC + gain. Shelf boosts everything
// above ~2kHz by 6dB so consonants come through clearer.
static float s_hs_b0 = 1, s_hs_b1 = 0, s_hs_b2 = 0;
static float s_hs_a1 = 0, s_hs_a2 = 0;
static float s_hs_x1 = 0, s_hs_x2 = 0, s_hs_y1 = 0, s_hs_y2 = 0;

static void compute_high_shelf(float fc, float Q, float gain_db) {
    float A = powf(10.0f, gain_db / 40.0f);
    float w0 = 2.0f * (float)M_PI * fc / (float)AUDIO_SAMPLE_RATE_HZ;
    float cosw0 = cosf(w0);
    float alpha = sinf(w0) / (2.0f * Q);
    float beta = 2.0f * sqrtf(A) * alpha;

    float b0 = A * ((A + 1) + (A - 1) * cosw0 + beta);
    float b1 = -2.0f * A * ((A - 1) + (A + 1) * cosw0);
    float b2 = A * ((A + 1) + (A - 1) * cosw0 - beta);
    float a0 = (A + 1) - (A - 1) * cosw0 + beta;
    float a1 = 2.0f * ((A - 1) - (A + 1) * cosw0);
    float a2 = (A + 1) - (A - 1) * cosw0 - beta;

    s_hs_b0 = b0 / a0;
    s_hs_b1 = b1 / a0;
    s_hs_b2 = b2 / a0;
    s_hs_a1 = a1 / a0;
    s_hs_a2 = a2 / a0;
    s_hs_x1 = s_hs_x2 = s_hs_y1 = s_hs_y2 = 0;
}

static inline float biquad_step(float x) {
    float y = s_hs_b0 * x + s_hs_b1 * s_hs_x1 + s_hs_b2 * s_hs_x2
              - s_hs_a1 * s_hs_y1 - s_hs_a2 * s_hs_y2;
    s_hs_x2 = s_hs_x1; s_hs_x1 = x;
    s_hs_y2 = s_hs_y1; s_hs_y1 = y;
    return y;
}

esp_err_t audio_init(void) {
#if defined(AUDIO_I2S_SPLIT)
    // Standard XIAO build: mic and speaker on SEPARATE I2S ports, each
    // with its own clocks and pins. (No single port = no full-duplex.)
    i2s_chan_config_t spk_chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_PORT_SPK, I2S_ROLE_MASTER);
    spk_chan_cfg.dma_desc_num = 8;
    spk_chan_cfg.dma_frame_num = AUDIO_FRAME_SAMPLES;
    spk_chan_cfg.auto_clear_after_cb = true;
    ESP_ERROR_CHECK(i2s_new_channel(&spk_chan_cfg, &s_tx, NULL));

    i2s_chan_config_t mic_chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_PORT_MIC, I2S_ROLE_MASTER);
    mic_chan_cfg.dma_desc_num = 8;
    mic_chan_cfg.dma_frame_num = AUDIO_FRAME_SAMPLES;
    mic_chan_cfg.auto_clear_after_cb = true;
    ESP_ERROR_CHECK(i2s_new_channel(&mic_chan_cfg, NULL, &s_rx));

    // ---- TX (speaker) ----
    i2s_std_config_t tx_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = SPK_PIN_BCLK,
            .ws = SPK_PIN_WS,
            .dout = SPK_PIN_DIN,
            .din = I2S_GPIO_UNUSED,
            .invert_flags = {0},
        },
    };
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_tx, &tx_cfg));

    // ---- RX (mic) ----
    i2s_std_config_t rx_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = MIC_PIN_BCLK,
            .ws = MIC_PIN_WS,
            .dout = I2S_GPIO_UNUSED,
            .din = MIC_PIN_SD,
            .invert_flags = {0},
        },
    };
    rx_cfg.slot_cfg.slot_mask = I2S_STD_SLOT_LEFT;
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_rx, &rx_cfg));

    ESP_ERROR_CHECK(i2s_channel_enable(s_tx));
    ESP_ERROR_CHECK(i2s_channel_enable(s_rx));
#else
    // Ducky PCB: full-duplex on one port, both channels share BCLK/WS.
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_PORT, I2S_ROLE_MASTER);
    chan_cfg.dma_desc_num = 8;
    // Match the per-descriptor size to the read size so a single read
    // returns one complete DMA descriptor (avoids partial-read rejections).
    chan_cfg.dma_frame_num = AUDIO_FRAME_SAMPLES;
    chan_cfg.auto_clear_after_cb = true;  // silence on TX underrun, no DMA loops

    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, &s_tx, &s_rx));

    // ---- TX (speaker) — 16-bit Philips STEREO ----
    // We write each mono sample twice (L=R) because the MAX98357 reads the
    // slot selected by its GAIN_SLOT pin; stereo Philips lets us be agnostic.
    i2s_std_config_t tx_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = I2S_PIN_BCLK,
            .ws = I2S_PIN_WS,
            .dout = SPK_PIN_DIN,
            .din = I2S_GPIO_UNUSED,
            .invert_flags = {0},
        },
    };
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_tx, &tx_cfg));

    // ---- RX (mic) — 16-bit Philips MONO, LEFT slot ----
    // ICS-43432 with L/R pin → GND outputs samples in the left slot.
    i2s_std_config_t rx_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = I2S_PIN_BCLK,
            .ws = I2S_PIN_WS,
            .dout = I2S_GPIO_UNUSED,
            .din = MIC_PIN_SD,
            .invert_flags = {0},
        },
    };
    rx_cfg.slot_cfg.slot_mask = I2S_STD_SLOT_LEFT;
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_rx, &rx_cfg));

    ESP_ERROR_CHECK(i2s_channel_enable(s_tx));
    ESP_ERROR_CHECK(i2s_channel_enable(s_rx));
#endif

    s_mic_lock = xSemaphoreCreateMutex();

    // ICS-43432 needs ~50ms after enable for the first samples to be valid.
    // Wait so calibration gets real noise floor instead of garbage.
    vTaskDelay(pdMS_TO_TICKS(100));

    // High-shelf EQ: boost above 2kHz by +6dB to undo enclosure muffling.
    compute_high_shelf(2000.0f, 0.7f, 6.0f);

    // ---- Mic gain: fixed conservative value ----
    // Was: noise-RMS-driven auto-gain at boot. Boot conditions ≠
    // talking conditions, so the locked-in value mismatched the room
    // when the user actually pressed the button — symptom was
    // "sometimes I just can't seem to talk to it." ElevenLabs Agents
    // does its own VAD + level normalization on the cloud side; a
    // fixed conservative gain feeds it a predictable signal at any
    // reasonable volume. If we see field reports of whisper-level
    // speech being missed, revisit with in-session AGC (#50).
    s_mic_gain = 8.0f;
    s_mic_dc = 0.0f;

    // Seed the DC tracker with one frame so the first ~60ms of audio
    // doesn't ride a stale DC offset through the gain stage. Cheap
    // (~20ms blocking) and only at boot. The slow alpha tracker in
    // audio_mic_read takes over from here.
    int16_t seedBuf[AUDIO_FRAME_SAMPLES];
    size_t seedRead = 0;
    if (i2s_channel_read(s_rx, seedBuf, sizeof(seedBuf), &seedRead,
                         pdMS_TO_TICKS(100)) == ESP_OK && seedRead > 0) {
        int n = seedRead / sizeof(int16_t);
        long long sum = 0;
        for (int i = 0; i < n; i++) sum += seedBuf[i];
        s_mic_dc = (float)(sum / n);
    }
    ESP_LOGI(TAG, "mic init: DC seed=%.0f gain=%.1f (fixed)",
             s_mic_dc, s_mic_gain);

#if defined(AUDIO_I2S_SPLIT)
    ESP_LOGI(TAG, "I2S split initialized @ %d Hz (mic: BCLK=%d WS=%d SD=%d, "
                  "spk: BCLK=%d WS=%d DIN=%d)",
             AUDIO_SAMPLE_RATE_HZ,
             MIC_PIN_BCLK, MIC_PIN_WS, MIC_PIN_SD,
             SPK_PIN_BCLK, SPK_PIN_WS, SPK_PIN_DIN);
#else
    ESP_LOGI(TAG, "I2S full-duplex initialized @ %d Hz (BCLK=%d WS=%d "
                  "spk_dout=%d mic_din=%d)",
             AUDIO_SAMPLE_RATE_HZ, I2S_PIN_BCLK, I2S_PIN_WS,
             SPK_PIN_DIN, MIC_PIN_SD);
#endif
    return ESP_OK;
}

void audio_mic_enable(bool on) {
    // No drain — mic is always-on now (server VAD handles echo). The drain
    // was emptying DMA and starving subsequent reads.
    s_mic_enabled = on;
}
bool audio_mic_is_enabled(void) { return s_mic_enabled; }

size_t audio_mic_read(int16_t *out, size_t max_samples, int timeout_ms) {
    if (!s_mic_enabled) {
        vTaskDelay(pdMS_TO_TICKS(timeout_ms));
        return 0;
    }
    size_t want = (max_samples < AUDIO_FRAME_SAMPLES ? max_samples : AUDIO_FRAME_SAMPLES);
    size_t bytes_read = 0;
    xSemaphoreTake(s_mic_lock, portMAX_DELAY);
    esp_err_t err = i2s_channel_read(s_rx, out, want * sizeof(int16_t),
                                     &bytes_read, pdMS_TO_TICKS(timeout_ms));
    xSemaphoreGive(s_mic_lock);
    if (err != ESP_OK) {
        static int64_t last_err_log = 0;
        int64_t now = esp_timer_get_time() / 1000;
        if (now - last_err_log > 2000) {
            ESP_LOGW(TAG, "i2s_channel_read err=0x%x bytes=%u", err, (unsigned)bytes_read);
            last_err_log = now;
        }
        return 0;
    }
    // Accept partial reads. With i2s_channel_read returning one DMA
    // descriptor at a time, asking for >descriptor_size returns less than
    // requested. Forwarding partial frames is fine — server reassembles.
    size_t n = bytes_read / sizeof(int16_t);
    if (n == 0) return 0;
    // DC removal + gain (EQ disabled — was making audio worse, see git log)
    for (size_t i = 0; i < n; i++) {
        float r = (float)out[i];
        s_mic_dc += MIC_DC_ALPHA * (r - s_mic_dc);
        float v = (r - s_mic_dc) * s_mic_gain;
        if (v > 32767.0f) v = 32767.0f;
        if (v < -32767.0f) v = -32767.0f;
        out[i] = (int16_t)v;
    }
    return n;
}

size_t audio_mic_read_raw(int16_t *out, size_t max_samples, int timeout_ms) {
    // Bypasses the enable-gate AND the DC/gain transform — used by the
    // tap-to-wake transient detector (wake.c). Mutex serializes against
    // audio_mic_read so the two callers don't split a DMA descriptor.
    size_t want = (max_samples < AUDIO_FRAME_SAMPLES ? max_samples : AUDIO_FRAME_SAMPLES);
    size_t bytes_read = 0;
    xSemaphoreTake(s_mic_lock, portMAX_DELAY);
    esp_err_t err = i2s_channel_read(s_rx, out, want * sizeof(int16_t),
                                     &bytes_read, pdMS_TO_TICKS(timeout_ms));
    xSemaphoreGive(s_mic_lock);
    if (err != ESP_OK) return 0;
    return bytes_read / sizeof(int16_t);
}

esp_err_t audio_spk_write(const int16_t *pcm, size_t num_samples) {
    // Extend the speaker-busy window. chunk_duration_ms is how long this
    // chunk takes to play; +AMP_DECAY_MS covers the trailing ring afterward.
    // Every call pushes the deadline forward, so a continuous stream of
    // writes keeps the gate up and the trailing decay starts from the LAST
    // write, not the first.
    int chunk_duration_ms = (int)((num_samples * 1000) / AUDIO_SAMPLE_RATE_HZ);
    s_spk_active_until_ms = audio_now_ms() + chunk_duration_ms + AMP_DECAY_MS;

    // Mono → stereo expansion: write each sample twice (L=R) for the Philips
    // stereo slot config. Use a small chunked buffer so we don't allocate
    // huge stacks. 256 mono samples = 512 stereo samples = 1024 bytes.
    int16_t stereo[512];
    size_t pos = 0;
    while (pos < num_samples) {
        size_t take = (num_samples - pos < 256) ? (num_samples - pos) : 256;
        for (size_t i = 0; i < take; i++) {
            stereo[i * 2]     = pcm[pos + i];
            stereo[i * 2 + 1] = pcm[pos + i];
        }
        size_t written = 0;
        esp_err_t err = i2s_channel_write(s_tx, stereo, take * 2 * sizeof(int16_t),
                                          &written, portMAX_DELAY);
        if (err != ESP_OK) return err;
        pos += take;
    }
    return ESP_OK;
}

bool audio_speaker_active(void) {
    return audio_now_ms() < s_spk_active_until_ms;
}

// ============================================================
// Chirp synth — sawtooth oscillator + Chamberlin SVF bandpass
// ============================================================
//
// Port of the original Teensy duck's ChirpSynth.ino — a 2x oversampled
// state-variable filter on a sawtooth oscillator gives the duck its
// squelchy "quack/whistle/uh-uh" character. The original ran at 44.1kHz
// to match Teensy Audio; coefficients are frequency-relative so the
// math re-derives cleanly at our 16kHz I2S bus.
//
// Algorithm matches Teensy's AudioFilterStateVariable exactly: 2x
// oversampled Chamberlin SVF (iter 1 uses (input + previous)/2, iter 2
// uses input directly). Don't simplify to 1x — the oversampling is what
// keeps high-resonance filter sweeps from blowing up at audio rate.
//
// Public surface (audio.h): audio_chirp_up / audio_chirp_down. Both
// generate a two-note pair through the synth — "happy ascending +
// opening filter" vs "sad descending + closing filter". Same coarse
// shape as the old sine-only implementations, just with the duck
// character on top.
typedef struct {
    float low;          // SVF lowpass state
    float band;         // SVF bandpass state
    float prev_input;   // for 2x oversample interpolation
    float f;            // freq coef = sin(pi * f / (2 * sr))
    float damp;         // 1.0 / Q
} chirp_svf_t;

static inline void chirp_svf_reset(chirp_svf_t *s) {
    s->low = s->band = s->prev_input = 0.0f;
}

static void chirp_svf_set_freq(chirp_svf_t *s, float center_hz, float Q) {
    // Clamp range matches the Teensy original. center_hz/2.5 is the upper
    // ceiling that keeps the SVF stable at the working sample rate; Q in
    // [0.7, 5.0] is the resonance band the original tuning was made for.
    if (center_hz < 20.0f) center_hz = 20.0f;
    float max_hz = (float)AUDIO_SAMPLE_RATE_HZ / 2.5f;
    if (center_hz > max_hz) center_hz = max_hz;
    if (Q < 0.7f) Q = 0.7f;
    if (Q > 5.0f) Q = 5.0f;
    s->f = sinf((float)M_PI * center_hz /
                ((float)AUDIO_SAMPLE_RATE_HZ * 2.0f));
    s->damp = 1.0f / Q;
}

// Run one input sample through the SVF, return bandpass output. 2x
// oversampled: iter 1 uses interpolated (input + prev)/2, iter 2 uses
// input directly. Both update low/band states; we read band on exit.
static inline float chirp_svf_process(chirp_svf_t *s, float input) {
    float high;
    float mid = (input + s->prev_input) * 0.5f;
    s->low  += s->f * s->band;
    high     = mid - s->low - s->damp * s->band;
    s->band += s->f * high;
    s->low  += s->f * s->band;
    high     = input - s->low - s->damp * s->band;
    s->band += s->f * high;
    s->prev_input = input;
    return s->band;
}

// Sawtooth oscillator — accumulator phase wraps [0,1), output [-1,1].
// The original also has sineSample but bambu's audio_chirp() above
// already covers that case; the squelch synth is sawtooth-only.
static inline float chirp_saw_sample(float *phase, float freq_hz) {
    *phase += freq_hz / (float)AUDIO_SAMPLE_RATE_HZ;
    if (*phase >= 1.0f) *phase -= 1.0f;
    return 2.0f * (*phase) - 1.0f;
}

// Synthesize a single sawtooth note with a linear frequency sweep and
// an exponential filter envelope, write to the speaker. `duration_ms`
// covers the audible portion; the 5ms head + tail attack/release runs
// inside that window so the sample budget matches the timing model
// the call sites already have for audio_chirp().
//
// `filter_start_hz` / `filter_end_hz` define the SVF center sweep —
// "opening filter" (start < end) gives the bright "whistle" quality;
// "closing filter" (start > end) gives the muffled "uh-uh" quality.
// `filter_rise_rate` is the exponential envelope time constant — 5
// is the original's expressive setting, 10+ is snappier for short
// UI cues. Q stays at 5.0 (matches the original's tuning).
static void chirp_squelch_note(int start_freq_hz, int end_freq_hz,
                                int duration_ms,
                                float filter_start_hz, float filter_end_hz,
                                float filter_rise_rate) {
    const int sr = AUDIO_SAMPLE_RATE_HZ;
    int total = (sr * duration_ms) / 1000;
    int chunk = 256;
    int16_t buf[256];
    float phase = 0.0f;
    chirp_svf_t svf;
    chirp_svf_reset(&svf);
    chirp_svf_set_freq(&svf, filter_start_hz, 5.0f);

    int written = 0;
    int attack_release_samples = sr / 100;  // 10ms each side
    while (written < total) {
        int n = (total - written < chunk) ? (total - written) : chunk;
        for (int i = 0; i < n; i++) {
            int idx = written + i;
            float t = (float)idx / (float)total;  // [0,1)

            // Linear oscillator frequency sweep.
            float freq = (float)start_freq_hz +
                         ((float)end_freq_hz - (float)start_freq_hz) * t;

            // Exponential filter sweep — same shape as the Teensy
            // original (1 - exp(-t_sec * rise_rate)).
            float t_sec = (float)idx / (float)sr;
            float fenv = 1.0f - expf(-t_sec * filter_rise_rate);
            float fhz = filter_start_hz +
                        (filter_end_hz - filter_start_hz) * fenv;
            chirp_svf_set_freq(&svf, fhz, 5.0f);

            // Sawtooth → bandpass → amplitude envelope.
            float s = chirp_saw_sample(&phase, freq);
            s = chirp_svf_process(&svf, s);

            // Linear attack/release so the start/end clicks are gone.
            float env = 1.0f;
            if (idx < attack_release_samples)
                env = (float)idx / (float)attack_release_samples;
            else if (total - idx < attack_release_samples)
                env = (float)(total - idx) / (float)attack_release_samples;

            // Amplitude tuned by ear to sit just under the agent voice
            // level coming from ElevenLabs (which peaks ~16k–20k). The
            // sawtooth + resonant bandpass is perceptually punchier
            // than a sine at the same RMS, so we run it at 13500 even
            // though int16 headroom would allow more — chirps that are
            // louder than the agent's voice read as "the duck is
            // overreacting" instead of as quiet UI feedback.
            float v = env * 13500.0f * s;
            if (v > 32000.0f)  v = 32000.0f;
            if (v < -32000.0f) v = -32000.0f;
            buf[i] = (int16_t)v;
        }
        audio_spk_write(buf, n);
        written += n;
    }
}

// Short silence between notes so the two halves read as a pair, not a
// glide. Same gap audio_chirp() leaves after a tone.
static void chirp_silence(int duration_ms) {
    const int sr = AUDIO_SAMPLE_RATE_HZ;
    int total = (sr * duration_ms) / 1000;
    int16_t zeros[256] = {0};
    int written = 0;
    while (written < total) {
        int n = (total - written < 256) ? (total - written) : 256;
        audio_spk_write(zeros, n);
        written += n;
    }
}

void audio_chirp(int freq_hz, int duration_ms) {
    // Single-note squelch: filter opens from a half-octave below the
    // carrier up to ~2× carrier across the note. This gives every
    // ad-hoc chirp the same "duck" character as the named chirp_up /
    // chirp_down voices. Call sites in main.c (boot beeps, settings
    // mode, wizard entry) keep their distinct frequency choices —
    // they just sound squelchy now instead of pure sine, so the whole
    // onboarding flow has consistent timbre.
    float filter_start = (float)freq_hz * 0.7f;
    float filter_end   = (float)freq_hz * 2.2f;
    chirp_squelch_note(freq_hz, freq_hz, duration_ms,
                       filter_start, filter_end, 12.0f);
    // Match the old behavior's 50ms silent tail — call sites string
    // multiple chirps back-to-back and rely on the gap so they read
    // as separate notes rather than one glide.
    chirp_silence(50);
}

void audio_chirp_bend(int start_hz, int end_hz, int duration_ms) {
    // Filter sweep tracks the pitch sweep — opens from the lower freq's
    // half-octave below up to the higher freq's ~2x. This keeps the
    // squelchy timbre consistent across the bend instead of one half
    // sounding muffled and the other bright.
    int low_hz  = start_hz < end_hz ? start_hz : end_hz;
    int high_hz = start_hz > end_hz ? start_hz : end_hz;
    float filter_start = (float)low_hz  * 0.7f;
    float filter_end   = (float)high_hz * 2.2f;
    chirp_squelch_note(start_hz, end_hz, duration_ms,
                       filter_start, filter_end, 12.0f);
    chirp_silence(50);
}

void audio_chirp_up(void) {
    // "Wake" — single ascending pitch bend in the duck's vocal
    // register. Lives in the same low-mid range as the boot and
    // connect bends so the duck's voice has one consistent pitch
    // identity rather than UI cues jumping into a synth-beep
    // register on every state change.
    audio_chirp_bend(380, 640, 220);
}

void audio_chirp_down(void) {
    // "Hangup" — descending pitch bend, neutral. Same vocal
    // register as chirp_up; reversed direction reads as
    // "session ended" / "letting go" without sounding sad
    // (the longer-fall "I need help" bend in main.c handles
    // genuinely sad).
    audio_chirp_bend(640, 380, 220);
}
