// Single .cpp glue file isolating C++ <-> C boundary for the
// esphome/micro-opus header-only library. Wraps OggOpusDecoder in a
// stable C ABI declared in opus_decoder.h. See the header for
// rationale.
//
// Memory: the decoder's working buffers (~140 KB total) live in
// PSRAM since (a) we have plenty of it on the ESP32-S3 and (b)
// keeping internal RAM free helps WiFi/MQTT throughput.

#include "opus_decoder.h"
#include "micro_opus/ogg_opus_decoder.h"

#include "esp_heap_caps.h"
#include "esp_log.h"

#include <cstring>
#include <new>

static const char *TAG = "opus_dec";

// Max Opus frame at 16 kHz mono is 120 ms × 16k = 1920 samples =
// 3840 bytes. Round up to 4 KB. Held inside the decoder struct so
// allocation matches lifetime.
static constexpr size_t PCM_BUF_BYTES = 4096;

struct opus_clip_decoder {
    micro_opus::OggOpusDecoder dec;
    int16_t pcm_buf[PCM_BUF_BYTES / sizeof(int16_t)];
    opus_clip_decoder()
        : dec(/*enable_crc=*/false, /*sample_rate=*/16000, /*channels=*/1) {}
};

extern "C" opus_clip_decoder_t *opus_clip_decoder_create(void) {
    void *mem = heap_caps_malloc(sizeof(opus_clip_decoder_t),
                                  MALLOC_CAP_SPIRAM);
    if (!mem) {
        ESP_LOGE(TAG, "alloc opus_clip_decoder wrapper failed");
        return nullptr;
    }
    return new (mem) opus_clip_decoder_t();
}

extern "C" void opus_clip_decoder_destroy(opus_clip_decoder_t *d) {
    if (!d) return;
    d->~opus_clip_decoder();
    heap_caps_free(d);
}

extern "C" int opus_clip_decode(opus_clip_decoder_t *d,
                                 const uint8_t *data, int size,
                                 opus_pcm_writer_fn writer, void *ctx) {
    if (!d || !data || size <= 0 || !writer) return -1;
    d->dec.reset();

    const uint8_t *ptr = data;
    int remaining = size;
    int total_samples = 0;

    while (remaining > 0) {
        size_t consumed = 0;
        size_t samples = 0;
        auto r = d->dec.decode(ptr, (size_t)remaining,
                                reinterpret_cast<uint8_t *>(d->pcm_buf),
                                sizeof(d->pcm_buf),
                                consumed, samples);
        if (r != micro_opus::OGG_OPUS_OK) {
            ESP_LOGE(TAG, "decode err %d after %d samples (rem=%d)",
                     (int)r, total_samples, remaining);
            return -2;
        }
        if (samples > 0) {
            writer(ctx, d->pcm_buf, (unsigned)samples);
            total_samples += (int)samples;
        }
        // No progress means clean end-of-stream (decoder emitted all
        // it could from the buffer it has).
        if (consumed == 0 && samples == 0) break;
        ptr += consumed;
        remaining -= (int)consumed;
    }
    return total_samples;
}
