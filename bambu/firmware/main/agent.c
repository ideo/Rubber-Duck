// Relay WebSocket client.
//
// The duck connects to the Python relay over wss:// (TLS validated
// against the bundled Mozilla NSS root list — see crt_bundle_attach
// below) and exchanges raw int16 LE PCM @ 16kHz mono in WebSocket
// *binary* frames. The relay holds the slow ElevenAgents WS upstream
// and does all the JSON+base64 audio translation. This file used to
// do that on-chip and was unstable; see bambu/STATE.md.
//
// Wire (duck ↔ relay):
//   binary frame, both ways  : raw int16 LE PCM
//   text frame, relay → duck : {"type":"ready"} | {"type":"interruption"}
//   text frame, duck → relay : reserved (currently unused)
#include "agent.h"
#include "audio.h"
#include "config.h"
#include "duck_id.h"
#include "servo.h"

#include <stdio.h>
#include <string.h>

#include <esp_crt_bundle.h>
#include <esp_heap_caps.h>
#include <esp_log.h>
#include <esp_timer.h>
#include <esp_websocket_client.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/stream_buffer.h>
#include <freertos/task.h>

static const char *TAG = "agent";

static esp_websocket_client_handle_t s_ws = NULL;
static volatile bool s_session_active = false;
static volatile bool s_agent_speaking = false;
static volatile int64_t s_last_audio_ms = 0;

static StreamBufferHandle_t s_spk_stream = NULL;
static StreamBufferHandle_t s_mic_stream = NULL;

// State accessors for wake.c (tap-to-wake gate).
bool agent_session_active(void) { return s_session_active; }
bool agent_speaking(void)        { return s_agent_speaking; }

// ---- inbound handling ----

