// APSTA captive-portal onboarding wizard.
//
// One continuous browser session from "duck has nothing" to "duck is on
// home WiFi + signed into Bambu cloud," with no reboot in the middle.
// Phone joins the duck's AP, captive portal pops up, user fills WiFi +
// Bambu creds, submits, page transitions through "connecting → logging
// in → maybe 2FA → done" all on the same connection.
//
// Why APSTA: at captive-portal time the phone has no internet, but the
// chip can be in BOTH AP (serving the page to the phone) and STA
// (connected to home WiFi → has internet → can talk to relay) at the
// same time. The chip submits the user's creds to the relay over the
// EXISTING /ws/notify WebSocket (plain TCP via ngrok), no chip-side
// HTTPS. That's the architecture that doesn't fight the chip's mbedtls
// quirks against ngrok's Cloudflare-fronted TLS edge.
//
// State machine (rendered server-side, browser auto-refreshes during
// transient states via <meta http-equiv=refresh>):
//
//   COLLECT_WIFI   → form 1: WiFi block + Bambu block
//                    /save POST → save WiFi to NVS, trigger STA connect,
//                    spawn background worker → CONNECTING_WIFI
//   CONNECTING_WIFI→ "connecting…" page, auto-refresh every 2s
//                    worker waits for got_ip → start notify task → WS up
//                    → call bambu_login_via_ws → state advances
//   LOGGING_IN     → "signing in…" auto-refresh
//   NEED_2FA       → form 2: just a 6-digit code field
//                    /code POST → bambu_login_via_ws(code) → state advances
//   BAD_CREDS      → error page (re-attempt or escape)
//   DONE           → success page
//
// On DONE, wifi_provision_run() returns — main.c proceeds with normal
// operation. AP stays up briefly so the user can see the success page,
// then comes down (eventually; not aggressive about it).
#include "provision.h"
#include "agent.h"
#include "wifi.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <esp_event.h>
#include <esp_http_server.h>
#include <esp_log.h>
#include <esp_mac.h>
#include <esp_netif.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/semphr.h>
#include <freertos/task.h>
#include <lwip/sockets.h>
#include <lwip/netdb.h>

static const char *TAG = "provision";

#define SCAN_MAX 16
static wifi_ap_record_t s_scan_results[SCAN_MAX];
static uint16_t s_scan_count = 0;

// ---- Wizard state machine ----

typedef enum {
    WIZ_COLLECT_WIFI = 0,
    WIZ_CONNECTING_WIFI,
    WIZ_WIFI_FAILED,
    WIZ_LOGGING_IN,
    WIZ_NEED_2FA,
    WIZ_LOGIN_BAD_CREDS,
    WIZ_DONE,
} wiz_state_t;

static volatile wiz_state_t s_state = WIZ_COLLECT_WIFI;

// Saved at /save time, used by the worker task and the /code retry.
// In-memory only — the password gets sent over WS to the relay and
// then forgotten on the chip. The relay holds the access_token after
// login, so the chip never needs to keep the password around.
//
// Protected by s_creds_mutex: writes happen on the httpd handler task
// (/save), reads happen on the worker tasks. Without the mutex a
// double-tap of /save during a worker's snprintf can tear the buffers.
// Workers should snapshot under-lock into local stack buffers before
// the long-running bambu_login_via_ws call, so the mutex is only ever
// held briefly.
static char s_bambu_email[65] = {0};
static char s_bambu_password[97] = {0};
static char s_bambu_user_id[40] = {0};
// ElevenLabs creds collected by the captive portal, forwarded to the
// relay over the same /ws/notify channel as bambu_login. Chip stores
// them in RAM only (relay holds the source-of-truth in its DB row);
// blank means the user wants to use the relay's default/env config.
static char s_eleven_key[80] = {0};
static char s_eleven_agent[40] = {0};
// Relay URL override collected from the captive portal. NOT YET USED at
// runtime — the WS clients in agent.c still build their URLs from the
// compile-time RELAY_BASE_URL #define. Plumbing this through requires
// either runtime-string URL builders or NVS-backed override that the
// boot path consults; tracked in the multi-tenant req doc, deferred to
// the Fly.io migration PR. We collect+log it now so the captive portal
// UX is final-shape and we can validate the full form flow.
static char s_relay_url[96] = {0};
static SemaphoreHandle_t s_creds_mutex = NULL;

