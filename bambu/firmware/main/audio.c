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
#include <freertos/task.h>

static const char *TAG = "audio";

static i2s_chan_handle_t s_tx = NULL;  // speaker
static i2s_chan_handle_t s_rx = NULL;  // mic
static volatile bool s_mic_enabled = false;

// DC removal + gain (ported from rubber_duck_s3_ducky/MicCapture.ino).
// ICS-43432 in 16-bit mode is quiet; default gain 8× brings speech up to
// usable amplitude. Calibration in audio_init() may bump up to 64× based
// on noise floor.
static float s_mic_dc = 0.0f;
static float s_mic_gain = 8.0f;
static const float MIC_DC_ALPHA = 0.001f;

esp_err_t audio_init(void) {
    // Allocate both TX (speaker) and RX (mic) on the SAME port — full-duplex.
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

    // ---- Mic calibration: DC offset + auto-gain ----
    // Same approach as rubber_duck_s3_ducky/MicCapture.ino setupMic().
    int16_t calBuf[AUDIO_FRAME_SAMPLES];
    size_t calRead = 0;
    long long calSum = 0;
    int calCount = 0;
    for (int f = 0; f < 4; f++) {
        if (i2s_channel_read(s_rx, calBuf, sizeof(calBuf), &calRead,
                             pdMS_TO_TICKS(100)) == ESP_OK) {
            int n = calRead / sizeof(int16_t);
            for (int i = 0; i < n; i++) calSum += calBuf[i];
            calCount += n;
        }
    }
    s_mic_dc = (calCount > 0) ? (float)(calSum / calCount) : 0.0f;

    if (calCount > 0 &&
        i2s_channel_read(s_rx, calBuf, sizeof(calBuf), &calRead,
                         pdMS_TO_TICKS(100)) == ESP_OK) {
        int n = calRead / sizeof(int16_t);
        float noiseSum = 0;
        for (int i = 0; i < n; i++) {
            float v = (float)calBuf[i] - s_mic_dc;
            noiseSum += v * v;
        }
        float noiseRMS = sqrtf(noiseSum / n);
        if (noiseRMS > 1.0f) {
            float g = 8192.0f / (noiseRMS * 10.0f);
            if (g < 1.0f) g = 1.0f;
            if (g > 64.0f) g = 64.0f;
            s_mic_gain = g;
        } else {
            s_mic_gain = 8.0f;
        }
        ESP_LOGI(TAG, "mic cal: DC=%.0f noiseRMS=%.1f gain=%.1f",
                 s_mic_dc, noiseRMS, s_mic_gain);
    }

    ESP_LOGI(TAG, "I2S full-duplex initialized @ %d Hz (BCLK=%d WS=%d "
                  "spk_dout=%d mic_din=%d)",
             AUDIO_SAMPLE_RATE_HZ, I2S_PIN_BCLK, I2S_PIN_WS,
             SPK_PIN_DIN, MIC_PIN_SD);
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
    esp_err_t err = i2s_channel_read(s_rx, out, want * sizeof(int16_t),
                                     &bytes_read, pdMS_TO_TICKS(timeout_ms));
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
    // DC removal + gain in-place (per rubber_duck_s3_ducky updateMic).
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

esp_err_t audio_spk_write(const int16_t *pcm, size_t num_samples) {
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
