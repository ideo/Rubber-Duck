#include "audio.h"
#include "config.h"

#include <math.h>
#include <string.h>

#include <driver/i2s_std.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "audio";

static i2s_chan_handle_t s_mic_rx = NULL;
static i2s_chan_handle_t s_spk_tx = NULL;
static volatile bool s_mic_enabled = false;

// --- Mic DC tracking + auto-gain (ported verbatim from
// firmware/rubber_duck_s3/MicCapture.ino — known-good on this hardware)
static float s_i2s_dc = 0.0f;
static float s_i2s_gain = 1.0f;
static const float I2S_DC_ALPHA = 0.001f;

static esp_err_t init_mic(void) {
    // ICS-43434 / INMP441 — 24-bit data left-aligned in a 32-bit slot.
    // Init params copied from firmware/rubber_duck_s3/MicCapture.ino which
    // is known-working on identical hardware (XIAO ESP32-S3 + ICS-43434).
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(MIC_I2S_PORT, I2S_ROLE_MASTER);
    chan_cfg.dma_desc_num = 4;
    chan_cfg.dma_frame_num = AUDIO_FRAME_SAMPLES;
    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, NULL, &s_mic_rx));

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_32BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = MIC_PIN_SCK,
            .ws = MIC_PIN_WS,
            .dout = I2S_GPIO_UNUSED,
            .din = MIC_PIN_SD,
            .invert_flags = {0},
        },
    };
    std_cfg.slot_cfg.slot_mask = I2S_STD_SLOT_LEFT;  // SEL→GND = left channel

    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_mic_rx, &std_cfg));
    ESP_ERROR_CHECK(i2s_channel_enable(s_mic_rx));

    // ---- Calibration (verbatim from rubber_duck_s3/MicCapture.ino) ----
    // 4 frames of "silence" → DC offset, 1 more frame → noise RMS → gain.
    int32_t calBuf[AUDIO_FRAME_SAMPLES];
    size_t calRead = 0;
    long long calSum = 0;
    int calCount = 0;
    for (int f = 0; f < 4; f++) {
        if (i2s_channel_read(s_mic_rx, calBuf, sizeof(calBuf), &calRead,
                             pdMS_TO_TICKS(100)) == ESP_OK) {
            int samplesRead = calRead / sizeof(int32_t);
            for (int i = 0; i < samplesRead; i++) {
                calSum += (calBuf[i] >> 8);  // 24-bit in top bits
                calCount++;
            }
        }
    }
    s_i2s_dc = (calCount > 0) ? (float)(calSum / calCount) : 0.0f;

    float noiseSum = 0;
    if (calCount > 0) {
        if (i2s_channel_read(s_mic_rx, calBuf, sizeof(calBuf), &calRead,
                             pdMS_TO_TICKS(100)) == ESP_OK) {
            int samplesRead = calRead / sizeof(int32_t);
            for (int i = 0; i < samplesRead; i++) {
                float val = (float)(calBuf[i] >> 8) - s_i2s_dc;
                noiseSum += val * val;
            }
            float noiseRMS = sqrtf(noiseSum / samplesRead);
            if (noiseRMS > 10.0f) {
                float g = 16384.0f / (noiseRMS * 4.0f);
                if (g < 0.001f) g = 0.001f;
                if (g > 4.0f) g = 4.0f;
                s_i2s_gain = g;
            } else {
                s_i2s_gain = 0.02f;  // safe default for ICS-43434
            }
            ESP_LOGI(TAG, "I2S cal — DC: %.0f  noise: %.1f  gain: %.4f",
                     s_i2s_dc, noiseRMS, s_i2s_gain);
        }
    }
    if (s_i2s_gain < 0.0001f) s_i2s_gain = 0.004f;
    return ESP_OK;
}

