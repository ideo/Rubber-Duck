// ============================================================
// AudioI2S — I2S output to MAX98357 DAC
// ============================================================
// Receives 16-bit mono PCM from UAC speaker callback,
// expands to stereo, writes to I2S DMA.
// ============================================================

#if ENABLE_AUDIO

#include <Arduino.h>
#include "Config.h"
#include "driver/i2s_std.h"
#include "driver/gpio.h"

static i2s_chan_handle_t txHandle = NULL;

void setupAudioI2S()
{
    i2s_chan_config_t chanCfg = I2S_CHANNEL_DEFAULT_CONFIG(AUDIO_I2S_PORT, I2S_ROLE_MASTER);
    chanCfg.dma_desc_num = I2S_DMA_BUF_COUNT;
    chanCfg.dma_frame_num = I2S_DMA_BUF_LEN;
    chanCfg.auto_clear = true;

    esp_err_t err = i2s_new_channel(&chanCfg, &txHandle, NULL);
    if (err != ESP_OK) {
        Serial.printf("[i2s] channel alloc failed: %d\n", err);
        return;
    }

    i2s_std_config_t stdCfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(AUDIO_SAMPLE_RATE),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO),
        .gpio_cfg = {
            .mclk = I2S_GPIO_UNUSED,
            .bclk = (gpio_num_t)I2S_BCLK_PIN,
            .ws = (gpio_num_t)I2S_WS_PIN,
            .dout = (gpio_num_t)I2S_DOUT_PIN,
            .din = I2S_GPIO_UNUSED,
            .invert_flags = {
                .mclk_inv = false,
                .bclk_inv = false,
                .ws_inv = false,
            },
        },
    };

    err = i2s_channel_init_std_mode(txHandle, &stdCfg);
    if (err != ESP_OK) {
        Serial.printf("[i2s] STD init failed: %d\n", err);
        i2s_del_channel(txHandle);
        txHandle = NULL;
        return;
    }

    err = i2s_channel_enable(txHandle);
    if (err != ESP_OK) {
        Serial.printf("[i2s] enable failed: %d\n", err);
        i2s_del_channel(txHandle);
        txHandle = NULL;
        return;
    }

    Serial.printf("[i2s] Ready — BCLK=D2 WS=D3 DOUT=D4 @ %dHz\n", AUDIO_SAMPLE_RATE);
}

// Write mono 16-bit samples → expand to stereo → I2S DMA
void audioI2SWrite(const int16_t *samples, size_t count)
{
    if (!txHandle || count == 0) return;

    // Expand mono → stereo in-place on stack (max 256 frames at a time)
    int16_t stereo[512];
    size_t offset = 0;

    while (offset < count) {
        size_t chunk = count - offset;
        if (chunk > 256) chunk = 256;

        for (size_t i = 0; i < chunk; i++) {
            stereo[i * 2]     = samples[offset + i];
            stereo[i * 2 + 1] = samples[offset + i];
        }

        size_t bytesWritten = 0;
        i2s_channel_write(txHandle, stereo, chunk * 4, &bytesWritten, pdMS_TO_TICKS(5));
        offset += chunk;
    }
}

#else

#include <stdint.h>
#include <stddef.h>
void setupAudioI2S() {}
void audioI2SWrite(const int16_t *, size_t) {}

#endif
