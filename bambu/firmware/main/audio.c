#include "audio.h"
#include "config.h"

#include <string.h>

#include <driver/i2s_std.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "audio";

static i2s_chan_handle_t s_mic_rx = NULL;
static i2s_chan_handle_t s_spk_tx = NULL;
static volatile bool s_mic_enabled = false;

static esp_err_t init_mic(void) {
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(MIC_I2S_PORT, I2S_ROLE_MASTER);
    ESP_ERROR_CHECK(i2s_new_channel(&chan_cfg, NULL, &s_mic_rx));

    i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE_HZ),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = MIC_PIN_SCK,
            .ws = MIC_PIN_WS,
            .dout = I2S_GPIO_UNUSED,
            .din = MIC_PIN_SD,
            .invert_flags = {0},
        },
    };
    // INMP441 outputs 24-bit data left-aligned in a 32-bit slot. Use 32-bit
    // slot, take the high 16 bits in mic_read.
    std_cfg.slot_cfg.slot_bit_width = I2S_SLOT_BIT_WIDTH_32BIT;
    std_cfg.slot_cfg.slot_mask = I2S_STD_SLOT_LEFT;

    ESP_ERROR_CHECK(i2s_channel_init_std_mode(s_mic_rx, &std_cfg));
    ESP_ERROR_CHECK(i2s_channel_enable(s_mic_rx));
    return ESP_OK;
}

static esp_err_t init_spk(void) {
    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(SPK_I2S_PORT, I2S_ROLE_MASTER);
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
    size_t samples = bytes_read / sizeof(int32_t);
    for (size_t i = 0; i < samples; i++) {
        // Top 16 bits of the 24-bit-in-32-bit word. Shift 16 = drop low byte
        // of mantissa + sign-extend correctly. Adjust gain here if too quiet.
        out[i] = (int16_t)(raw[i] >> 16);
    }
    return samples;
}

esp_err_t audio_spk_write(const int16_t *pcm, size_t num_samples) {
    size_t written = 0;
    return i2s_channel_write(s_spk_tx, pcm, num_samples * sizeof(int16_t),
                             &written, portMAX_DELAY);
}
