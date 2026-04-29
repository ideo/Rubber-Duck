// ElevenAgents WebSocket client.
//
// Protocol (PCM 16kHz LE mono, base64-encoded):
//   client → server  : conversation_initiation_client_data, user_audio_chunk, pong
//   server → client  : conversation_initiation_metadata, audio, ping, interruption,
//                       agent_response, user_transcript, client_tool_call
//
// We don't implement client_tool_call here — Server Tools (webhooks) call the
// relay directly from ElevenAgents's side, no firmware involvement.
#include "agent.h"
#include "audio.h"
#include "config.h"

#include <stdio.h>
#include <string.h>

#include <cJSON.h>
#include <esp_crt_bundle.h>
#include <esp_log.h>
#include <esp_websocket_client.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <mbedtls/base64.h>

static const char *TAG = "agent";

static esp_websocket_client_handle_t s_ws = NULL;
static volatile bool s_session_active = false;
static volatile bool s_agent_speaking = false;

// ---- helpers ----

static void send_json(cJSON *root) {
    char *s = cJSON_PrintUnformatted(root);
    if (s && s_ws) {
        esp_websocket_client_send_text(s_ws, s, strlen(s), portMAX_DELAY);
    }
    cJSON_free(s);
}

static void send_init(void) {
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "type", "conversation_initiation_client_data");
    cJSON *cfg = cJSON_AddObjectToObject(root, "conversation_config_override");
    cJSON *agent = cJSON_AddObjectToObject(cfg, "agent");
    cJSON_AddStringToObject(agent, "language", "en");
    send_json(root);
    cJSON_Delete(root);
}

static void send_audio_chunk(const int16_t *pcm, size_t samples) {
    size_t in_len = samples * sizeof(int16_t);
    size_t b64_cap = ((in_len + 2) / 3) * 4 + 8;
    char *b64 = malloc(b64_cap);
    if (!b64) return;
    size_t b64_len = 0;
    if (mbedtls_base64_encode((unsigned char *)b64, b64_cap, &b64_len,
                              (const unsigned char *)pcm, in_len) != 0) {
        free(b64);
        return;
    }
    b64[b64_len] = '\0';
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "user_audio_chunk", b64);
    send_json(root);
    cJSON_Delete(root);
    free(b64);
}

static void send_pong(int event_id) {
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "type", "pong");
    cJSON_AddNumberToObject(root, "event_id", event_id);
    send_json(root);
    cJSON_Delete(root);
}

// ---- inbound event handling ----

static void play_audio_event(cJSON *audio_event) {
    cJSON *b64_node = cJSON_GetObjectItem(audio_event, "audio_base_64");
    if (!cJSON_IsString(b64_node)) return;
    const char *b64 = b64_node->valuestring;
    size_t b64_len = strlen(b64);
    size_t pcm_cap = (b64_len / 4) * 3 + 4;
    unsigned char *pcm = malloc(pcm_cap);
    if (!pcm) return;
    size_t pcm_len = 0;
    if (mbedtls_base64_decode(pcm, pcm_cap, &pcm_len,
                              (const unsigned char *)b64, b64_len) == 0) {
        s_agent_speaking = true;
        audio_mic_enable(false);  // mute mic while talking back (cheap echo control)
        audio_spk_write((const int16_t *)pcm, pcm_len / sizeof(int16_t));
    }
    free(pcm);
}

static void handle_event(const char *json, size_t len) {
    cJSON *root = cJSON_ParseWithLength(json, len);
    if (!root) return;
    cJSON *type = cJSON_GetObjectItem(root, "type");
    const char *t = cJSON_IsString(type) ? type->valuestring : "";

    if (strcmp(t, "ping") == 0) {
        cJSON *evt = cJSON_GetObjectItem(root, "ping_event");
        cJSON *id = evt ? cJSON_GetObjectItem(evt, "event_id") : NULL;
        send_pong(cJSON_IsNumber(id) ? (int)id->valuedouble : 0);
    } else if (strcmp(t, "audio") == 0) {
        cJSON *audio = cJSON_GetObjectItem(root, "audio_event");
        if (audio) play_audio_event(audio);
    } else if (strcmp(t, "interruption") == 0) {
        // User cut in: stop talking. (Speaker DMA buffer will drain naturally;
        // for a hard cut we'd flush the I2S channel.)
        s_agent_speaking = false;
        audio_mic_enable(true);
    } else if (strcmp(t, "agent_response") == 0 ||
               strcmp(t, "user_transcript") == 0) {
        cJSON *resp = cJSON_GetObjectItem(root, "agent_response_event");
        if (!resp) resp = cJSON_GetObjectItem(root, "user_transcription_event");
        cJSON *text = resp ? cJSON_GetObjectItem(resp, "agent_response") : NULL;
        if (!text) text = resp ? cJSON_GetObjectItem(resp, "user_transcript") : NULL;
        if (cJSON_IsString(text)) {
            ESP_LOGI(TAG, "[%s] %s", t, text->valuestring);
        }
    } else if (strcmp(t, "conversation_initiation_metadata") == 0) {
        ESP_LOGI(TAG, "session ready");
        audio_mic_enable(true);
    }
    cJSON_Delete(root);
}

// ---- WebSocket event callback ----

static void ws_event_handler(void *handler_args, esp_event_base_t base,
                              int32_t event_id, void *event_data) {
    esp_websocket_event_data_t *d = event_data;
    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            ESP_LOGI(TAG, "ws connected");
            send_init();
            break;
        case WEBSOCKET_EVENT_DATA:
            if (d->op_code == 1 /* text */) {
                handle_event((const char *)d->data_ptr, d->data_len);
            }
            break;
        case WEBSOCKET_EVENT_DISCONNECTED:
        case WEBSOCKET_EVENT_CLOSED:
            ESP_LOGI(TAG, "ws closed");
            s_session_active = false;
            break;
    }
}

// ---- mic pump task ----

static void mic_task(void *arg) {
    int16_t pcm[AUDIO_FRAME_SAMPLES];
    while (s_session_active) {
        size_t n = audio_mic_read(pcm, AUDIO_FRAME_SAMPLES, 50);
        if (n > 0 && !s_agent_speaking) {
            send_audio_chunk(pcm, n);
        }
    }
    vTaskDelete(NULL);
}

// ---- public ----

esp_err_t agent_run_session(const char *signed_url) {
    esp_websocket_client_config_t cfg = {
        .uri = signed_url,
        .crt_bundle_attach = esp_crt_bundle_attach,
        .buffer_size = 4096,
        .reconnect_timeout_ms = 5000,
        .network_timeout_ms = 10000,
    };
    s_ws = esp_websocket_client_init(&cfg);
    if (!s_ws) return ESP_FAIL;

    esp_websocket_register_events(s_ws, WEBSOCKET_EVENT_ANY, ws_event_handler, NULL);
    s_session_active = true;
    s_agent_speaking = false;
    audio_mic_enable(false);
    esp_websocket_client_start(s_ws);

    xTaskCreate(mic_task, "mic", 4096, NULL, 5, NULL);

    while (s_session_active) {
        vTaskDelay(pdMS_TO_TICKS(200));
    }
    audio_mic_enable(false);
    esp_websocket_client_stop(s_ws);
    esp_websocket_client_destroy(s_ws);
    s_ws = NULL;
    return ESP_OK;
}