static EventGroupHandle_t s_wifi_event_group = NULL;
#define BIT_STA_GOT_IP   BIT0
#define BIT_STA_FAILED   BIT1

// ---- DNS hijack (captive portal popup magic) ----
// Same as before — every DNS query gets answered with 192.168.4.1 so
// the OS's captive-portal probe URLs resolve to us. Combined with the
// 404 redirect handler, the phone's OS auto-pops the setup page.

static void dns_hijack_task(void *arg) {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        ESP_LOGE(TAG, "dns: socket() failed: errno=%d", errno);
        vTaskDelete(NULL);
        return;
    }
    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port = htons(53),
        .sin_addr.s_addr = htonl(INADDR_ANY),
    };
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        ESP_LOGE(TAG, "dns: bind() failed: errno=%d", errno);
        close(sock);
        vTaskDelete(NULL);
        return;
    }
    ESP_LOGI(TAG, "dns hijack listening on UDP/53 — answering 192.168.4.1 to all");

    uint8_t buf[512];
    while (1) {
        struct sockaddr_in src;
        socklen_t srclen = sizeof(src);
        int n = recvfrom(sock, buf, sizeof(buf), 0, (struct sockaddr *)&src, &srclen);
        if (n < 12) continue;
        buf[2] = 0x81; buf[3] = 0x80;
        buf[6] = 0x00; buf[7] = 0x01;
        int q_end = 12;
        while (q_end < n && buf[q_end] != 0) {
            int len = buf[q_end];
            if (len == 0 || q_end + 1 + len >= n) break;
            q_end += 1 + len;
        }
        q_end += 5;
        if (q_end + 16 > (int)sizeof(buf)) continue;
        uint8_t *p = buf + q_end;
        *p++ = 0xc0; *p++ = 0x0c;
        *p++ = 0x00; *p++ = 0x01;
        *p++ = 0x00; *p++ = 0x01;
        *p++ = 0x00; *p++ = 0x00; *p++ = 0x00; *p++ = 60;
        *p++ = 0x00; *p++ = 0x04;
        *p++ = 192; *p++ = 168; *p++ = 4; *p++ = 1;
        int outlen = p - buf;
        sendto(sock, buf, outlen, 0, (struct sockaddr *)&src, srclen);
    }
}

// ---- Form helpers ----

static void url_decode(char *s) {
    char *r = s, *w = s;
    while (*r) {
        if (*r == '+') { *w++ = ' '; r++; }
        else if (*r == '%' && r[1] && r[2]) {
            char hex[3] = { r[1], r[2], 0 };
            *w++ = (char)strtol(hex, NULL, 16);
            r += 3;
        } else { *w++ = *r++; }
    }
    *w = '\0';
}

static bool form_get(const char *body, const char *key, char *out, size_t out_cap) {
    char needle[40];
    int nl = snprintf(needle, sizeof(needle), "%s=", key);
    if (nl <= 0) return false;
    const char *p = strstr(body, needle);
    if (!p) return false;
    p += nl;
    const char *end = strchr(p, '&');
    size_t len = end ? (size_t)(end - p) : strlen(p);
    if (len >= out_cap) len = out_cap - 1;
    memcpy(out, p, len);
    out[len] = '\0';
    url_decode(out);
    return true;
}

// ---- Captive portal — every 404 redirects to / so the OS auto-pop lands here ----

static esp_err_t captive_redirect(httpd_req_t *req, httpd_err_code_t err) {
    httpd_resp_set_status(req, "302 Found");
    httpd_resp_set_hdr(req, "Location", "http://192.168.4.1/");
    httpd_resp_send(req, NULL, 0);
    return ESP_OK;
}

// ---- WiFi event handler (STA side — AP events ignored) ----

static void wifi_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data) {
    if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)data;
        ESP_LOGI(TAG, "STA got ip: " IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(s_wifi_event_group, BIT_STA_GOT_IP);
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        // STA can disconnect for benign reasons (roaming, brief noise).
        // Only flag failure if we never connected. For our wizard, the
        // first disconnect when we're trying to authenticate is the bad
        // case — bumping the failed bit lets the worker handle it.
        ESP_LOGW(TAG, "STA disconnected; will retry");
        esp_wifi_connect();
    }
}

// ---- HTML rendering per state ----

