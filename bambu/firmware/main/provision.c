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
// EXISTING /ws/notify WebSocket — no separate HTTPS connection. The
// relay does the real Bambu cloud TLS in Python httpx and returns
// the result on the same WebSocket. One persistent connection does
// double duty for printer-event push AND credential forwarding.
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
#include "audio.h"
#include "config.h"   // BUTTON_PIN
#include "phrases.h"
#include "servo.h"
#include "wifi.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <driver/gpio.h>
#include <esp_event.h>
#include <esp_http_server.h>
#include <esp_log.h>
#include <esp_mac.h>
#include <esp_netif.h>
#include <esp_timer.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/semphr.h>
#include <nvs_flash.h>
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
    // Phase B of #41 — after a successful bambu_login that returned
    // ≥2 printers, render a checkbox form so the user can opt out of
    // any. Single-printer accounts skip this state entirely.
    WIZ_PICK_PRINTERS,
    // Settings-only fast-path entry (long-press while already
    // onboarded). Renders "checking your printers..." with auto-
    // refresh while the worker pulls the current list from the relay
    // using the stored access_token. On success → WIZ_PICK_PRINTERS;
    // on failure → fall back to WIZ_COLLECT_WIFI.
    WIZ_FAST_LOADING,
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
    // Override for checkboxes — the input{width:100%;...} above
    // stretched native checkboxes into invisible "text-box"-shaped
    // controls on iOS captive portal browsers (#41 Phase B picker).
    // Force native rendering, fixed size, no stretch.
    // Native size via width/height (transform:scale was breaking the
    // tap hit-testing on iOS captive-portal browser — checkbox was
    // visually scaled but the actual touch region stayed at the
    // unscaled position, leaving users tapping the wrong area).
    "input[type=checkbox]{width:24px;height:24px;padding:0;border:0;"
    "border-radius:0;margin:0 .8em 0 .2em;vertical-align:middle;"
    "accent-color:#f5b942}"
    "button{margin-top:1.5em;width:100%;padding:.9em;font-size:1.05em;"
    "background:#f5b942;border:0;border-radius:6px;font-weight:600}"
    ".sub{color:#666;font-size:.9em}"
    ".ok{background:#e8f5e9;border-radius:6px;padding:.7em;color:#1b5e20}"
    ".err{background:#fde7e7;border-radius:6px;padding:.7em;color:#b71c1c}"
    ".code{font-family:ui-monospace,monospace;letter-spacing:.2em;"
    "text-align:center;font-size:1.4em}"
    "</style></head><body>";
static const char html_tail[] = "</body></html>";

