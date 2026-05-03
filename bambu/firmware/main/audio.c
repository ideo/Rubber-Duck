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

void audio_chirp(int freq_hz, int duration_ms) {
    const int sr = AUDIO_SAMPLE_RATE_HZ;
    int total = (sr * duration_ms) / 1000;
    int chunk = 256;
    int16_t buf[256];
    float phase = 0.0f;
    float step = 2.0f * (float)M_PI * (float)freq_hz / (float)sr;
    int written_samples = 0;
    while (written_samples < total) {
        int n = (total - written_samples < chunk) ? (total - written_samples) : chunk;
        for (int i = 0; i < n; i++) {
            float env = 1.0f;
            int from_start = written_samples + i;
            int from_end = total - from_start;
            if (from_start < sr / 100) env = (float)from_start / (sr / 100.0f);
            if (from_end < sr / 100) env = (float)from_end / (sr / 100.0f);
            buf[i] = (int16_t)(env * 12000.0f * sinf(phase));
            phase += step;
            if (phase > 2.0f * (float)M_PI) phase -= 2.0f * (float)M_PI;
        }
        audio_spk_write(buf, n);
        written_samples += n;
    }
    memset(buf, 0, sizeof(buf));
    int silence_total = sr / 20;  // 50ms tail of silence
    int s_written = 0;
    while (s_written < silence_total) {
        int n = (silence_total - s_written < chunk) ? (silence_total - s_written) : chunk;
        audio_spk_write(buf, n);
        s_written += n;
    }
}

void audio_chirp_up(void) {
    audio_chirp(700, 90);
    audio_chirp(1100, 110);
}

void audio_chirp_down(void) {
    audio_chirp(700, 90);
    audio_chirp(450, 140);
}