// Common header and footer reused across all pages so styling is
// consistent. Stored as static strings to avoid stack pressure.

static const char html_head[] =
    "<!doctype html><html><head><meta charset=utf-8>"
    "<meta name=viewport content='width=device-width,initial-scale=1'>"
    "<title>Set up Duck</title>"
    "<style>"
    "body{font-family:-apple-system,system-ui,sans-serif;max-width:420px;"
    "margin:2em auto;padding:0 1em;color:#222}"
    "h1{font-size:1.4em}h2{font-size:1.1em;margin-top:1.6em}"
    "label{display:block;margin:1em 0 .25em;font-weight:600}"
    "input,select{width:100%;padding:.7em;font-size:1em;box-sizing:border-box;"
    "border:1px solid #aaa;border-radius:6px}"
    "button{margin-top:1.5em;width:100%;padding:.9em;font-size:1.05em;"
    "background:#f5b942;border:0;border-radius:6px;font-weight:600}"
    ".sub{color:#666;font-size:.9em}"
    ".ok{background:#e8f5e9;border-radius:6px;padding:.7em;color:#1b5e20}"
    ".err{background:#fde7e7;border-radius:6px;padding:.7em;color:#b71c1c}"
    ".code{font-family:ui-monospace,monospace;letter-spacing:.2em;"
    "text-align:center;font-size:1.4em}"
    "</style></head><body>";
static const char html_tail[] = "</body></html>";

