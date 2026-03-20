// ============================================================
// USBAudio — USB Audio Class (UAC) device
// ============================================================
// Makes the ESP32-S3 appear as "Duck Duck Duck" in CoreAudio.
// Mic input + speaker output, 16kHz 16-bit mono.
//
// For now this is a minimal stub — speaker data is discarded,
// mic sends silence. The point is to get the device to enumerate.
// ============================================================

#include <Arduino.h>
#include "Config.h"

#if ENABLE_UAC

extern "C" {
#include "usb_device_uac.h"
}

// Called when host sends audio to us (TTS playback)
static esp_err_t speaker_cb(uint8_t *buf, size_t len, void *cb_ctx)
{
    static int count = 0;
    if (++count % 100 == 0) {
        Serial.printf("[spk] cb #%d len=%d\n", count, (int)len);
    }
    audioI2SWrite((const int16_t *)buf, len / 2);
    (void)cb_ctx;
    return ESP_OK;
}

// Called when host requests audio from us (mic capture)
static esp_err_t mic_cb(uint8_t *buf, size_t len, size_t *bytes_read, void *cb_ctx)
{
    // TODO: route from I2S ADC / PDM mic
    // For now, send silence
    memset(buf, 0, len);
    *bytes_read = len;
    (void)cb_ctx;
    return ESP_OK;
}

static void mute_cb(uint32_t mute, void *cb_ctx)
{
    Serial.printf("[uac] mute: %lu\n", mute);
    (void)cb_ctx;
}

static void volume_cb(uint32_t volume, void *cb_ctx)
{
    Serial.printf("[uac] volume: %lu\n", volume);
    (void)cb_ctx;
}

void setupUSBAudio()
{
    uac_device_config_t config = {};
    config.output_cb = speaker_cb;
    config.input_cb = mic_cb;
    config.set_mute_cb = mute_cb;
    config.set_volume_cb = volume_cb;
    config.cb_ctx = NULL;

    esp_err_t err = uac_device_init(&config);
    if (err != ESP_OK) {
        Serial.printf("[uac] init FAILED: %d\n", err);
    } else {
        Serial.println("[uac] USB Audio Class initialized");
    }
}

#else

void setupUSBAudio() {}

#endif
