#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// C wrapper around the esphome/micro-opus component's OggOpusDecoder
// (a C++ class). Decouples the rest of the firmware (which is C) from
// the C++ surface. One decoder instance is enough for our use — the
// chip plays at most one phrase at a time, and the wrapper resets
// stream state between clips so the same decoder can be reused.
//
// Why a wrapper at all: micro-opus is a header-only C++ library;
// linking it into our C-only modules without this wrapper would mean
// renaming the .c sources to .cpp and pulling C++ runtime quirks
// (name mangling, exception unwinding) into the rest of the firmware.
// One small .cpp file isolates that.
//
// Output is always 16 kHz mono int16 PCM, matching the chip's I2S TX
// configuration. Caller passes a writer callback that gets each
// decoded PCM frame (~20 ms / 320 samples per Opus frame at 16 kHz).

#ifdef __cplusplus
extern "C" {
#endif

typedef struct opus_clip_decoder opus_clip_decoder_t;

// Per-frame writer. `samples` is mono int16 PCM, `count` is the
// number of int16 samples in this frame.
typedef void (*opus_pcm_writer_fn)(void *ctx,
                                    const int16_t *samples,
                                    unsigned count);

// Allocate a decoder instance in PSRAM. ~140 KB on first use; cheap
// to construct, expensive to drop.
opus_clip_decoder_t *opus_clip_decoder_create(void);

// Free decoder + its PSRAM working memory.
void opus_clip_decoder_destroy(opus_clip_decoder_t *dec);

// Decode one Ogg-Opus clip end-to-end. Resets stream state at start
// so the same instance can be reused across clips. Calls writer for
// every PCM frame (typically every 20 ms of audio = 320 samples).
// Returns total samples written, or -1/-2 on error.
int opus_clip_decode(opus_clip_decoder_t *dec,
                     const uint8_t *data, int size,
                     opus_pcm_writer_fn writer, void *ctx);

#ifdef __cplusplus
}
#endif