static void render_collect_wifi(httpd_req_t *req) {
    httpd_resp_send_chunk(req, html_head, sizeof(html_head) - 1);
    static const char start[] =
        "<h1>🦆 Hi! Let's get you set up.</h1>"
        "<p class=sub>Tell me your WiFi and Bambu account. I'll handle the rest "
        "without disconnecting you from this page.</p>"
        "<form method=POST action=/save>"
        "<h2>WiFi</h2>"
        "<label for=ssid>Network</label>"
        "<select id=ssid name=ssid required>";
    httpd_resp_send_chunk(req, start, sizeof(start) - 1);
    if (s_scan_count == 0) {
        static const char none[] = "<option value=''>(no networks found — type below)</option>";
        httpd_resp_send_chunk(req, none, sizeof(none) - 1);
    }
    for (int i = 0; i < s_scan_count; i++) {
        char opt[80], clean[33];
        const char *src = (const char *)s_scan_results[i].ssid;
        int o = 0;
        for (int k = 0; src[k] && o + 1 < (int)sizeof(clean); k++) {
            char c = src[k];
            if (c == '<' || c == '>' || c == '&' || c == '"') c = '_';
            clean[o++] = c;
        }
        clean[o] = '\0';
        int n = snprintf(opt, sizeof(opt),
                         "<option value=\"%s\">%s (%d dBm)</option>",
                         clean, clean, s_scan_results[i].rssi);
        if (n > 0) httpd_resp_send_chunk(req, opt, n);
    }
    static const char tail[] =
        "</select>"
        "<label for=pw>WiFi password</label>"
        "<input type=password id=pw name=pw autocomplete=off"
        " autocorrect=off autocapitalize=off spellcheck=false passwordrules=\"\">"
        "<h2>Bambu account</h2>"
        "<p class=sub>So I can talk to your printer through Bambu's cloud.</p>"
        "<label for=bemail>Email</label>"
        "<input type=email id=bemail name=bemail required autocomplete=off "
        "autocapitalize=off>"
        "<label for=bpw>Password</label>"
        "<input type=password id=bpw name=bpw required autocomplete=off"
        " autocorrect=off autocapitalize=off spellcheck=false passwordrules=\"\">"
        "<h2>ElevenLabs</h2>"
        "<p class=sub>Your ElevenLabs API key + agent ID. The relay uses these "
        "to give the duck a voice. (Skip if you're using a relay we host — "
        "leave both blank and we'll use ours.)</p>"
        "<label for=ekey>API key</label>"
        "<input type=password id=ekey name=ekey autocomplete=off "
        " autocorrect=off autocapitalize=off spellcheck=false passwordrules=\"\">"
        "<label for=eagent>Agent ID</label>"
        "<input type=text id=eagent name=eagent autocomplete=off "
        " autocorrect=off autocapitalize=off spellcheck=false>"
        "<details><summary class=sub>Advanced — relay URL</summary>"
        "<p class=sub>If you're running your own relay, paste its WebSocket "
        "URL here (e.g. wss://duck.fly.dev). Leave blank to use the default.</p>"
        "<label for=rurl>Relay URL</label>"
        "<input type=url id=rurl name=rurl placeholder=\"wss://...\" "
        " autocomplete=off autocorrect=off autocapitalize=off spellcheck=false>"
        "</details>"
        "<button type=submit>Set up</button>"
        "</form>";
    httpd_resp_send_chunk(req, tail, sizeof(tail) - 1);
    httpd_resp_send_chunk(req, html_tail, sizeof(html_tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);
}

static void render_status(httpd_req_t *req, const char *title, const char *body,
                          bool refresh) {
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    if (refresh) {
        // Auto-refresh page every 2s while we're in a transient state.
        // Plain meta refresh — no JS — works in every browser including
        // captive-portal restricted in-app browsers.
        httpd_resp_send_chunk(req,
            "<!doctype html><html><head><meta charset=utf-8>"
            "<meta name=viewport content='width=device-width,initial-scale=1'>"
            "<meta http-equiv=refresh content='2'>",
            -1);
    } else {
        httpd_resp_send_chunk(req,
            "<!doctype html><html><head><meta charset=utf-8>"
            "<meta name=viewport content='width=device-width,initial-scale=1'>",
            -1);
    }
    httpd_resp_send_chunk(req,
        "<title>Set up Duck</title><style>"
        "body{font-family:-apple-system,system-ui,sans-serif;max-width:420px;"
        "margin:2em auto;padding:0 1em;color:#222;text-align:center}"
        "h1{font-size:1.4em}.sub{color:#666;font-size:.9em}"
        "</style></head><body>", -1);
    httpd_resp_send_chunk(req, "<h1>", -1);
    httpd_resp_send_chunk(req, title, -1);
    httpd_resp_send_chunk(req, "</h1><p class=sub>", -1);
    httpd_resp_send_chunk(req, body, -1);
    httpd_resp_send_chunk(req, "</p>", -1);
    httpd_resp_send_chunk(req, html_tail, sizeof(html_tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);
}

static void render_2fa_form(httpd_req_t *req, bool retry) {
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    httpd_resp_send_chunk(req, html_head, sizeof(html_head) - 1);
    httpd_resp_send_chunk(req, "<h1>🦆 Verification code</h1>", -1);
    if (retry) {
        httpd_resp_send_chunk(req,
            "<div class=err>That code didn't work. Use the latest one from "
            "your email — or if your Bambu email/password was wrong, start "
            "over below.</div>", -1);
    }
    httpd_resp_send_chunk(req,
        "<p class=sub>Bambu emailed you a 6-digit code. Type it here:</p>"
        "<form method=POST action=/code>"
        "<input class=code type=text inputmode=numeric pattern='[0-9]*' "
        "name=c maxlength=6 autocomplete='one-time-code' required "
        "autocorrect=off autocapitalize=off spellcheck=false>"
        "<button type=submit>Submit</button>"
        "</form>"
        "<form method=POST action=/restart style='margin-top:1.5em'>"
        "<button type=submit style='background:#eee;font-weight:400'>"
        "Start over</button>"
        "</form>", -1);
    httpd_resp_send_chunk(req, html_tail, sizeof(html_tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);
}

// Renders the "WiFi didn't connect" page with a POST-based "Try again"
// button. POST (not GET <a href>) so browser pre-fetch / mistaken
// reload doesn't trigger the state reset on its own — the user has
// to actively click. /restart wipes the in-memory creds and goes back
// to the form; if the user types a new WiFi password there, /save
// overwrites NVS. No explicit "forget WiFi" UI needed.
static void render_wifi_failed(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    httpd_resp_send_chunk(req, html_head, sizeof(html_head) - 1);
    httpd_resp_send_chunk(req,
        "<h1>WiFi didn't connect</h1>"
        "<p class=sub>The password might be wrong, or that network's out "
        "of range.</p>"
        "<form method=POST action=/restart>"
        "<button type=submit>Try again</button>"
        "</form>", -1);
    httpd_resp_send_chunk(req, html_tail, sizeof(html_tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);
}

// ---- HTTP handlers ----

static esp_err_t root_handler(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    switch (s_state) {
        case WIZ_COLLECT_WIFI:
            render_collect_wifi(req);
            return ESP_OK;
        case WIZ_CONNECTING_WIFI:
            render_status(req, "Connecting to your WiFi…",
                "I'll be back online in a few seconds. This page will refresh.", true);
            return ESP_OK;
        case WIZ_WIFI_FAILED:
            render_wifi_failed(req);
            return ESP_OK;
        case WIZ_LOGGING_IN:
            render_status(req, "Signing in to Bambu…",
                "Should be quick. This page will refresh.", true);
            return ESP_OK;
        case WIZ_NEED_2FA:
            render_2fa_form(req, false);
            return ESP_OK;
        case WIZ_LOGIN_BAD_CREDS:
            render_2fa_form(req, true);
            return ESP_OK;
        case WIZ_DONE:
            render_status(req, "🦆 You're set!",
                "Bambu is connected. You can disconnect from the duck's "
                "WiFi now. Your phone will switch back to your home network.",
                false);
            return ESP_OK;
    }
    return ESP_OK;
}

// Forward declaration — defined below (worker spawned by /save).
static void provision_worker_task(void *arg);

static esp_err_t save_handler(httpd_req_t *req) {
    char body[512] = {0};
    int len = req->content_len < (int)sizeof(body) - 1
                ? req->content_len : (int)sizeof(body) - 1;
    int got = httpd_req_recv(req, body, len);
    if (got <= 0) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    body[got] = '\0';

    char ssid[33] = {0}, wifi_pw[65] = {0};
    if (!form_get(body, "ssid", ssid, sizeof(ssid)) || ssid[0] == '\0') {
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_send(req, "Missing ssid", HTTPD_RESP_USE_STRLEN);
        return ESP_OK;
    }
    form_get(body, "pw", wifi_pw, sizeof(wifi_pw));
    // Cred buffers are read by the worker task — take the lock briefly
    // so a refresh-tap of /save while a worker is running can't tear the
    // strings under the worker's snprintf.
    if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
    form_get(body, "bemail", s_bambu_email, sizeof(s_bambu_email));
    form_get(body, "bpw", s_bambu_password, sizeof(s_bambu_password));
    // ElevenLabs creds — optional. Forwarded to the relay as a separate
    // ws message (set_eleven_creds) after the bambu_login round-trip.
    form_get(body, "ekey", s_eleven_key, sizeof(s_eleven_key));
    form_get(body, "eagent", s_eleven_agent, sizeof(s_eleven_agent));
    // Relay URL override — collected for forward-compat, currently
    // unused at runtime (see static decl comment above).
    form_get(body, "rurl", s_relay_url, sizeof(s_relay_url));
    if (s_relay_url[0]) {
        ESP_LOGI(TAG, "captive portal collected relay URL override: %s "
                      "(NOT YET ACTIVE — requires runtime URL plumbing)",
                 s_relay_url);
    }
    // user_id is auto-resolved via /preference on the relay side now —
    // /preference proved reliable across testing. If Bambu ever breaks
    // /preference we fall back to relay-side env BAMBU_USER_ID, OR add
    // a recovery form. Not worth a captive-portal field today.
    s_bambu_user_id[0] = '\0';
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);

    // Persist WiFi to NVS (so reboot recovers). Bambu creds stay in
    // memory only — they get sent to the relay over WS during the
    // wizard's worker phase, then we forget them.
    esp_err_t err = wifi_save_creds(ssid, wifi_pw);
    if (err != ESP_OK) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    // Configure STA with the new creds and trigger a connect. AP stays
    // up — APSTA mode means both interfaces are simultaneously live.
    wifi_config_t sta_cfg = {0};
    strncpy((char *)sta_cfg.sta.ssid, ssid, sizeof(sta_cfg.sta.ssid));
    strncpy((char *)sta_cfg.sta.password, wifi_pw, sizeof(sta_cfg.sta.password));
    sta_cfg.sta.threshold.authmode = WIFI_AUTH_OPEN;
    sta_cfg.sta.pmf_cfg.capable = true;
    sta_cfg.sta.pmf_cfg.required = false;
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_cfg));
    ESP_ERROR_CHECK(esp_wifi_connect());

    s_state = WIZ_CONNECTING_WIFI;
    xTaskCreate(provision_worker_task, "prov_worker", 6144, NULL, 4, NULL);

    // 303 → GET / so the browser doesn't resubmit on refresh.
    httpd_resp_set_status(req, "303 See Other");
    httpd_resp_set_hdr(req, "Location", "/");
    httpd_resp_send(req, NULL, 0);
    return ESP_OK;
}

// /restart — escape hatch from a stuck wizard state (WIFI_FAILED,
// LOGIN_BAD_CREDS, or 2FA-with-wrong-Bambu-password). Just clears the
// in-memory cred buffers and rewinds state to COLLECT_WIFI so the
// next render is the form. WiFi NVS is left alone — if the user types
// new WiFi creds in the form, /save overwrites NVS automatically; if
// they leave WiFi alone, the existing values stay.
//
// POST (not GET) so a browser pre-fetch can't accidentally wipe state.
//
// We don't expose a "factory wipe NVS" button here on purpose — the
// soft long-press path (set provision_pending + reboot) preserves
// creds by design, and a user who actually wants a hard reset can
// re-flash or use a serial command. Keeps the captive-portal UX
// reversible-by-default.
static esp_err_t restart_handler(httpd_req_t *req) {
    // Drain any body bytes (we don't use them, but the httpd needs us
    // to consume them so the keepalive connection stays clean).
    char buf[64];
    int remaining = req->content_len;
    while (remaining > 0) {
        int n = httpd_req_recv(req, buf, remaining < (int)sizeof(buf)
                                          ? remaining : (int)sizeof(buf));
        if (n <= 0) break;
        remaining -= n;
    }

    if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
    memset(s_bambu_email,    0, sizeof(s_bambu_email));
    memset(s_bambu_password, 0, sizeof(s_bambu_password));
    memset(s_bambu_user_id,  0, sizeof(s_bambu_user_id));
    memset(s_eleven_key,     0, sizeof(s_eleven_key));
    memset(s_eleven_agent,   0, sizeof(s_eleven_agent));
    memset(s_relay_url,      0, sizeof(s_relay_url));
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);

    ESP_LOGI(TAG, "/restart: cleared in-mem creds, back to COLLECT_WIFI");
    s_state = WIZ_COLLECT_WIFI;

    httpd_resp_set_status(req, "303 See Other");
    httpd_resp_set_hdr(req, "Location", "/");
    httpd_resp_send(req, NULL, 0);
    return ESP_OK;
}