static esp_err_t init_spk(void) {
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(SPK_I2S_PORT, I2S_ROLE_MASTER);
    // CRUCIAL: without this, DMA loops the last buffer forever after writes stop.
    // (URAM does this in speaker.c — same fix.)
    chan_cfg.auto_clear_after_cb = true;
    chan_cfg.dma_desc_num = 8;
    chan_cfg.dma_frame_num = 512;
    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, &s_spk_tx, NULL));

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = SPK_PIN_BCLK,
            .ws = SPK_PIN_LRC,
            .dout = SPK_PIN_DIN,
            .din = I2S_GPIO_UNUSED,
            .invert_flags = {0},
        },
    };
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_spk_tx, &std_cfg));
    ESP_ERROR_CHECK(i2s_channel_enable(s_spk_tx));
    return ESP_OK;
}

esp_err_t audio_init(void) {
    ESP_ERROR_CHECK(init_mic());
    ESP_ERROR_CHECK(init_spk());
    ESP_LOGI(TAG, "I2S mic + spk initialized @ %d Hz", AUDIO_SAMPLE_RATE_HZ);
    return ESP_OK;
}

void audio_mic_enable(bool on) { s_mic_enabled = on; }
bool audio_mic_is_enabled(void) { return s_mic_enabled; }

size_t audio_mic_read(int16_t *out, size_t max_samples, int timeout_ms) {
    if (!s_mic_enabled) {
        vTaskDelay(pdMS_TO_TICKS(timeout_ms));
        return 0;
    }
    // INMP441: read 32-bit words, keep high 16 bits.
    int32_t raw[AUDIO_FRAME_SAMPLES];
    size_t want = (max_samples < AUDIO_FRAME_SAMPLES ? max_samples : AUDIO_FRAME_SAMPLES);
    size_t bytes_read = 0;
    esp_err_t err = i2s_channel_read(s_mic_rx, raw, want * sizeof(int32_t),
                                     &bytes_read, pdMS_TO_TICKS(timeout_ms));
    if (err != ESP_OK) return 0;
    // Reject partial reads — a short frame stitched into a continuous PCM
    // stream causes phoneme-boundary misalignment (per rubber_duck_s3).
    if (bytes_read < want * sizeof(int32_t)) return 0;
    size_t samples = bytes_read / sizeof(int32_t);
    // Verbatim from firmware/rubber_duck_s3/MicCapture.ino updateMic():
    // raw>>8 to drop 8 padding bits → signed 24-bit, then running DC
    // removal, then learned gain, then clamp to int16.
    for (size_t i = 0; i < samples; i++) {
        float r = (float)(raw[i] >> 8);
        s_i2s_dc += I2S_DC_ALPHA * (r - s_i2s_dc);
        float sample = (r - s_i2s_dc) * s_i2s_gain;
        if (sample > 32767.0f) sample = 32767.0f;
        if (sample < -32767.0f) sample = -32767.0f;
        out[i] = (int16_t)sample;
    }
    return samples;
}

esp_err_t audio_spk_write(const int16_t *pcm, size_t num_samples) {
    size_t written = 0;
    return i2s_channel_write(s_spk_tx, pcm, num_samples * sizeof(int16_t),
                             &written, portMAX_DELAY);
}

#include <math.h>
// memset for silence flush is in <string.h>, already pulled by other includes,
// but be explicit:

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
            // Tiny attack/release envelope so it doesn't click.
            float env = 1.0f;
            int from_start = written_samples + i;
            int from_end = total - from_start;
            if (from_start < sr / 100) env = (float)from_start / (sr / 100.0f);
            if (from_end  < sr / 100) env = (float)from_end   / (sr / 100.0f);
            buf[i] = (int16_t)(env * 12000.0f * sinf(phase));
            phase += step;
            if (phase > 2.0f * (float)M_PI) phase -= 2.0f * (float)M_PI;
        }
        audio_spk_write(buf, n);
        written_samples += n;
    }
    // Flush the DMA buffer with silence so the amp doesn't loop the last
    // tone forever. ~50ms is plenty larger than any DMA buffer.
    memset(buf, 0, sizeof(buf));
    int silence_total = sr / 20;  // 50ms
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