static void on_text(const char *json, size_t len) {
    // Substring match against the FULL type-tag literal so a future
    // control message that happens to contain "interruption" or
    // "ready" inside another field can't trip the wrong handler.
    // No JSON parser on the hot path — the wire format is fixed by
    // duck_proxy.py and well-formed; a literal-tag match is enough.
    if (memmem(json, len, "\"type\":\"interruption\"", 21) != NULL) {
        // Drop any pending agent speaker output so the duck stops mid-word.
        // Mic stays on (it never went off).
        if (s_spk_stream) xStreamBufferReset(s_spk_stream);
        ESP_LOGI(TAG, "rx interruption");
    } else if (memmem(json, len, "\"type\":\"ready\"", 14) != NULL) {
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
// notification fields in the /ws/duck?event=&subtask= query params.
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

esp_err_t agent_run_session(const char *event, const char *subtask) {
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

    // Compose the URL. Notification sessions append ?event=<type>&subtask=<name>
    // so the relay can build a "Printer notice: ..." user_message and inject
    // it after the agent init metadata. Button press = bare URL.
    static char url[1024];
    if (event && event[0]) {
        char esc_event[64];
        url_escape(event, esc_event, sizeof(esc_event));
        if (subtask && subtask[0]) {
            char esc_subtask[600];
            url_escape(subtask, esc_subtask, sizeof(esc_subtask));
            snprintf(url, sizeof(url), "%s?event=%s&subtask=%s",
                     RELAY_DUCK_URL, esc_event, esc_subtask);
        } else {
            snprintf(url, sizeof(url), "%s?event=%s", RELAY_DUCK_URL, esc_event);
        }
    } else {
        snprintf(url, sizeof(url), "%s", RELAY_DUCK_URL);
    }

    // Identify ourselves to the relay so it routes our session to our
    // duck row (multi-tenant — see bambu/docs/MULTI-TENANT-REQ.md). The
    // relay's compat shim still resolves to a default duck if the
    // header is absent, but we always send it so the relay logs which
    // duck is talking even on shared deployments.
    char ws_headers[64];
    snprintf(ws_headers, sizeof(ws_headers),
             "X-Duck-Id: %s\r\n", duck_id_get());

    esp_websocket_client_config_t cfg = {
        .uri = url,  // wss:// to Fly.io edge (Let's Encrypt cert)
        .buffer_size = 16384,
        .reconnect_timeout_ms = 5000,
        .network_timeout_ms = 10000,
        .headers = ws_headers,
        // Validate the relay's cert against the bundled Mozilla NSS
        // root list (CONFIG_MBEDTLS_CERTIFICATE_BUNDLE_DEFAULT_FULL).
        // No PEM management on the chip; works against any
        // public-CA-fronted endpoint. ESP-IDF v5.3+ mbedTLS 3.5+
        // handles Let's Encrypt's ECDSA-SHA384 chains cleanly.
        .crt_bundle_attach = esp_crt_bundle_attach,
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
// Receives text frames like {"type":"notify","event":"finish","subtask":"..."}
// and triggers a one-shot session via agent_run_session(event, subtask). The
// relay turns those two fields into a "Printer notice: ..." user_message so
// the agent improvises the announcement in voice. We never send a free-text
// headline through the chip — keeps this naive parser safe from JSON escapes
// (em dashes etc) that previously survived round-trip and got TTSed verbatim.
// The session pre-empts nothing — if a session is already open (button), the
// notification waits until it ends.
// ---------------------------------------------------------------------------

static esp_websocket_client_handle_t s_notify_ws = NULL;
static volatile bool s_notify_ws_connected = false;

// Pending bambu_login response — set by notify_ws_event when the relay
// replies, consumed by bambu_login_via_ws. One slot is enough; we
// serialize login attempts in the wizard.
static SemaphoreHandle_t s_login_done = NULL;
static volatile bambu_login_ws_result_t s_login_last_result = BAMBU_LOGIN_WS_TIMEOUT;

// Same shape for set_eleven_creds. Allocated lazily inside the sender;
// declared here so notify_ws_event (which fires above the sender in
// the file) can give the semaphore on ack arrival.
static SemaphoreHandle_t s_eleven_done = NULL;
static volatile bool s_eleven_last_ok = false;

// And for set_printers (Phase B of #41).
static SemaphoreHandle_t s_set_printers_done = NULL;
static volatile bool s_set_printers_last_ok = false;

// Multi-printer info captured from bambu_login_result. Used by the
// captive portal to render the checkbox picker. Populated on the
// notify-ws thread, read on the wizard worker thread — strings are
// only mutated when no reader is active (ensured by the wizard's
// state machine: parse happens during LOGGING_IN → PICK_PRINTERS
// transition, reads happen after) so no mutex needed for the simple
// hand-off.
static bambu_printer_info_t s_printers[BAMBU_MAX_PRINTERS];
static int s_printers_count = 0;

int bambu_printers_count(void) { return s_printers_count; }

bool bambu_printer_info(int idx, bambu_printer_info_t *out) {
    if (idx < 0 || idx >= s_printers_count || !out) return false;
    *out = s_printers[idx];
    return true;
}

// Queue of pending notifications. Single-slot used to lose events when two
// arrived back-to-back while a session was active (P0-2 in the agent review).
// 4 deep is comfortable: with the relay's inject-into-active-session path the
// chip queue only fills when offline or between sessions, where 4 is plenty.
//
// TODO(multi-printer): once a duck is linked to a printer (or fleet) via auth
// (#31), dedup queued events by printer_id — the latest event per printer
// should overwrite the previous one (e.g. a "resume" supersedes a queued
// "pause" for the same printer; a queue of pause+resume+pause should collapse
// to just pause). Implementation: walk the queue on insert, drop any earlier
// item with the same printer_id. FreeRTOS QueueHandle_t doesn't support this
// natively — replace with a small linear ring + mutex, or use uxQueueMessages
// / xQueuePeek + xQueueReset to rebuild on insert. Today's single-printer
// hardcode means FIFO is fine.
typedef struct {
    char event[32];
    char subtask[600];
    // TODO: add `char printer_id[32];` for per-printer dedup once available.
} notify_item_t;
#define NOTIFY_QUEUE_DEPTH 4
static QueueHandle_t s_notify_queue = NULL;

// Reconnect is handled entirely by esp_websocket_client's built-in
// reconnect_timeout_ms (see notify_task cfg below). No manual flag, no manual
// stop+start — the IDF library already does it.

// Extract a quoted string value for the given JSON key out of a text payload.
// Bounded, no allocation, no escape decoding — by design. The relay sends
// only ASCII-safe values for "event" and "subtask" (it pre-resolves the
// friendly subtask name on its end), so \uXXXX and \" never appear in the
// fields we read. Pulling in a real JSON parser (cJSON, etc.) would buy us
// nothing for the two-field schema and grow the binary noticeably. Returns
// false if the key was not found or the value couldn't be located.
static bool extract_json_string(const char *data, size_t data_len,
                                  const char *key, char *out, size_t out_cap) {
    char needle[40];
    int nl = snprintf(needle, sizeof(needle), "\"%s\"", key);
    if (nl <= 0 || (size_t)nl >= sizeof(needle)) return false;
    const char *p = memmem(data, data_len, needle, nl);
    if (!p) return false;
    const char *cursor = p + nl;
    const char *limit = data + data_len;
    while (cursor < limit && (*cursor == ' ' || *cursor == ':' || *cursor == '\t')) cursor++;
    if (cursor >= limit || *cursor != '"') return false;
    const char *start = cursor + 1;
    const char *end = (const char *)memchr(start, '"', limit - start);
    if (!end) return false;
    size_t len = end - start;
    if (len >= out_cap) len = out_cap - 1;
    memcpy(out, start, len);
    out[len] = '\0';
    return true;
}

// Tracks the last time we observed a CONNECTED event on the notify
// channel. Watchdog uses this to spot "been disconnected for too long"
// — a known failure mode where IDF's internal auto-reconnect doesn't
// kick in after a server-initiated graceful close (e.g. Fly redeploy).
// Set to "now" on every CONNECTED event so a flapping connection
// keeps resetting the timer; only sustained disconnects trigger the
// watchdog. See #51.
static volatile int64_t s_notify_last_connected_ms = 0;

static inline int64_t notify_now_ms(void) {
    return esp_timer_get_time() / 1000;
}

static void notify_ws_event(void *handler_args, esp_event_base_t base,
                             int32_t event_id, void *event_data) {
    esp_websocket_event_data_t *d = event_data;
    if (event_id == WEBSOCKET_EVENT_CONNECTED) {
        ESP_LOGI(TAG, "notify channel connected to %s", RELAY_NOTIFY_URL);
        s_notify_ws_connected = true;
        s_notify_last_connected_ms = notify_now_ms();
        return;
    } else if (event_id == WEBSOCKET_EVENT_DISCONNECTED ||
               event_id == WEBSOCKET_EVENT_CLOSED) {
        ESP_LOGI(TAG, "notify channel closed — auto-reconnecting (watchdog "
                      "will force-recreate if reconnect stalls)");
        s_notify_ws_connected = false;
        return;
    } else if (event_id == WEBSOCKET_EVENT_ERROR) {
        ESP_LOGE(TAG, "notify channel error (auto-reconnect will retry, "
                      "watchdog will force-recreate if it stalls)");
        return;
    }
    if (event_id == WEBSOCKET_EVENT_DATA) {
        ESP_LOGI(TAG, "notify ws data: op_code=%d len=%d", d->op_code, d->data_len);
        if (d->op_code == 1 || d->op_code == 0) {
            // Log first 80 bytes of payload for debugging
            char preview[81];
            int n = d->data_len < 80 ? d->data_len : 80;
            memcpy(preview, d->data_ptr, n);
            preview[n] = '\0';
            ESP_LOGI(TAG, "notify text preview: %s", preview);

            // Dispatch by message type. Three types today:
            //   "notify"             — printer event (queue → trigger session)
            //   "bambu_login_result" — captive-portal login response
            //   anything else        — log and drop
            char type_field[32] = {0};
            if (extract_json_string(d->data_ptr, d->data_len, "type",
                                     type_field, sizeof(type_field))
                && strcmp(type_field, "bambu_login_result") == 0) {
                // Decode the result. Relay sends:
                //   {"type":"bambu_login_result","ok":true|false,"code":"..."}
                // We sniff the literal substring "true" right after "ok"
                // (avoid pulling in cJSON for one boolean).
                const char *ok_pos = memmem(d->data_ptr, d->data_len, "\"ok\"", 4);
                bool ok_true = false;
                if (ok_pos) {
                    const char *limit = (const char *)d->data_ptr + d->data_len;
                    const char *cursor = ok_pos + 4;
                    while (cursor < limit && (*cursor == ' ' || *cursor == ':' || *cursor == '\t')) cursor++;
                    ok_true = (cursor + 4 <= limit) && memcmp(cursor, "true", 4) == 0;
                }
                if (ok_true) {
                    s_login_last_result = BAMBU_LOGIN_WS_OK;
                    // Phase B of #41 — capture the printer list the
                    // relay sent alongside ok=true so the captive portal
                    // can render the picker. Numbered string fields,
                    // chip already has extract_json_string for those.
                    char count_str[8] = {0};
                    extract_json_string(d->data_ptr, d->data_len,
                                         "printer_count", count_str,
                                         sizeof(count_str));
                    int n = atoi(count_str);
                    if (n > BAMBU_MAX_PRINTERS) n = BAMBU_MAX_PRINTERS;
                    if (n < 0) n = 0;
                    s_printers_count = 0;
                    for (int i = 0; i < n; i++) {
                        char key[24];
                        snprintf(key, sizeof(key), "printer_%d_name", i);
                        bool got_name = extract_json_string(
                            d->data_ptr, d->data_len, key,
                            s_printers[i].name, sizeof(s_printers[i].name));
                        snprintf(key, sizeof(key), "printer_%d_serial", i);
                        bool got_serial = extract_json_string(
                            d->data_ptr, d->data_len, key,
                            s_printers[i].serial,
                            sizeof(s_printers[i].serial));
                        char online_str[4] = {0};
                        snprintf(key, sizeof(key), "printer_%d_online", i);
                        extract_json_string(d->data_ptr, d->data_len, key,
                                             online_str, sizeof(online_str));
                        s_printers[i].online = (online_str[0] == '1');
                        if (got_name && got_serial) s_printers_count++;
                    }
                    ESP_LOGI(TAG, "bambu_login_result: parsed %d printers",
                             s_printers_count);
                } else {
                    char code_field[32] = {0};
                    extract_json_string(d->data_ptr, d->data_len, "code",
                                         code_field, sizeof(code_field));
                    if (strcmp(code_field, "2fa_required") == 0)
                        s_login_last_result = BAMBU_LOGIN_WS_NEED_2FA;
                    else if (strcmp(code_field, "login_failed") == 0)
                        s_login_last_result = BAMBU_LOGIN_WS_BAD_CREDS;
                    else
                        s_login_last_result = BAMBU_LOGIN_WS_BAD_CREDS;
                }
                ESP_LOGI(TAG, "bambu_login_result: %d (ok=%d)",
                         s_login_last_result, ok_true);
                if (s_login_done) xSemaphoreGive(s_login_done);
                return;
            }

            if (strcmp(type_field, "set_eleven_creds_result") == 0) {
                // {"type":"set_eleven_creds_result","ok":true|false,"error":"..."}
                // Same "true" sniff as bambu_login_result above. We don't
                // surface the specific error code today — anything other
                // than ok=true means the captive portal should report a
                // generic "couldn't save voice settings, try again."
                const char *ok_pos = memmem(d->data_ptr, d->data_len, "\"ok\"", 4);
                bool ok_true = false;
                if (ok_pos) {
                    const char *limit = (const char *)d->data_ptr + d->data_len;
                    const char *cursor = ok_pos + 4;
                    while (cursor < limit && (*cursor == ' ' || *cursor == ':' || *cursor == '\t')) cursor++;
                    ok_true = (cursor + 4 <= limit) && memcmp(cursor, "true", 4) == 0;
                }
                s_eleven_last_ok = ok_true;
                ESP_LOGI(TAG, "set_eleven_creds_result: ok=%d", ok_true);
                if (s_eleven_done) xSemaphoreGive(s_eleven_done);
                return;
            }

            if (strcmp(type_field, "set_printers_result") == 0) {
                // Phase B of #41 — relay confirms the narrowed binding
                // is in effect. Same true-sniff as the others above.
                const char *ok_pos = memmem(d->data_ptr, d->data_len, "\"ok\"", 4);
                bool ok_true = false;
                if (ok_pos) {
                    const char *limit = (const char *)d->data_ptr + d->data_len;
                    const char *cursor = ok_pos + 4;
                    while (cursor < limit && (*cursor == ' ' || *cursor == ':' || *cursor == '\t')) cursor++;
                    ok_true = (cursor + 4 <= limit) && memcmp(cursor, "true", 4) == 0;
                }
                s_set_printers_last_ok = ok_true;
                ESP_LOGI(TAG, "set_printers_result: ok=%d", ok_true);
                if (s_set_printers_done) xSemaphoreGive(s_set_printers_done);
                return;
            }

            notify_item_t item = {0};
            if (!extract_json_string(d->data_ptr, d->data_len, "event",
                                      item.event, sizeof(item.event))) {
                ESP_LOGW(TAG, "notify: no event field");
                return;
            }
            // subtask is optional — relay may omit when unknown.
            extract_json_string(d->data_ptr, d->data_len, "subtask",
                                 item.subtask, sizeof(item.subtask));
            // Non-blocking enqueue — drop with a warning if the queue is
            // somehow full. (Would only happen if the chip got >4 events
            // while a button session was running and the relay couldn't
            // inject for some reason.)
            if (s_notify_queue == NULL ||
                xQueueSendToBack(s_notify_queue, &item, 0) != pdTRUE) {
                ESP_LOGW(TAG, "notify queue full, dropping: event=%s subtask=%s",
                         item.event, item.subtask);
            } else {
                ESP_LOGI(TAG, "notify rx queued: event=%s subtask=%s",
                         item.event, item.subtask);
            }
        }
    }
    // CONNECTED / DISCONNECTED / ERROR handled at top of function.
}

// Build + start a fresh notify WS client. Used by both the initial
// notify_task spawn and the watchdog's forced-recreate path. Caller
// is responsible for ensuring s_notify_ws is NULL before calling.
static esp_err_t notify_ws_create_and_start(void) {
    // X-Duck-Id header — chip MAC, used by relay's multi-tenant
    // routing. Long-lived connection so we keep the formatted string
    // alive at file scope.
    static char ws_headers[64];
    snprintf(ws_headers, sizeof(ws_headers),
             "X-Duck-Id: %s\r\n", duck_id_get());

    esp_websocket_client_config_t cfg = {
        .uri = RELAY_NOTIFY_URL,
        .reconnect_timeout_ms = 5000,
        .network_timeout_ms = 10000,
        .buffer_size = 2048,
        .headers = ws_headers,
        .crt_bundle_attach = esp_crt_bundle_attach,
    };
    s_notify_ws = esp_websocket_client_init(&cfg);
    if (!s_notify_ws) {
        ESP_LOGE(TAG, "notify ws init failed");
        return ESP_FAIL;
    }
    esp_websocket_register_events(s_notify_ws, WEBSOCKET_EVENT_ANY,
                                   notify_ws_event, NULL);
    return esp_websocket_client_start(s_notify_ws);
}

// Watchdog: every WATCHDOG_PERIOD_MS, check whether the notify channel
// has been disconnected for longer than WATCHDOG_TIMEOUT_MS. If so,
// destroy the existing WS client and create a fresh one — this is the
// belt-and-suspenders fix for an IDF reconnect path that occasionally
// stalls after a server-initiated graceful close (e.g. Fly redeploy).
// See #51.
//
// Tuning notes:
//   PERIOD = 15s — cheap enough; bounds the worst-case detection delay.
//   TIMEOUT = 60s — gives IDF's own auto-reconnect (5s + backoff) ~10
//     attempts before we intervene. Avoids double-recreate races.
#define NOTIFY_WATCHDOG_PERIOD_MS  15000
#define NOTIFY_WATCHDOG_TIMEOUT_MS 60000

static void notify_watchdog_task(void *arg) {
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(NOTIFY_WATCHDOG_PERIOD_MS));
        if (s_notify_ws_connected) continue;
        int64_t now = notify_now_ms();
        int64_t since = now - s_notify_last_connected_ms;
        if (s_notify_last_connected_ms == 0) {
            // No connection yet since boot — give the initial connect
            // attempt grace, don't intervene if WiFi is just slow.
            continue;
        }
        if (since < NOTIFY_WATCHDOG_TIMEOUT_MS) continue;

        ESP_LOGW(TAG, "notify watchdog: %lld ms since last connect — "
                      "force-recreating WS client",
                 (long long)since);
        if (s_notify_ws) {
            esp_websocket_client_stop(s_notify_ws);
            esp_websocket_client_destroy(s_notify_ws);
            s_notify_ws = NULL;
        }
        if (notify_ws_create_and_start() != ESP_OK) {
            ESP_LOGE(TAG, "notify watchdog: create_and_start failed; "
                          "will retry on next tick");
        } else {
            // Reset the clock so a stuck-pending state doesn't
            // immediately retrigger the watchdog before the new
            // client gets a chance to connect.
            s_notify_last_connected_ms = now;
        }
    }
}

static void notify_task(void *arg) {
    if (notify_ws_create_and_start() != ESP_OK) {
        // Watchdog will retry from here.
        s_notify_ws = NULL;
    }

    notify_item_t item;
    while (1) {
        // Block forever on the queue. agent_run_session itself blocks for the
        // session duration, so this task naturally serializes notify-triggered
        // sessions. (We don't pre-empt button-press sessions — by design, the
        // chip is single-conversation. The relay's user_message inject path
        // handles the "notification arrives during active session" case.)
        if (xQueueReceive(s_notify_queue, &item, portMAX_DELAY) == pdTRUE) {
            ESP_LOGI(TAG, "starting session from notification: event=%s subtask=%s",
                     item.event, item.subtask);
            agent_run_session(item.event, item.subtask[0] ? item.subtask : NULL);
        }
    }
}

esp_err_t notify_task_start(void) {
    static bool s_notify_started = false;
    if (s_notify_started) return ESP_OK;  // idempotent
    if (s_notify_queue == NULL) {
        s_notify_queue = xQueueCreate(NOTIFY_QUEUE_DEPTH, sizeof(notify_item_t));
        if (s_notify_queue == NULL) {
            ESP_LOGE(TAG, "notify queue alloc failed");
            return ESP_ERR_NO_MEM;
        }
    }
    if (s_login_done == NULL) {
        s_login_done = xSemaphoreCreateBinary();
    }
    xTaskCreate(notify_task, "notify", 6144, NULL, 4, NULL);
    // Watchdog independent of notify_task — it keeps running even if
    // notify_task ever exits (it shouldn't, but defensive).
    xTaskCreate(notify_watchdog_task, "notify_wd", 3072, NULL, 3, NULL);
    s_notify_started = true;
    return ESP_OK;
}

bool notify_ws_is_connected(void) {
    return s_notify_ws_connected;
}

bambu_login_ws_result_t bambu_login_via_ws(const char *email,
                                            const char *password,
                                            const char *code,
                                            const char *user_id,
                                            int timeout_ms) {
    if (!s_notify_ws || !s_notify_ws_connected) {
        ESP_LOGW(TAG, "bambu_login_via_ws: notify WS not connected");
        return BAMBU_LOGIN_WS_RELAY_DOWN;
    }
    if (!email || !password) {
        return BAMBU_LOGIN_WS_BAD_CREDS;
    }
    // Defensive: notify_task_start() should always create this before
    // s_notify_ws_connected goes true, but if a caller ever invokes us
    // before the task ran (or after a teardown nulled it), don't crash
    // on xSemaphoreTake. Return a benign timeout-equivalent.
    if (s_login_done == NULL) {
        ESP_LOGE(TAG, "bambu_login_via_ws: s_login_done not initialized");
        return BAMBU_LOGIN_WS_TIMEOUT;
    }
    // Build the JSON body. We hand-roll instead of pulling cJSON into
    // agent.c — the schema is fixed and the values are short. Caller is
    // responsible for sanitizing inputs (provision.c uses url_decode on
    // form-urlencoded fields which produces clean ASCII for our cases).
    char body[512];
    int n = snprintf(body, sizeof(body),
        "{\"type\":\"bambu_login\","
         "\"duck_id\":\"%s\","
         "\"email\":\"%s\","
         "\"password\":\"%s\","
         "\"code\":\"%s\","
         "\"user_id\":\"%s\"}",
        duck_id_get(),
        email, password,
        code ? code : "",
        user_id ? user_id : "");
    if (n <= 0 || n >= (int)sizeof(body)) {
        ESP_LOGE(TAG, "bambu_login body too large or snprintf err: %d", n);
        return BAMBU_LOGIN_WS_BAD_CREDS;
    }

    // Drain any stale signal from a previous attempt.
    xSemaphoreTake(s_login_done, 0);
    s_login_last_result = BAMBU_LOGIN_WS_TIMEOUT;

    int sent = esp_websocket_client_send_text(s_notify_ws, body, n,
                                              pdMS_TO_TICKS(5000));
    if (sent < n) {
        ESP_LOGE(TAG, "bambu_login send failed (sent=%d of %d)", sent, n);
        return BAMBU_LOGIN_WS_RELAY_DOWN;
    }
    ESP_LOGI(TAG, "bambu_login sent (%d bytes), waiting for result", n);

    if (xSemaphoreTake(s_login_done, pdMS_TO_TICKS(timeout_ms)) != pdTRUE) {
        ESP_LOGW(TAG, "bambu_login timeout (%d ms)", timeout_ms);
        return BAMBU_LOGIN_WS_TIMEOUT;
    }
    return s_login_last_result;
}

// Result-tracking for the set_eleven_creds round-trip. Same shape as
// bambu_login: signal `s_eleven_done` when the matching ack lands;
// caller blocks on it. The semaphore is created lazily here on first
// call (no in-flight at boot to worry about) — declarations live up
// at the file-scope statics block since notify_ws_event references
// them too.
bool eleven_creds_send_via_ws(const char *key, const char *agent,
                               int timeout_ms) {
    // User left fields blank → no-op success. They've opted into the
    // relay's default config (shared deployments use the relay's env
    // vars instead of per-duck creds).
    if (!key || !*key || !agent || !*agent) return true;
    if (!s_notify_ws || !s_notify_ws_connected) {
        ESP_LOGW(TAG, "eleven_creds_send_via_ws: notify WS not connected");
        return false;
    }
    if (s_eleven_done == NULL) {
        s_eleven_done = xSemaphoreCreateBinary();
        if (s_eleven_done == NULL) return false;
    }

    char body[300];
    int n = snprintf(body, sizeof(body),
        "{\"type\":\"set_eleven_creds\","
         "\"duck_id\":\"%s\","
         "\"elevenlabs_key\":\"%s\","
         "\"elevenlabs_agent\":\"%s\"}",
        duck_id_get(), key, agent);
    if (n <= 0 || n >= (int)sizeof(body)) {
        ESP_LOGE(TAG, "eleven_creds body too large: %d", n);
        return false;
    }

    // Drain any stale signal from a previous attempt.
    xSemaphoreTake(s_eleven_done, 0);
    s_eleven_last_ok = false;

    int sent = esp_websocket_client_send_text(s_notify_ws, body, n,
                                              pdMS_TO_TICKS(5000));
    if (sent < n) {
        ESP_LOGE(TAG, "eleven_creds send failed (sent=%d of %d)", sent, n);
        return false;
    }
    ESP_LOGI(TAG, "set_eleven_creds sent (%d bytes), waiting for ack", n);

    if (xSemaphoreTake(s_eleven_done, pdMS_TO_TICKS(timeout_ms)) != pdTRUE) {
        ESP_LOGW(TAG, "set_eleven_creds timeout (%d ms)", timeout_ms);
        return false;
    }
    return s_eleven_last_ok;
}

bool set_printers_send_via_ws(const char *serials_pipe, int timeout_ms) {
    if (!serials_pipe || !*serials_pipe) return false;
    if (!s_notify_ws || !s_notify_ws_connected) {
        ESP_LOGW(TAG, "set_printers_send_via_ws: notify WS not connected");
        return false;
    }
    if (s_set_printers_done == NULL) {
        s_set_printers_done = xSemaphoreCreateBinary();
        if (s_set_printers_done == NULL) return false;
    }

    // serials_pipe should already be bounded — the caller (provision.c)
    // builds it from at most BAMBU_MAX_PRINTERS * (16 char serial + 1
    // separator) = ~140 chars. Pad the body for duck_id + JSON envelope.
    char body[256];
    int n = snprintf(body, sizeof(body),
        "{\"type\":\"set_printers\","
         "\"duck_id\":\"%s\","
         "\"serials\":\"%s\"}",
        duck_id_get(), serials_pipe);
    if (n <= 0 || n >= (int)sizeof(body)) {
        ESP_LOGE(TAG, "set_printers body too large: %d", n);
        return false;
    }
    xSemaphoreTake(s_set_printers_done, 0);
    s_set_printers_last_ok = false;
    int sent = esp_websocket_client_send_text(s_notify_ws, body, n,
                                              pdMS_TO_TICKS(5000));
    if (sent < n) {
        ESP_LOGE(TAG, "set_printers send failed (sent=%d of %d)", sent, n);
        return false;
    }
    ESP_LOGI(TAG, "set_printers sent (%d bytes), waiting for ack", n);
    if (xSemaphoreTake(s_set_printers_done, pdMS_TO_TICKS(timeout_ms)) != pdTRUE) {
        ESP_LOGW(TAG, "set_printers timeout (%d ms)", timeout_ms);
        return false;
    }
    return s_set_printers_last_ok;
}