// Forward declaration — worker spawned by /code (defined below).
static void retry_login_worker_task(void *arg);

static esp_err_t code_handler(httpd_req_t *req) {
    char body[64] = {0};
    int len = req->content_len < (int)sizeof(body) - 1
                ? req->content_len : (int)sizeof(body) - 1;
    int got = httpd_req_recv(req, body, len);
    if (got <= 0) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    body[got] = '\0';
    char code[16] = {0};
    if (!form_get(body, "c", code, sizeof(code)) || code[0] == '\0') {
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_send(req, "Missing code", HTTPD_RESP_USE_STRLEN);
        return ESP_OK;
    }
    // Spawn a worker so we can return 303 immediately and the browser
    // sees the LOGGING_IN page during the 30s wait (mirroring /save).
    // Stash the code in a heap buffer the worker takes ownership of.
    char *code_arg = malloc(sizeof(code));
    if (!code_arg) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    strlcpy(code_arg, code, sizeof(code));
    s_state = WIZ_LOGGING_IN;
    if (xTaskCreate(retry_login_worker_task, "code_worker", 6144,
                    code_arg, 4, NULL) != pdPASS) {
        free(code_arg);
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    httpd_resp_set_status(req, "303 See Other");
    httpd_resp_set_hdr(req, "Location", "/");
    httpd_resp_send(req, NULL, 0);
    return ESP_OK;
}

// ---- Worker — runs the post-WiFi-up sequence asynchronously ----

static void provision_worker_task(void *arg) {
    // 1. Wait for STA to get an IP. Generous timeout — slow auth, weak
    //    signal, etc. If we never get IP, bail to FAILED.
    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
        BIT_STA_GOT_IP, pdFALSE, pdFALSE, pdMS_TO_TICKS(30000));
    if (!(bits & BIT_STA_GOT_IP)) {
        ESP_LOGE(TAG, "worker: STA never got IP");
        s_state = WIZ_WIFI_FAILED;
        vTaskDelete(NULL);
        return;
    }

    // 2. Snapshot creds into local stack buffers so we can release the
    //    mutex before the long-running login call. This keeps the lock
    //    hold time microseconds, not seconds.
    char email[65], password[97], user_id[40];
    if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
    strlcpy(email,    s_bambu_email,    sizeof(email));
    strlcpy(password, s_bambu_password, sizeof(password));
    strlcpy(user_id,  s_bambu_user_id,  sizeof(user_id));
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);

    // Skip Bambu login entirely if user didn't fill the email field —
    // they can configure later via a future duck.local recovery surface.
    if (email[0] == '\0') {
        ESP_LOGI(TAG, "worker: no Bambu email, skipping cloud login");
        s_state = WIZ_DONE;
        vTaskDelete(NULL);
        return;
    }

    // 3. Bring up the long-lived /ws/notify connection. notify_task_start
    //    is idempotent.
    notify_task_start();

    // 4. Wait for WS to be connected before sending. The TCP+WS handshake
    //    to ngrok takes ~500ms-2s typically.
    int waited = 0;
    while (!notify_ws_is_connected() && waited < 15000) {
        vTaskDelay(pdMS_TO_TICKS(200));
        waited += 200;
    }
    if (!notify_ws_is_connected()) {
        ESP_LOGW(TAG, "worker: notify WS didn't come up — relay may be down");
        s_state = WIZ_LOGIN_BAD_CREDS;  // visible failure, can re-onboard
        vTaskDelete(NULL);
        return;
    }

    // 5. If the user filled in ElevenLabs creds, send them now (before
    //    bambu_login since this side-channel is fast and order-independent
    //    on the relay — both write to the same DB row, last writer wins).
    char eleven_key_local[80] = {0}, eleven_agent_local[40] = {0};
    if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
    strlcpy(eleven_key_local,   s_eleven_key,   sizeof(eleven_key_local));
    strlcpy(eleven_agent_local, s_eleven_agent, sizeof(eleven_agent_local));
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);
    if (eleven_key_local[0] && eleven_agent_local[0]) {
        eleven_creds_send_via_ws(eleven_key_local, eleven_agent_local);
        // Forget the key on chip — relay holds it now.
        if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
        memset(s_eleven_key, 0, sizeof(s_eleven_key));
        if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);
    }

    // 6. Send the login. NEED_2FA is the typical first response.
    s_state = WIZ_LOGGING_IN;
    bambu_login_ws_result_t r = bambu_login_via_ws(
        email, password, "", user_id, 30000);
    ESP_LOGI(TAG, "worker: bambu_login_via_ws result=%d", r);
    switch (r) {
        case BAMBU_LOGIN_WS_OK:
            // Forget the password now — relay holds the access_token.
            if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
            memset(s_bambu_password, 0, sizeof(s_bambu_password));
            if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);
            s_state = WIZ_DONE;
            break;
        case BAMBU_LOGIN_WS_NEED_2FA:
            s_state = WIZ_NEED_2FA;
            break;
        case BAMBU_LOGIN_WS_BAD_CREDS:
            s_state = WIZ_LOGIN_BAD_CREDS;
            break;
        case BAMBU_LOGIN_WS_RELAY_DOWN:
        case BAMBU_LOGIN_WS_TIMEOUT:
        default:
            // Treat as bad-creds for UX simplicity — user gets a chance
            // to retry. Could split out distinct errors later.
            s_state = WIZ_LOGIN_BAD_CREDS;
            break;
    }
    vTaskDelete(NULL);
}