// Emit the settings section (volume, movement mode, time zone) with
// the currently-persisted values pre-selected. Shared between the
// initial form and the picker page so a re-entry user can adjust
// settings without re-doing onboarding. Form `name=` attributes
// (`vol`, `move`, `tz`) are parsed by both /save and /pick handlers.
static void render_settings_section(httpd_req_t *req) {
    uint8_t vol = audio_get_volume_step();
    servo_move_mode_t move = servo_get_move_mode();
    int16_t tz = servo_get_tz_offset_min();

    static const char head[] =
        "<h2>Settings</h2>"
        "<p class=sub>How loud the duck speaks, when it moves its head, "
        "and what time zone you're in (so the quiet-hours mode knows "
        "when night is).</p>"
        "<label for=vol>Volume</label>"
        "<select id=vol name=vol>";
    httpd_resp_send_chunk(req, head, sizeof(head) - 1);
    static const char *vol_labels[] = {
        "Loud", "Normal", "Quiet", "Whisper", "Mute"
    };
    for (int i = 0; i < 5; i++) {
        char opt[80];
        int n = snprintf(opt, sizeof(opt),
            "<option value=%d%s>%s</option>",
            i, (vol == i) ? " selected" : "", vol_labels[i]);
        if (n > 0) httpd_resp_send_chunk(req, opt, n);
    }

    static const char move_head[] =
        "</select>"
        "<label>Movement</label>"
        "<div style='margin-bottom:.8em'>";
    httpd_resp_send_chunk(req, move_head, sizeof(move_head) - 1);
    static const char *move_labels[] = {
        "Always alive (quiet 9pm–6am)",
        "Tapered (active, then settles down)",
        "Only after I touch it (quiet otherwise)",
    };
    for (int i = 0; i < 3; i++) {
        char opt[200];
        int n = snprintf(opt, sizeof(opt),
            "<div style='padding:.3em 0'>"
            "<input type=radio id=m%d name=move value=%d%s>"
            "<label for=m%d style='display:inline;font-weight:400;cursor:pointer'>"
            "%s</label></div>",
            i, i, ((int)move == i) ? " checked" : "", i, move_labels[i]);
        if (n > 0) httpd_resp_send_chunk(req, opt, n);
    }

    static const char tz_head[] =
        "</div>"
        "<label for=tz>Time zone</label>"
        "<select id=tz name=tz>";
    httpd_resp_send_chunk(req, tz_head, sizeof(tz_head) - 1);
    // Common offsets, minutes east of UTC. Standard time only — DST
    // shifts twice a year, user updates manually if their region
    // observes it. Covers continental US, Hawaii, UK, CET, JST.
    static const struct { int16_t mins; const char *label; } tz_opts[] = {
        {    0, "UTC"                                  },
        { -480, "US Pacific (PST, UTC−8)"              },
        { -420, "US Pacific Daylight (PDT, UTC−7)"     },
        { -420, "US Mountain (MST, UTC−7)"             },
        { -360, "US Mountain Daylight (MDT, UTC−6)"    },
        { -360, "US Central (CST, UTC−6)"              },
        { -300, "US Central Daylight (CDT, UTC−5)"     },
        { -300, "US Eastern (EST, UTC−5)"              },
        { -240, "US Eastern Daylight (EDT, UTC−4)"     },
        { -600, "US Hawaii (HST, UTC−10)"              },
        {   60, "Europe Central (CET, UTC+1)"          },
        {  120, "Europe Central Summer (CEST, UTC+2)"  },
        {  540, "Asia Tokyo (JST, UTC+9)"              },
    };
    bool tz_matched = false;
    for (size_t i = 0; i < sizeof(tz_opts) / sizeof(tz_opts[0]); i++) {
        bool sel = (tz_opts[i].mins == tz) && !tz_matched;
        if (sel) tz_matched = true;
        char opt[120];
        int n = snprintf(opt, sizeof(opt),
            "<option value=%d%s>%s</option>",
            (int)tz_opts[i].mins, sel ? " selected" : "", tz_opts[i].label);
        if (n > 0) httpd_resp_send_chunk(req, opt, n);
    }
    static const char tz_tail[] = "</select>";
    httpd_resp_send_chunk(req, tz_tail, sizeof(tz_tail) - 1);
}

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
    static const char tail_pre[] =
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
#ifndef BAMBU_DUCK_TURNKEY
        // Turnkey builds (idf.py -DBAMBU_DUCK_TURNKEY=1) skip the
        // ElevenLabs section — the relay being used already has shared
        // creds, and the user only needs WiFi + Bambu. Default (open-
        // source self-hosted) builds keep the section so each
        // self-hoster brings their own ElevenLabs account.
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
#endif
        ;
    static const char tail_post[] =
#ifdef BAMBU_DUCK_TURNKEY
        // Turnkey builds bake a relay URL at compile time. The field
        // is still here as an Advanced override for fleet ducks that
        // want to point at a different deployment (e.g. staging),
        // but it's optional and tucked behind <details>.
        "<details><summary class=sub>Advanced — relay URL</summary>"
        "<p class=sub>The duck connects to its built-in relay by "
        "default. Override here to point at a different WebSocket "
        "URL (e.g. wss://staging.example.com). Leave blank to use "
        "the default.</p>"
        "<label for=rurl>Relay URL</label>"
        "<input type=url id=rurl name=rurl placeholder=\"wss://...\" "
        "pattern='wss?://.+' "
        " autocomplete=off autocorrect=off autocapitalize=off spellcheck=false>"
        "</details>"
#else
        // Open-source / public-flasher builds: the relay URL is
        // REQUIRED. There's no compile-time default to fall back to,
        // so the duck literally can't open sessions until the user
        // supplies one. We surface the field prominently (not in a
        // details block) and link to the deploy runbook so a user
        // who doesn't have a relay yet has a clear path forward.
        "<h2>Relay</h2>"
        "<p class=sub>Where the duck connects for voice + printer "
        "data. You'll need a relay running on your own infrastructure "
        "— a 5-minute setup using <a href='https://github.com/ideo/Rubber-Duck/blob/main/bambu/DEPLOY.md' "
        "target='_blank'>this runbook</a>. After you deploy it, paste "
        "your <code>wss://&lt;your-app&gt;.fly.dev</code> URL here.</p>"
        "<label for=rurl>Relay URL</label>"
        "<input type=url id=rurl name=rurl required "
        "placeholder=\"wss://your-app.fly.dev\" "
        "pattern='wss?://.+' "
        " autocomplete=off autocorrect=off autocapitalize=off spellcheck=false>"
