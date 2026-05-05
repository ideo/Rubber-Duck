// Spoken onboarding phrases (#34). Pre-recorded ElevenLabs TTS
// (Liam voice — same as the conversational agent) encoded to Ogg-
// Opus 16 kHz mono 24 kbps voip, embedded in flash via CMakeLists
// EMBED_FILES. Decoded on-chip by micro-opus, written straight into
// the existing I2S TX path through audio_spk_write.
//
// One decoder instance held across the lifetime of the chip — its
// allocation is ~140 KB PSRAM, expensive to drop. Phrases are
// serialized via s_play_mutex so two calls don't trample the I2S
// stream.
//
// Source-of-truth for phrase texts is bambu/firmware/main/phrases/
// <name>.txt sidecars + the dispatch table below. Re-generate the
// .opus blobs from the texts via bambu/firmware/scripts/gen_phrases.py.

#include "phrases.h"
#include "opus_decoder.h"
#include "audio.h"

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>

static const char *TAG = "phrases";

// Embedded blob symbols — populated by EMBED_FILES in CMakeLists.txt.
// `_start` is the first byte; `_end` is one past the last. Subtract
// to get size. Each entry below has BOTH symbols declared even when
// the file isn't embedded yet; the linker will fail loudly if a
// referenced phrase is missing from CMakeLists, which is the right
// behavior — we want compile-time confirmation that all phrase IDs
// resolve to actual blobs.
extern const uint8_t _binary_tap_to_start_opus_start[]  asm("_binary_tap_to_start_opus_start");
extern const uint8_t _binary_tap_to_start_opus_end[]    asm("_binary_tap_to_start_opus_end");
extern const uint8_t _binary_wifi_up_opus_start[]       asm("_binary_wifi_up_opus_start");
extern const uint8_t _binary_wifi_up_opus_end[]         asm("_binary_wifi_up_opus_end");
extern const uint8_t _binary_wifi_connected_opus_start[] asm("_binary_wifi_connected_opus_start");
extern const uint8_t _binary_wifi_connected_opus_end[]   asm("_binary_wifi_connected_opus_end");

typedef struct {
    const uint8_t *start;
    const uint8_t *end;
    const char *name;  // for logging
} phrase_blob_t;

static const phrase_blob_t s_blobs[PHRASE_COUNT] = {
    [PHRASE_TAP_TO_START] = {
        _binary_tap_to_start_opus_start, _binary_tap_to_start_opus_end,
        "tap_to_start",
    },
    [PHRASE_WIFI_UP] = {
        _binary_wifi_up_opus_start, _binary_wifi_up_opus_end, "wifi_up",
    },
    [PHRASE_WIFI_CONNECTED] = {
        _binary_wifi_connected_opus_start, _binary_wifi_connected_opus_end,
        "wifi_connected",
    },
};

static opus_clip_decoder_t *s_decoder = NULL;
static SemaphoreHandle_t s_play_mutex = NULL;
static volatile bool s_active = false;

// micro-opus decoder callback — gets each ~20ms PCM frame, hands
// straight to the I2S TX. audio_spk_write blocks until the chunk is
// queued in the DMA descriptor ring, which provides natural back-
// pressure: phrase playback paces itself to the speaker.
static void pcm_writer(void *ctx, const int16_t *samples, unsigned count) {
    (void)ctx;
    if (count == 0) return;
    audio_spk_write(samples, count);
}

static void ensure_init(void) {
    if (s_play_mutex == NULL) {
        s_play_mutex = xSemaphoreCreateMutex();
    }
    if (s_decoder == NULL) {
        s_decoder = opus_clip_decoder_create();
        if (s_decoder == NULL) {
            ESP_LOGE(TAG, "decoder create failed — phrases disabled");
        }
    }
}

bool phrase_play(phrase_id_t id) {
    if (id < 0 || id >= PHRASE_COUNT) return false;
    ensure_init();
    if (s_decoder == NULL || s_play_mutex == NULL) return false;

    const phrase_blob_t *b = &s_blobs[id];
    int size = (int)(b->end - b->start);
    if (size <= 0) {
        ESP_LOGW(TAG, "phrase %s has no embedded data", b->name);
        return false;
    }

    // Serialize against any concurrent caller — two phrases can't
    // share the I2S TX ring without sounding mangled.
    if (xSemaphoreTake(s_play_mutex, portMAX_DELAY) != pdTRUE) return false;
    s_active = true;
    ESP_LOGI(TAG, "phrase: %s (%d bytes)", b->name, size);
    int n = opus_clip_decode(s_decoder, b->start, size, pcm_writer, NULL);
    s_active = false;
    xSemaphoreGive(s_play_mutex);
    if (n < 0) {
        ESP_LOGE(TAG, "phrase %s decode failed", b->name);
        return false;
    }
    return true;
}

bool phrase_active(void) {
    return s_active;
}
