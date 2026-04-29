// Local-relay WebSocket client.
//
// The duck connects to our Python relay over LAN/ngrok and exchanges raw
// int16 LE PCM @ 16kHz mono in WebSocket *binary* frames. The relay holds
// the slow ElevenAgents WS upstream and does all the JSON+base64+TLS work.
// This file used to do all that on-chip and was unstable; see bambu/STATE.md.
//
// Wire (duck ↔ relay):
//   binary frame, both ways  : raw int16 LE PCM
//   text frame, relay → duck : {"type":"ready"} | {"type":"interruption"}
//   text frame, duck → relay : reserved (currently unused)
#include "agent.h"
#include "audio.h"
#include "config.h"

#include <stdio.h>
#include <string.h>

#include <esp_heap_caps.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <esp_websocket_client.h>
#include <freertos/FreeRTOS.h>
#include <freertos/stream_buffer.h>
#include <freertos/task.h>

static const char *TAG = "agent";

static esp_websocket_client_handle_t s_ws = NULL;
static volatile bool s_session_active = false;
static volatile bool s_agent_speaking = false;
static volatile int64_t s_last_audio_ms = 0;

static StreamBufferHandle_t s_spk_stream = NULL;
static StreamBufferHandle_t s_mic_stream = NULL;

// ---- inbound handling ----

static void on_text(const char *json, size_t len) {
    // Cheap substring sniff — relay only sends two known control messages,
    // no need for a full JSON parser on the hot path.
    if (memmem(json, len, "interruption", 12) != NULL) {
        // Drop any pending agent speaker output so the duck stops mid-word.
        // Mic stays on (it never went off).
        if (s_spk_stream) xStreamBufferReset(s_spk_stream);
        ESP_LOGI(TAG, "rx interruption");
    } else if (memmem(json, len, "ready", 5) != NULL) {
        ESP_LOGI(TAG, "session ready");
        audio_mic_enable(true);
    }
}

static void on_binary(const uint8_t *data, size_t len, int payload_offset, int payload_len) {
    // PCM audio chunk from agent. Mark agent_speaking so mic_task zeros out
    // its frames — frames still flow upstream (keeps session alive) but
    // don't carry the speaker's own voice as fake user input.
    s_agent_speaking = true;
    s_last_audio_ms = esp_timer_get_time() / 1000;
    size_t sent = xStreamBufferSend(s_spk_stream, data, len, pdMS_TO_TICKS(50));
    if (sent < len) {
        ESP_LOGW(TAG, "spk stream full, dropped %u bytes", (unsigned)(len - sent));
    }
}

// ---- WebSocket event callback ----

static void ws_event_handler(void *handler_args, esp_event_base_t base,
                              int32_t event_id, void *event_data) {
    esp_websocket_event_data_t *d = event_data;
    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            ESP_LOGI(TAG, "ws connected to relay");
            break;
        case WEBSOCKET_EVENT_DATA:
            if (d->op_code == 1) {
                on_text((const char *)d->data_ptr, d->data_len);
            } else if (d->op_code == 2 || d->op_code == 0) {
                on_binary((const uint8_t *)d->data_ptr, d->data_len,
                          d->payload_offset, d->payload_len);
            }
            break;
        case WEBSOCKET_EVENT_DISCONNECTED:
        case WEBSOCKET_EVENT_CLOSED:
            ESP_LOGI(TAG, "ws closed");
            s_session_active = false;
            break;
    }
}

// ---- mic capture task: I2S → ring buffer (DMA-paced, must NOT block) ----

static void mic_task(void *arg) {
    int16_t pcm[AUDIO_FRAME_SAMPLES];
    int reads_total = 0, frames_pushed = 0, frames_silenced = 0;
    int64_t last_log_ms = esp_timer_get_time() / 1000;
    while (s_session_active) {
        size_t n = audio_mic_read(pcm, AUDIO_FRAME_SAMPLES, 50);
        reads_total++;
        if (n == 0) {
            vTaskDelay(1);
        } else {
            // While the agent is speaking, the mic is hearing the speaker
            // through the air (= acoustic feedback). Zero out the samples
            // so frames keep flowing upstream (server expects them to keep
            // session alive) but don't carry the agent's own voice back as
            // fake user input.
            if (s_agent_speaking) {
                memset(pcm, 0, n * sizeof(int16_t));
                frames_silenced++;
            }
            size_t bytes = n * sizeof(int16_t);
            size_t sent = xStreamBufferSend(s_mic_stream, pcm, bytes, 0);
            if (sent < bytes) {
                ESP_LOGW(TAG, "mic stream full, resetting");
                xStreamBufferReset(s_mic_stream);
            } else {
                frames_pushed++;
            }
        }
        int64_t now = esp_timer_get_time() / 1000;
        if (now - last_log_ms > 2000) {
            ESP_LOGI(TAG, "mic: %d reads, %d frames pushed (%d silenced) in %lldms",
                     reads_total, frames_pushed, frames_silenced, now - last_log_ms);
            reads_total = 0; frames_pushed = 0; frames_silenced = 0;
            last_log_ms = now;
        }
    }
    vTaskDelete(NULL);
}

// ---- WS send task: ring buffer → binary WS frame (no JSON, no base64) ----