#endif
        "<button type=submit>Set up</button>"
        "</form>"
        // Factory Reset — separate form posting to /factory_reset.
        // Wipes the relay row (Bambu access_token, ElevenLabs creds,
        // printer binding) AND the chip's NVS (WiFi creds, volume,
        // any cached state) then reboots fresh. For when shipping a
        // duck to someone else, or moving it between Bambu accounts
        // cleanly. Inline confirm prompt because the action is
        // irreversible — single accidental tap shouldn't wipe.
        "<form method=POST action=/factory_reset style='margin-top:2em'>"
        "<p class=sub style='color:#900;margin-bottom:.4em'>"
        "Wipes WiFi + Bambu account + all settings. Cannot be undone.</p>"
        "<label for=frconfirm class=sub>Type RESET to confirm</label>"
        "<input type=text id=frconfirm name=confirm required "
        "pattern='[Rr][Ee][Ss][Ee][Tt]' "
        "autocomplete=off autocorrect=off autocapitalize=characters "
        "spellcheck=false placeholder='RESET'>"
        "<button type=submit style='background:#fee;color:#900;"
        "border:1px solid #c66;font-weight:400;margin-top:.4em'>"
        "Factory Reset</button>"
        "</form>";
    httpd_resp_send_chunk(req, tail_pre, sizeof(tail_pre) - 1);
    render_settings_section(req);
    httpd_resp_send_chunk(req, tail_post, sizeof(tail_post) - 1);
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