static void retry_login_worker_task(void *arg) {
    char *code = (char *)arg;

    // Snapshot creds under-lock — same pattern as provision_worker_task.
    char email[65], password[97], user_id[40];
    if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
    strlcpy(email,    s_bambu_email,    sizeof(email));
    strlcpy(password, s_bambu_password, sizeof(password));
    strlcpy(user_id,  s_bambu_user_id,  sizeof(user_id));
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);

    bambu_login_ws_result_t r = bambu_login_via_ws(
        email, password, code, user_id, 30000);
    ESP_LOGI(TAG, "retry_login_worker result=%d", r);
    switch (r) {
        case BAMBU_LOGIN_WS_OK:
            if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
            memset(s_bambu_password, 0, sizeof(s_bambu_password));
            if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);
            s_state = WIZ_DONE;
            break;
        case BAMBU_LOGIN_WS_NEED_2FA:
        case BAMBU_LOGIN_WS_BAD_CREDS:
        default:
            s_state = WIZ_LOGIN_BAD_CREDS;
            break;
    }
    free(code);
    vTaskDelete(NULL);
}

// ---- Entry point ----

esp_err_t wifi_provision_run(void) {
    ESP_LOGI(TAG, "starting APSTA onboarding wizard");
    s_state = WIZ_COLLECT_WIFI;
    s_wifi_event_group = xEventGroupCreate();
    if (!s_creds_mutex) s_creds_mutex = xSemaphoreCreateMutex();

    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_SOFTAP);
    char ap_ssid[32];
    snprintf(ap_ssid, sizeof(ap_ssid), "DuckDuckDuck-%02X%02X", mac[4], mac[5]);

    esp_netif_init();
    esp_event_loop_create_default();
    esp_netif_create_default_wifi_ap();
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));

    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
        ESP_EVENT_ANY_ID, wifi_event_handler, NULL, NULL));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
        IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL, NULL));

    // Scan first in STA-only mode to populate the network dropdown. AP
    // hasn't been started yet — phones can't see the duck yet.
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    wifi_scan_config_t scan = {
        .scan_type = WIFI_SCAN_TYPE_ACTIVE,
        .scan_time.active = { .min = 100, .max = 300 },
    };
    if (esp_wifi_scan_start(&scan, true) == ESP_OK) {
        s_scan_count = SCAN_MAX;
        if (esp_wifi_scan_get_ap_records(&s_scan_count, s_scan_results) != ESP_OK)
            s_scan_count = 0;
    }
    ESP_LOGI(TAG, "scan found %d networks", s_scan_count);

    // Switch to APSTA. AP comes up — phones can join. STA stays
    // enabled (idle) until the user submits creds via /save.
    wifi_config_t ap_cfg = {0};
    strncpy((char *)ap_cfg.ap.ssid, ap_ssid, sizeof(ap_cfg.ap.ssid));
    ap_cfg.ap.ssid_len = strlen(ap_ssid);
    ap_cfg.ap.channel = 1;
    ap_cfg.ap.max_connection = 4;
    ap_cfg.ap.authmode = WIFI_AUTH_OPEN;
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &ap_cfg));
    // PS off so the AP doesn't drop client packets and the audio path
    // stays responsive when STA comes up later.
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    ESP_LOGI(TAG, "APSTA up: AP=%s, STA idle (will connect on /save submit)", ap_ssid);

    // HTTP server + DNS hijack (captive-portal pop-up).
    httpd_handle_t server = NULL;
    httpd_config_t hcfg = HTTPD_DEFAULT_CONFIG();
    hcfg.lru_purge_enable = true;
    ESP_ERROR_CHECK(httpd_start(&server, &hcfg));
    httpd_uri_t root = { .uri = "/", .method = HTTP_GET, .handler = root_handler };
    httpd_uri_t save = { .uri = "/save", .method = HTTP_POST, .handler = save_handler };
    httpd_uri_t code = { .uri = "/code", .method = HTTP_POST, .handler = code_handler };
    httpd_uri_t rstr = { .uri = "/restart", .method = HTTP_POST, .handler = restart_handler };
    httpd_register_uri_handler(server, &root);
    httpd_register_uri_handler(server, &save);
    httpd_register_uri_handler(server, &code);
    httpd_register_uri_handler(server, &rstr);
    httpd_register_err_handler(server, HTTPD_404_NOT_FOUND, captive_redirect);
    xTaskCreate(dns_hijack_task, "dns_hijack", 4096, NULL, 5, NULL);

    // Block until the wizard reaches DONE (or stays stuck in a failure
    // state — caller can long-press to wipe and retry). Polling is fine
    // here; the wait is human-paced.
    while (s_state != WIZ_DONE) {
        vTaskDelay(pdMS_TO_TICKS(500));
    }
    ESP_LOGI(TAG, "wizard reached DONE — leaving AP up briefly for success page");

    // Give the user's browser ~30s to load the success page and read it.
    // Then tear down the AP. STA stays connected; httpd stays running
    // (harmless — not externally accessible without the AP).
    vTaskDelay(pdMS_TO_TICKS(30000));
    ESP_LOGI(TAG, "tearing down AP");
    httpd_stop(server);
    esp_wifi_set_mode(WIFI_MODE_STA);  // drops AP, keeps STA connected
    return ESP_OK;
}
