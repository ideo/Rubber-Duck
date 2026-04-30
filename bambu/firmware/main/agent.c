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
#include "servo.h"

#include <stdio.h>
#include <string.h>

#include <esp_heap_caps.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <esp_websocket_client.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
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
    servo_set_speaking(true);
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
            // Feed envelope to servo for beak movement before playing.
            servo_feed_audio_envelope(buf, n / sizeof(int16_t));
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
                servo_set_speaking(false);
                ESP_LOGI(TAG, "mute timer: agent done speaking, mic un-silenced");
            }
        }
    }
    vTaskDelete(NULL);
}

// ---- public ----

// Percent-encode a UTF-8 string into out (zero-terminated). Used to embed
// notification headlines in the /ws/duck?first_message= query param.
static void url_escape(const char *src, char *out, size_t out_cap) {
    static const char hex[] = "0123456789ABCDEF";
    size_t o = 0;
    for (size_t i = 0; src[i] && o + 4 < out_cap; i++) {
        unsigned char c = (unsigned char)src[i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~') {
            out[o++] = c;
        } else {
            out[o++] = '%';
            out[o++] = hex[c >> 4];
            out[o++] = hex[c & 0xf];
        }
    }
    out[o] = '\0';
}

esp_err_t agent_run_session(const char *first_message) {
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

    // Compose the URL — append ?first_message=<urlescaped> if we have one.
    static char url[1024];
    if (first_message && first_message[0]) {
        char esc[600];
        url_escape(first_message, esc, sizeof(esc));
        snprintf(url, sizeof(url), "%s?first_message=%s", RELAY_DUCK_URL, esc);
    } else {
        snprintf(url, sizeof(url), "%s", RELAY_DUCK_URL);
    }

    esp_websocket_client_config_t cfg = {
        .uri = url,  // ws:// via ngrok TCP tunnel — no TLS on chip
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
    // Session over — clear all the speaking-state flags so the servo and
    // mic logic don't think the agent is still mid-utterance.
    s_agent_speaking = false;
    servo_set_speaking(false);
    audio_mic_enable(false);
    // Stop the WS client first so no new data lands in the streams.
    esp_websocket_client_stop(s_ws);
    esp_websocket_client_destroy(s_ws);
    s_ws = NULL;
    // Then let the spawned tasks (mic, ws_send, spk, mute_timer) finish their
    // current loop iteration and exit on s_session_active=false. Each blocks
    // up to ~100ms in xStreamBufferReceive — 600ms is comfortable headroom
    // before we delete the streams underneath them. (Was 200ms; race caused
    // a stream_buffer assert.)
    vTaskDelay(pdMS_TO_TICKS(600));
    vStreamBufferDelete(s_mic_stream);
    s_mic_stream = NULL;
    vStreamBufferDeleteWithCaps(s_spk_stream);
    s_spk_stream = NULL;
    return ESP_OK;
}

// ---------------------------------------------------------------------------
// Notification channel: long-lived /ws/notify connection.
//
// Receives text frames like {"type":"notify","headline":"..."} and triggers
// a one-shot session via agent_run_session(headline). The session pre-empts
// nothing — if the user is already in a session (button pressed), the
// notification waits until the current session ends.
// ---------------------------------------------------------------------------

static esp_websocket_client_handle_t s_notify_ws = NULL;
// Pending headline copied off the WS event thread for the notify task to
// pick up — keeps the WS event handler non-blocking.
static char s_pending_headline[600];
static volatile bool s_pending_notify = false;
static volatile bool s_notify_reconnect_pending = false;
static SemaphoreHandle_t s_notify_busy = NULL;  // serialize against active session

static void notify_ws_event(void *handler_args, esp_event_base_t base,
                             int32_t event_id, void *event_data) {
    esp_websocket_event_data_t *d = event_data;
    if (event_id == WEBSOCKET_EVENT_DATA) {
        ESP_LOGI(TAG, "notify ws data: op_code=%d len=%d", d->op_code, d->data_len);
        if (d->op_code == 1 || d->op_code == 0) {
            // Log first 80 bytes of payload for debugging
            char preview[81];
            int n = d->data_len < 80 ? d->data_len : 80;
            memcpy(preview, d->data_ptr, n);
            preview[n] = '\0';
            ESP_LOGI(TAG, "notify text preview: %s", preview);

            const char *p = memmem(d->data_ptr, d->data_len, "\"headline\"", 10);
            if (!p) {
                ESP_LOGW(TAG, "notify: no headline field found");
                return;
            }
            // Skip past `"headline"` then whitespace + `:` + whitespace + `"`.
            const char *cursor = p + 10;
            const char *limit = (const char *)d->data_ptr + d->data_len;
            while (cursor < limit && (*cursor == ' ' || *cursor == ':' || *cursor == '\t')) cursor++;
            if (cursor >= limit || *cursor != '"') {
                ESP_LOGW(TAG, "notify: malformed headline value");
                return;
            }
            const char *start = cursor + 1;
            const char *end = (const char *)memchr(start, '"', limit - start);
            if (!end) {
                ESP_LOGW(TAG, "notify: unterminated headline");
                return;
            }
            size_t len = end - start;
            if (len >= sizeof(s_pending_headline)) len = sizeof(s_pending_headline) - 1;
            memcpy(s_pending_headline, start, len);
            s_pending_headline[len] = '\0';
            s_pending_notify = true;
            ESP_LOGI(TAG, "notify rx headline: %s", s_pending_headline);
        }
    } else if (event_id == WEBSOCKET_EVENT_CONNECTED) {
        ESP_LOGI(TAG, "notify channel connected to %s", RELAY_NOTIFY_URL);
    } else if (event_id == WEBSOCKET_EVENT_DISCONNECTED ||
               event_id == WEBSOCKET_EVENT_CLOSED) {
        ESP_LOGI(TAG, "notify channel closed — will reconnect");
        // Mark for reconnect; the notify_task loop kicks the client.
        s_notify_reconnect_pending = true;
    } else if (event_id == WEBSOCKET_EVENT_ERROR) {
        ESP_LOGE(TAG, "notify channel error");
        s_notify_reconnect_pending = true;
    }
}

static void notify_task(void *arg) {
    esp_websocket_client_config_t cfg = {
        .uri = RELAY_NOTIFY_URL,
        .reconnect_timeout_ms = 5000,
        .network_timeout_ms = 10000,
        .buffer_size = 2048,
    };
    s_notify_ws = esp_websocket_client_init(&cfg);
    if (!s_notify_ws) {
        ESP_LOGE(TAG, "notify ws init failed");
        vTaskDelete(NULL);
        return;
    }
    esp_websocket_register_events(s_notify_ws, WEBSOCKET_EVENT_ANY, notify_ws_event, NULL);
    esp_websocket_client_start(s_notify_ws);

    while (1) {
        if (s_pending_notify) {
            s_pending_notify = false;
            // Wait for any current session to end before opening a new one.
            xSemaphoreTake(s_notify_busy, portMAX_DELAY);
            char headline[sizeof(s_pending_headline)];
            strncpy(headline, s_pending_headline, sizeof(headline));
            ESP_LOGI(TAG, "starting session from notification");
            agent_run_session(headline);
            xSemaphoreGive(s_notify_busy);
        }
        // Reconnect if the channel got closed (relay restart, network blip).
        if (s_notify_reconnect_pending) {
            s_notify_reconnect_pending = false;
            vTaskDelay(pdMS_TO_TICKS(2000));  // back-off so we don't hammer
            ESP_LOGI(TAG, "notify channel reconnecting");
            esp_websocket_client_stop(s_notify_ws);
            esp_websocket_client_start(s_notify_ws);
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

esp_err_t notify_task_start(void) {
    if (s_notify_busy == NULL) {
        s_notify_busy = xSemaphoreCreateMutex();
        xSemaphoreGive(s_notify_busy);
    }
    xTaskCreate(notify_task, "notify", 6144, NULL, 4, NULL);
    return ESP_OK;
}