// Renders the printer-picker page (Phase B of #41). After a successful
// bambu_login that returned multiple printers, the wizard transitions
// here so the user can check off which to subscribe to. Defaults all
// online printers to checked, offline ones unchecked. Form fields
// "p0" through "p7" map to bambu_printer_info(0..7).
static void render_pick_printers(httpd_req_t *req) {
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    httpd_resp_send_chunk(req, html_head, sizeof(html_head) - 1);
    httpd_resp_send_chunk(req,
        "<h1>🦆 Pick your printers</h1>"
        "<p class=sub>I found these in your Bambu account. Check the ones "
        "you want me to listen to. The duck will speak about all of them; "
        "uncheck any you'd rather it stay quiet about.</p>"
        "<form method=POST action=/pick>", -1);
    int n = bambu_printers_count();
    for (int i = 0; i < n; i++) {
        bambu_printer_info_t info;
        if (!bambu_printer_info(i, &info)) continue;
        // HTML-safe rendering: extract_json_string already stripped
        // quotes/backslashes server-side, so we just need to escape
        // < > & for safety. Build inline; names are ≤31 chars.
        char safe_name[64];
        int o = 0;
        for (int k = 0; info.name[k] && o + 5 < (int)sizeof(safe_name); k++) {
            char c = info.name[k];
            if (c == '<')      { memcpy(safe_name + o, "&lt;",  4); o += 4; }
            else if (c == '>') { memcpy(safe_name + o, "&gt;",  4); o += 4; }
            else if (c == '&') { memcpy(safe_name + o, "&amp;", 5); o += 5; }
            else                safe_name[o++] = c;
        }
        safe_name[o] = '\0';
        const char *fallback = (info.name[0] == '\0') ? info.serial : safe_name;
        // Explicit id/for binding (instead of wrapping label) — iOS
        // captive-portal browser was unreliable about toggling the
        // checkbox when the label wrapped it. The for=id pattern is
        // bulletproof. Buffer sized for ~250 chars of format string
        // + ~64 chars of name + small substitutions, with margin.
        char chunk[512];
        // Checkbox state reflects current binding (info.subscribed),
        // not online status. The duck's row on the relay is the
        // source of truth for "is this printer being listened to";
        // online is a separate axis we just label visually.
        int cn = snprintf(chunk, sizeof(chunk),
            "<div style='padding:.7em 0;border-bottom:1px solid #eee'>"
            "<input type=checkbox id=p%d name=p%d value=1 %s>"
            "<label for=p%d style='display:inline;font-weight:400;cursor:pointer'>"
            "<strong>%s</strong> "
            "<span style='color:%s;font-size:.9em'>(%s)</span>"
            "</label>"
            "</div>",
            i, i,
            info.subscribed ? "checked" : "",
            i,
            fallback,
            info.online ? "#1b5e20" : "#999",
            info.online ? "online" : "offline");
        if (cn > 0) httpd_resp_send_chunk(req, chunk, cn);
    }
    // Settings on the picker too — re-entry path lets the user adjust
    // volume / movement mode / TZ without re-doing the full onboarding.
    // /pick handler parses these alongside the printer checkboxes.
    render_settings_section(req);
    httpd_resp_send_chunk(req,
        "<button type=submit>Save</button>"
        "</form>"
        // Escape hatch for the rare case where the user really wants
        // to wipe and re-onboard with different creds (changing Bambu
        // account, moving WiFi networks). Tucked at the bottom in
        // sub-text styling so it's not the first thing they see.
        "<form method=POST action=/restart style='margin-top:1.5em'>"
        "<button type=submit style='background:#eee;font-weight:400;"
        "color:#666;font-size:.9em'>"
        "Sign out and start over</button>"
        "</form>"
        // Factory Reset on the picker page — this is the most common
        // re-entry point (long-press while already onboarded) so the
        // hand-off path needs to be reachable here as well as the
        // first-run sign-in form. Same red styling + confirm dialog
        // as the version on render_form so the action looks
        // consistent and irreversible across pages.
        "<form method=POST action=/factory_reset style='margin-top:2em'>"
        "<p class=sub style='color:#900;margin-bottom:.4em'>"
        "Wipes WiFi + Bambu account + all settings. Cannot be undone.</p>"
        "<label for=frconfirm class=sub>Type RESET to confirm</label>"
        "<input type=text id=frconfirm name=confirm required "
        "pattern='[Rr][Ee][Ss][Ee][Tt]' "
        "autocomplete=off autocorrect=off autocapitalize=characters "
        "spellcheck=false placeholder='RESET'>"
        "<button type=submit style='background:#fee;color:#900;"
        "border:1px solid #c66;font-weight:400;margin-top:.4em'>"
        "Factory Reset</button>"
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
        case WIZ_PICK_PRINTERS:
            render_pick_printers(req);
            return ESP_OK;
        case WIZ_FAST_LOADING:
            render_status(req, "Checking your printers…",
                "Hold tight — pulling the current list from the relay.",
                true);
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
    // Relay URL — required on public builds (no compile-time default),
    // optional override on turnkey builds (compile-time default exists).
    // Persisted to NVS so subsequent sessions read it via relay_url_load
    // in agent.c. The save validator rejects anything that isn't ws://
    // or wss:// — typo'd URLs would otherwise produce cryptic WS errors
    // far from the input site.
    form_get(body, "rurl", s_relay_url, sizeof(s_relay_url));
    if (s_relay_url[0]) {
        esp_err_t err = relay_url_save(s_relay_url);
        if (err == ESP_OK) {
            ESP_LOGI(TAG, "relay URL saved to NVS: %s", s_relay_url);
        } else {
            ESP_LOGW(TAG, "relay URL save failed (%s): %s — sessions "
                          "will fall back to compile-time default if "
                          "any, otherwise refuse to start",
                     esp_err_to_name(err), s_relay_url);
        }
    }
#ifndef BAMBU_DUCK_TURNKEY
    // Public build hard-requires a URL. The form's `required` attribute
    // covers the typical browser case, but defend server-side too in
    // case the user's browser bypassed it (some captive-portal
    // browsers don't honor `required` on iOS).
    if (!s_relay_url[0] && !relay_url_has()) {
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_send(req,
            "Relay URL is required on this build. Deploy a relay first "
            "(see bambu/DEPLOY.md) then come back and paste its "
            "wss:// URL into the form.",
            HTTPD_RESP_USE_STRLEN);
        return ESP_OK;
    }
#endif
    // user_id is auto-resolved via /preference on the relay side now —
    // /preference proved reliable across testing. If Bambu ever breaks
    // /preference we fall back to relay-side env BAMBU_USER_ID, OR add
    // a recovery form. Not worth a captive-portal field today.
    s_bambu_user_id[0] = '\0';
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);

    // Settings (volume / movement mode / TZ) are independently NVS-
    // persisted on each form submission so users can change them
    // without re-doing the WiFi+Bambu round-trip. Empty fields ->
    // skip (keep existing). Apply via the audio + servo public APIs
    // so we don't open NVS handles directly here.
    char buf[16];
    if (form_get(body, "vol", buf, sizeof(buf)) && buf[0]) {
        int v = atoi(buf);
        if (v >= 0 && v <= 4) audio_set_volume_step((uint8_t)v);
    }
    if (form_get(body, "move", buf, sizeof(buf)) && buf[0]) {
        int m = atoi(buf);
        if (m >= 0 && m <= 2) servo_set_move_mode((servo_move_mode_t)m);
    }
    if (form_get(body, "tz", buf, sizeof(buf)) && buf[0]) {
        // Form value is a signed integer in minutes east of UTC.
        // atoi handles the sign; range-check inside the setter
        // rejects out-of-range values.
        servo_set_tz_offset_min((int16_t)atoi(buf));
    }

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

// /pick — Phase B of #41 picker submission. Reads checkbox state out
// of the POST body for fields p0..p7, looks up the corresponding
// serial via bambu_printer_info(), builds a pipe-delimited list, and
// sends set_printers over /ws/notify. Relay narrows the duck's MQTT
// subscriptions to that subset and acks. State advances to DONE on
// success; on failure we leave the user on the picker page so they
// can retry.
static esp_err_t pick_handler(httpd_req_t *req) {
    // Body capacity bumped from 256 → 512 to accommodate the settings
    // fields (vol, move, tz) appended in the same submission. Picker
    // bodies historically capped well under 200 bytes; settings add
    // ≤30 bytes; 512 leaves margin for future additions.
    char body[512] = {0};
    int len = req->content_len < (int)sizeof(body) - 1
                ? req->content_len : (int)sizeof(body) - 1;
    if (len > 0) {
        int got = httpd_req_recv(req, body, len);
        if (got > 0) body[got] = '\0';
    }

    // Settings — same shape as the form's /save handler; persisted via
    // public audio/servo APIs so this code doesn't touch NVS directly.
    // Empty fields skip (keep existing).
    char buf[16];
    if (form_get(body, "vol", buf, sizeof(buf)) && buf[0]) {
        int v = atoi(buf);
        if (v >= 0 && v <= 4) audio_set_volume_step((uint8_t)v);
    }
    if (form_get(body, "move", buf, sizeof(buf)) && buf[0]) {
        int m = atoi(buf);
        if (m >= 0 && m <= 2) servo_set_move_mode((servo_move_mode_t)m);
    }
    if (form_get(body, "tz", buf, sizeof(buf)) && buf[0]) {
        servo_set_tz_offset_min((int16_t)atoi(buf));
    }

    // Build the pipe-delimited serials list from checked p0..p7 boxes.
    // Unchecked boxes are absent from the form body entirely (HTML
    // checkbox semantics), so form_get returning false = unchecked.
    char serials_pipe[160] = {0};
    int chosen_count = 0;
    int n = bambu_printers_count();
    if (n > BAMBU_MAX_PRINTERS) n = BAMBU_MAX_PRINTERS;
    for (int i = 0; i < n; i++) {
        // Form field is "p0".."p7" — fixed-shape build avoids snprintf
        // truncation warnings under -Werror=format-truncation. n is
        // capped at BAMBU_MAX_PRINTERS == 8, so i ∈ [0, 8) and a
        // single digit always fits.
        char key[3] = {'p', (char)('0' + i), '\0'};
        char val[4] = {0};
        if (!form_get(body, key, val, sizeof(val)) || val[0] != '1') continue;
        bambu_printer_info_t info;
        if (!bambu_printer_info(i, &info)) continue;
        if (chosen_count > 0) strlcat(serials_pipe, "|", sizeof(serials_pipe));
        strlcat(serials_pipe, info.serial, sizeof(serials_pipe));
        chosen_count++;
    }

    if (chosen_count == 0) {
        // User unchecked everything — relay would have nothing to
        // subscribe to. Reject and let them try again.
        ESP_LOGW(TAG, "/pick: no printers checked, refusing to set empty");
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_send(req, "Pick at least one printer.",
                         HTTPD_RESP_USE_STRLEN);
        return ESP_OK;
    }

    bool ok = set_printers_send_via_ws(serials_pipe, 10000);
    if (!ok) {
        ESP_LOGW(TAG, "/pick: set_printers_send_via_ws failed — staying on picker");
        httpd_resp_set_status(req, "303 See Other");
        httpd_resp_set_hdr(req, "Location", "/");
        httpd_resp_send(req, NULL, 0);
        return ESP_OK;
    }

    ESP_LOGI(TAG, "/pick: %d printer(s) selected, set_printers ack OK",
             chosen_count);
    s_state = WIZ_DONE;
    // Render an inline success page instead of redirecting to /.
    // Redirecting forced the phone to load another page that AP-teardown
    // ate halfway through, which read as "wizard never ended." A direct
    // page tells the user "Save worked, you're done" before the AP
    // collapses under them.
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    httpd_resp_send_chunk(req, html_head, sizeof(html_head) - 1);
    httpd_resp_send_chunk(req,
        "<h1>🦆 All set!</h1>"
        "<p class=sub>Saved. The duck is closing this WiFi network — "
        "your phone will reconnect to your home WiFi automatically. "
        "You can close this page.</p>",
        -1);
    httpd_resp_send_chunk(req, html_tail, sizeof(html_tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);
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

// /factory_reset — full wipe for handing the duck off to a new owner.
//
//   1. Tell the relay to delete this duck's row (revokes the prior
//      owner's Bambu access_token + ElevenLabs creds + printer
//      binding immediately, even if step 3 fails).
//   2. Render a "Wiping..." page so the user sees something happen
//      before WiFi drops.
//   3. nvs_flash_erase() — wipes WiFi creds, volume step, the
//      provision_pending flag, anything else stored in NVS.
//   4. esp_restart() — comes up fresh-out-of-box on next boot, the
//      "press my button to set up" path.
//
// Worker pattern (deferred async): the HTTP request returns
// immediately with the wiping page; an actual wipe happens in a
// short-lived task so we don't fight the AP/HTTP teardown when
// nvs_flash_erase + restart fire.
static void factory_reset_worker(void *arg) {
    (void)arg;
    // Give the response a beat to flush to the browser before WiFi /
    // captive portal go away under it.
    vTaskDelay(pdMS_TO_TICKS(500));

    // Step 1: tell the relay to delete the row. Best-effort — chip
    // erase proceeds either way. 5s timeout so a flaky relay can't
    // strand the user mid-wipe.
    bool ok = wipe_duck_via_ws(5000);
    ESP_LOGI(TAG, "/factory_reset: relay wipe %s",
             ok ? "ack'd" : "skipped/failed (chip erase will proceed)");
    // Brief pause so any in-flight WS frame on the notify channel
    // can drain before we yank the rug.
    vTaskDelay(pdMS_TO_TICKS(500));

    // Step 2: erase the entire NVS partition. Wipes WiFi creds (the
    // "duck" namespace), volume step (the "audio" namespace), the
    // provision_pending flag, anything else. Next boot's nvs_flash_init
    // will re-create empty namespaces on demand.
    ESP_LOGI(TAG, "/factory_reset: erasing NVS");
    esp_err_t err = nvs_flash_erase();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_flash_erase failed: %s — restarting anyway",
                 esp_err_to_name(err));
    }

    // Step 3: reboot. The chip comes up with no WiFi creds, no Bambu
    // binding, plays the "press my button" phrase, fresh out of box
    // for the next owner.
    vTaskDelay(pdMS_TO_TICKS(200));
    esp_restart();
}

static esp_err_t factory_reset_handler(httpd_req_t *req) {
    // Read body — expect a `confirm` field containing "reset" (any
    // case). The form uses an HTML pattern attribute for client-side
    // validation, but a stray POST from a misconfigured proxy /
    // browser-prefetch / mistyped URL could otherwise wipe a duck.
    // Server-side check makes the wipe deliberate.
    char body[128] = {0};
    int len = req->content_len < (int)sizeof(body) - 1
                ? req->content_len : (int)sizeof(body) - 1;
    if (len > 0) {
        int got = httpd_req_recv(req, body, len);
        if (got > 0) body[got] = '\0';
    }
    char confirm[16] = {0};
    form_get(body, "confirm", confirm, sizeof(confirm));
    bool ok = (strcasecmp(confirm, "reset") == 0);
    if (!ok) {
        ESP_LOGW(TAG, "/factory_reset: rejected — confirm field did not "
                      "contain 'reset' (got %d chars)",
                 (int)strlen(confirm));
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_send(req, "Type RESET in the confirmation field.",
                         HTTPD_RESP_USE_STRLEN);
        return ESP_OK;
    }

    // Show a confirmation page that survives the imminent reboot —
    // by the time the user reads it, WiFi/AP are gone. They'll need
    // to power-cycle or just plug into a new network for the next
    // owner.
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    httpd_resp_send_chunk(req, html_head, sizeof(html_head) - 1);
    httpd_resp_send_chunk(req,
        "<h1>Wiping this duck</h1>"
        "<p class=sub>Clearing WiFi, Bambu account, and relay binding. "
        "The duck will reboot in a few seconds. This page won't update — "
        "the duck's WiFi network is going away.</p>"
        "<p class=sub>Power-cycle to confirm: when you next plug it in, "
        "it should ask you to press its button to start setup.</p>",
        -1);
    httpd_resp_send_chunk(req, html_tail, sizeof(html_tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);

    ESP_LOGW(TAG, "/factory_reset: triggered — spawning wipe worker");
    xTaskCreate(factory_reset_worker, "fact_rst", 4096, NULL, 5, NULL);
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
    //    to the relay's edge takes ~500ms-2s typically.
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
    //    Turnkey builds skip this entirely — the relay already has the
    //    shared creds as Fly secrets and per-duck creds aren't collected.
#ifndef BAMBU_DUCK_TURNKEY
    char eleven_key_local[80] = {0}, eleven_agent_local[40] = {0};
    if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
    strlcpy(eleven_key_local,   s_eleven_key,   sizeof(eleven_key_local));
    strlcpy(eleven_agent_local, s_eleven_agent, sizeof(eleven_agent_local));
    if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);
    if (eleven_key_local[0] && eleven_agent_local[0]) {
        // 10s timeout — relay's upsert is sub-millisecond; anything
        // taking longer is a network/relay problem worth surfacing.
        bool ok = eleven_creds_send_via_ws(eleven_key_local,
                                            eleven_agent_local, 10000);
        if (ok) {
            // Forget the key on chip — relay holds it now.
            if (s_creds_mutex) xSemaphoreTake(s_creds_mutex, portMAX_DELAY);
            memset(s_eleven_key, 0, sizeof(s_eleven_key));
            if (s_creds_mutex) xSemaphoreGive(s_creds_mutex);
        } else {
            // Keep the buffer so a future retry path can resend.
            // For now we just log — captive portal will keep going
            // with bambu_login; a missing eleven row on the relay
            // means /ws/duck falls back to env-var creds (shared
            // deployments) or fails cleanly with a 1011 close
            // (self-hosted with no env fallback). Either way the
            // user finds out at first conversation, not silently.
            ESP_LOGW(TAG, "set_eleven_creds did not ack — relay won't "
                          "have per-duck creds for this chip");
        }
    }
#endif

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
            // Phase B of #41 — if the relay returned ≥2 printers, give
            // the user a chance to opt some out. One-printer accounts
            // skip the picker (no choice to make).
            if (bambu_printers_count() >= 2) {
                s_state = WIZ_PICK_PRINTERS;
            } else {
                s_state = WIZ_DONE;
            }
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
            // Same picker-vs-done branch as the initial login worker.
            if (bambu_printers_count() >= 2) {
                s_state = WIZ_PICK_PRINTERS;
            } else {
                s_state = WIZ_DONE;
            }
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

// Settings-only fast-path. Long-press while already onboarded means
// the user just wants to pick printers — they don't need (and don't
// want) to re-enter WiFi/Bambu/ElevenLabs creds. This worker uses the
// existing WiFi association to talk to the relay, pulls the current
// printer list via list_printers (which uses the stored access_token —
// no re-auth), and transitions the wizard straight to PICK_PRINTERS.
//
// On any failure (no WiFi, no relay row, expired token, network blip)
// we fall back to the standard COLLECT_WIFI form so the user has an
// escape hatch for "actually I do need to redo onboarding."
static void fast_path_worker_task(void *arg) {
    // Use the existing STA association — wifi_init already brought
    // it up if NVS had creds, and APSTA mode preserves the
    // association. Just wait briefly for the netif to be ready.
    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
        BIT_STA_GOT_IP, pdFALSE, pdFALSE, pdMS_TO_TICKS(15000));
    if (!(bits & BIT_STA_GOT_IP)) {
        // STA didn't come up — could be a roam, AP outage, anything.
        // Bail to the form so the user can re-enter creds if needed.
        ESP_LOGW(TAG, "fast_path: STA not up, falling back to form");
        s_state = WIZ_COLLECT_WIFI;
        vTaskDelete(NULL);
        return;
    }

    notify_task_start();

    int waited = 0;
    while (!notify_ws_is_connected() && waited < 15000) {
        vTaskDelay(pdMS_TO_TICKS(200));
        waited += 200;
    }
    if (!notify_ws_is_connected()) {
        ESP_LOGW(TAG, "fast_path: notify WS didn't come up, falling back");
        s_state = WIZ_COLLECT_WIFI;
        vTaskDelete(NULL);
        return;
    }

    bool ok = list_printers_via_ws(15000);
    if (ok && bambu_printers_count() >= 1) {
        ESP_LOGI(TAG, "fast_path: %d printers, jumping to picker",
                 bambu_printers_count());
        s_state = WIZ_PICK_PRINTERS;
    } else {
        ESP_LOGW(TAG, "fast_path: no printers from relay, falling back to form");
        s_state = WIZ_COLLECT_WIFI;
    }
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

    // Spoken hint (#34): tells the user the AP is broadcasting and
    // what name to look for. Plays once when the wizard's AP first
    // comes online — before they've had a chance to look for it.
    // No-ops if phrases haven't been generated. Delegated to a brief
    // task so we don't block the rest of wizard setup on audio
    // playback (~3s for the "WiFi's up..." clip).
    phrase_play(PHRASE_WIFI_UP);

    // HTTP server + DNS hijack (captive-portal pop-up).
    httpd_handle_t server = NULL;
    httpd_config_t hcfg = HTTPD_DEFAULT_CONFIG();
    hcfg.lru_purge_enable = true;
    ESP_ERROR_CHECK(httpd_start(&server, &hcfg));
    httpd_uri_t root = { .uri = "/", .method = HTTP_GET, .handler = root_handler };
    httpd_uri_t save = { .uri = "/save", .method = HTTP_POST, .handler = save_handler };
    httpd_uri_t code = { .uri = "/code", .method = HTTP_POST, .handler = code_handler };
    httpd_uri_t pick = { .uri = "/pick", .method = HTTP_POST, .handler = pick_handler };
    httpd_uri_t rstr = { .uri = "/restart", .method = HTTP_POST, .handler = restart_handler };
    httpd_uri_t fres = { .uri = "/factory_reset", .method = HTTP_POST, .handler = factory_reset_handler };
    httpd_register_uri_handler(server, &root);
    httpd_register_uri_handler(server, &save);
    httpd_register_uri_handler(server, &code);
    httpd_register_uri_handler(server, &pick);
    httpd_register_uri_handler(server, &rstr);
    httpd_register_uri_handler(server, &fres);
    httpd_register_err_handler(server, HTTPD_404_NOT_FOUND, captive_redirect);
    xTaskCreate(dns_hijack_task, "dns_hijack", 4096, NULL, 5, NULL);

    // Settings-only fast-path: if WiFi NVS still has saved creds, the
    // user pressed long-press to change something (almost always the
    // printer selection) — not to re-do onboarding from scratch. Use
    // the saved WiFi to reconnect STA in the background and pull the
    // current printer list from the relay. Land the user on the picker
    // page directly. Falls back to the standard form if anything goes
    // sideways (no relay row, expired token, WiFi changed).
    if (wifi_has_creds()) {
        char ssid[33] = {0}, pw[65] = {0};
        if (wifi_load_creds(ssid, sizeof(ssid),
                             pw, sizeof(pw)) == ESP_OK) {
            wifi_config_t sta_cfg = {0};
            strncpy((char *)sta_cfg.sta.ssid, ssid, sizeof(sta_cfg.sta.ssid));
            strncpy((char *)sta_cfg.sta.password, pw, sizeof(sta_cfg.sta.password));
            sta_cfg.sta.threshold.authmode = WIFI_AUTH_OPEN;
            sta_cfg.sta.pmf_cfg.capable = true;
            sta_cfg.sta.pmf_cfg.required = false;
            ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_cfg));
            ESP_ERROR_CHECK(esp_wifi_connect());
            s_state = WIZ_FAST_LOADING;
            xTaskCreate(fast_path_worker_task, "fast_path",
                         6144, NULL, 4, NULL);
            ESP_LOGI(TAG, "fast-path enabled (WiFi creds in NVS) — "
                          "wizard will skip form if relay binding still valid");
        }
    }

    // Block until the wizard reaches DONE OR a hard timeout fires OR
    // the user presses the physical button (universal "I'm done"
    // cancel). Without these, a user who long-presses by mistake or
    // dismisses the captive portal without saving leaves the AP
    // broadcasting forever — chatty radio + confusing entry point on
    // someone's phone. 5 minutes is plenty for any legitimate
    // onboarding including 2FA email lookup; if a user genuinely
    // needs longer they can just long-press again.
    //
    // We poll BUTTON_PIN directly here rather than going through
    // wake.c — provision_run is a blocking call from main, the wake
    // task is suppressed during this window, and a direct read with
    // a 50ms debounce is the simplest correct shape.
    gpio_set_direction(BUTTON_PIN, GPIO_MODE_INPUT);
    gpio_set_pull_mode(BUTTON_PIN, GPIO_PULLUP_ONLY);
    const int64_t WIZARD_TIMEOUT_MS = 5 * 60 * 1000;
    int64_t start_ms = esp_timer_get_time() / 1000;
    bool timed_out = false;
    bool cancelled = false;
    while (s_state != WIZ_DONE) {
        vTaskDelay(pdMS_TO_TICKS(250));
        int64_t elapsed = (esp_timer_get_time() / 1000) - start_ms;
        if (elapsed > WIZARD_TIMEOUT_MS) {
            ESP_LOGW(TAG, "wizard timed out after %lld ms in state=%d — "
                          "tearing down AP, returning to idle",
                     (long long)elapsed, (int)s_state);
            timed_out = true;
            break;
        }
        // Active-low button. Wait at least 1s before polling to avoid
        // catching the same long-press event that just bounced us
        // into the wizard.
        if (elapsed > 1500 && gpio_get_level(BUTTON_PIN) == 0) {
            vTaskDelay(pdMS_TO_TICKS(50));
            if (gpio_get_level(BUTTON_PIN) == 0) {
                ESP_LOGI(TAG, "button pressed during wizard — cancel");
                cancelled = true;
                break;
            }
        }
    }
    if (!timed_out && !cancelled) {
        ESP_LOGI(TAG, "wizard reached DONE — brief AP-up window for success page");
        // Just enough for the HTTP response to flush + the phone to
        // render the "All set" page (~800ms). Was 3s and read as
        // "wizard is stuck" — user complained the AP lingered too
        // long. The success page already flashes the meaningful
        // confirmation before this delay; this is purely buffer for
        // the response/render to land.
        vTaskDelay(pdMS_TO_TICKS(800));
    }
    ESP_LOGI(TAG, "tearing down AP (timed_out=%d cancelled=%d)",
             timed_out, cancelled);
    httpd_stop(server);
    esp_wifi_set_mode(WIFI_MODE_STA);  // drops AP, keeps STA connected
    // Both timed_out and cancelled are user-driven exits with no data
    // changed — return ESP_ERR_TIMEOUT so main.c chirps quietly and
    // drops back to idle. Reserved ESP_OK for the actual success path.
    return (timed_out || cancelled) ? ESP_ERR_TIMEOUT : ESP_OK;
}