static void ws_send_task(void *arg) {
    // 80ms chunks — small enough to amortize each TLS write, big enough
    // to keep WS overhead down. With binary frames + no encoding work, even
    // 80ms is comfortably real-time on this chip.
    static int16_t pcm[AUDIO_FRAME_SAMPLES * 4];
    int chunk_count = 0;
    while (s_session_active) {
        size_t n = xStreamBufferReceive(s_mic_stream, pcm, sizeof(pcm),
                                        pdMS_TO_TICKS(500));
        if (n != sizeof(pcm)) continue;  // only send full chunks
        if (!s_ws) continue;
        // Binary WS frame — raw bytes, server side reassembles.
        esp_websocket_client_send_bin(s_ws, (const char *)pcm, n, portMAX_DELAY);
        if ((++chunk_count % 12) == 0) {
            ESP_LOGI(TAG, "tx chunk #%d: %u bytes (80ms)", chunk_count, (unsigned)n);
        }
    }
    vTaskDelete(NULL);
}

// ---- speaker drain task: ring buffer → I2S ----

static void spk_task(void *arg) {
    int16_t buf[256];
    while (s_session_active) {
        size_t n = xStreamBufferReceive(s_spk_stream, buf, sizeof(buf), pdMS_TO_TICKS(100));
        if (n > 0) {
            audio_spk_write(buf, n / sizeof(int16_t));
        }
    }
    vTaskDelete(NULL);
}

// ---- mute timer: re-enable mic 500ms after last agent audio chunk ----

static void mute_timer_task(void *arg) {
    // Two conditions BOTH must be true to clear s_agent_speaking:
    //   1. No new audio chunk arrived in the last 500ms.
    //   2. The speaker stream has drained to near-empty (< 1KB ≈ 30ms).
    // Without (2), we clear too early — the spk DMA still has seconds of
    // buffered audio queued, the speaker keeps playing, and the mic picks
    // up that playback as fake user input.
    while (s_session_active) {
        vTaskDelay(pdMS_TO_TICKS(100));
        if (s_agent_speaking) {
            int64_t now = esp_timer_get_time() / 1000;
            bool quiet_long_enough = (now - s_last_audio_ms > 500);
            bool spk_drained = (s_spk_stream == NULL ||
                                xStreamBufferBytesAvailable(s_spk_stream) < 1024);
            if (quiet_long_enough && spk_drained) {
                s_agent_speaking = false;
                ESP_LOGI(TAG, "mute timer: agent done speaking, mic un-silenced");
            }
        }
    }
    vTaskDelete(NULL);
}

// ---- public ----

esp_err_t agent_run_session(const char *unused_signed_url) {
    (void)unused_signed_url;  // kept for backwards-compat with main.c

    // 80ms chunks at 16kHz mono int16 = 320*4 samples * 2 bytes = 2560 bytes
    const size_t MIC_CHUNK_BYTES = AUDIO_FRAME_SAMPLES * 4 * sizeof(int16_t);
    s_mic_stream = xStreamBufferCreate(16 * 1024, MIC_CHUNK_BYTES);
    if (!s_mic_stream) return ESP_ERR_NO_MEM;
    // ElevenLabs sends agent audio faster than realtime (it pre-buffers
    // entire utterances). For a 10s sentence ~320KB arrives at once. Spk
    // task drains at 16kHz playback rate. 512KB ≈ 16s of audio buffered.
    s_spk_stream = xStreamBufferCreateWithCaps(512 * 1024, 1,
                                                MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!s_spk_stream) {
        vStreamBufferDelete(s_mic_stream); s_mic_stream = NULL;
        return ESP_ERR_NO_MEM;
    }

    esp_websocket_client_config_t cfg = {
        .uri = RELAY_WS_URL,  // ws:// via ngrok TCP tunnel — no TLS on chip
        .buffer_size = 16384,
        .reconnect_timeout_ms = 5000,
        .network_timeout_ms = 10000,
    };
    s_ws = esp_websocket_client_init(&cfg);
    if (!s_ws) {
        vStreamBufferDelete(s_mic_stream); s_mic_stream = NULL;
        vStreamBufferDeleteWithCaps(s_spk_stream); s_spk_stream = NULL;
        return ESP_FAIL;
    }

    esp_websocket_register_events(s_ws, WEBSOCKET_EVENT_ANY, ws_event_handler, NULL);
    s_session_active = true;
    s_agent_speaking = false;
    s_last_audio_ms = 0;
    audio_mic_enable(false);
    esp_websocket_client_start(s_ws);

    xTaskCreate(mic_task,        "mic",        4096, NULL, 7, NULL);
    xTaskCreate(ws_send_task,    "ws_send",    8192, NULL, 5, NULL);
    xTaskCreate(spk_task,        "spk",        4096, NULL, 6, NULL);
    xTaskCreate(mute_timer_task, "mute_timer", 4096, NULL, 4, NULL);

    while (s_session_active) {
        vTaskDelay(pdMS_TO_TICKS(200));
    }
    audio_mic_enable(false);
    vTaskDelay(pdMS_TO_TICKS(200));
    esp_websocket_client_stop(s_ws);
    esp_websocket_client_destroy(s_ws);
    s_ws = NULL;
    vStreamBufferDelete(s_mic_stream);
    s_mic_stream = NULL;
    vStreamBufferDeleteWithCaps(s_spk_stream);
    s_spk_stream = NULL;
    return ESP_OK;
}
