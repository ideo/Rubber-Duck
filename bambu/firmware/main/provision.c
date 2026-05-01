// SoftAP onboarding wizard — see provision.h for the flow narrative.
//
// Phase 1: minimum viable. SoftAP + HTTP form + NVS write + reboot. No DNS
// hijack (no captive-portal auto-pop), no multi-network slots (#30), no
// Bambu OAuth (#31). Each is a follow-up that extends THIS file rather
// than replaces it.
#include "provision.h"
#include "wifi.h"

#include <stdio.h>
#include <string.h>

#include <esp_event.h>
#include <esp_http_server.h>
#include <esp_log.h>
#include <esp_mac.h>
#include <esp_netif.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <lwip/sockets.h>
#include <lwip/netdb.h>

static const char *TAG = "provision";

// Number of scan results we keep + render in the SSID dropdown. 16 covers
// every realistic home situation; cap protects the small RAM page buffer.
#define SCAN_MAX 16
static wifi_ap_record_t s_scan_results[SCAN_MAX];
static uint16_t s_scan_count = 0;

// Once the POST handler successfully saves creds we set this flag. The
// main task (wifi_provision_run) polls and calls esp_restart() — we don't
// reboot from inside the HTTP handler so the response can flush first.
static volatile bool s_provision_done = false;

// ---- DNS hijack (captive portal popup magic) ----
//
// Phones detect captive portals by querying a known URL after joining a WiFi
// network and seeing whether they get their expected response. iOS hits
// captive.apple.com, Android hits connectivitycheck.gstatic.com, etc. If
// the response isn't what they expect, the OS pops up an in-app browser
// showing whatever URL they got redirected to — that's the magical "join
// network → setup page appears" UX.
//
// Two pieces make it work:
//   1. DNS hijack (this task): respond to EVERY DNS query with our IP
//      (192.168.4.1) so all the captive-portal probe hostnames resolve
//      to us instead of failing with NXDOMAIN.
//   2. HTTP catch-all (root_handler + the 404 err handler below): return
//      a 302 redirect to / on any URL the phone probes, so the phone's
//      probe request lands on our setup page.

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
        if (n < 12) continue;  // DNS header is 12 bytes minimum

        // Craft a response in-place by editing the query header + appending
        // an answer record. DNS message format (RFC 1035):
        //   header (12 bytes), question section, [answer section], ...
        //
        // We set QR=1 (response), RA=1 (recursion available), ANCOUNT=1,
        // and append a single A-record pointing at 192.168.4.1.
        buf[2] = 0x81;  // QR=1, opcode=0, AA=0, TC=0, RD=1
        buf[3] = 0x80;  // RA=1, Z=0, RCODE=0
        // ancount = 1
        buf[6] = 0x00;
        buf[7] = 0x01;

        // Walk past the question name (length-prefixed labels, ends with \0)
        // then skip the 4-byte QTYPE+QCLASS.
        int q_end = 12;
        while (q_end < n && buf[q_end] != 0) {
            int len = buf[q_end];
            if (len == 0 || q_end + 1 + len >= n) break;  // malformed; bail
            q_end += 1 + len;
        }
        q_end += 5;  // null label + qtype(2) + qclass(2)
        if (q_end + 16 > (int)sizeof(buf)) continue;  // no room for answer

        // Answer record — name pointer to question (offset 12), type A,
        // class IN, TTL 60, RDLENGTH 4, RDATA 192.168.4.1.
        uint8_t *p = buf + q_end;
        *p++ = 0xc0; *p++ = 0x0c;     // pointer to question's name
        *p++ = 0x00; *p++ = 0x01;     // TYPE = A
        *p++ = 0x00; *p++ = 0x01;     // CLASS = IN
        *p++ = 0x00; *p++ = 0x00; *p++ = 0x00; *p++ = 60;  // TTL = 60s
        *p++ = 0x00; *p++ = 0x04;     // RDLENGTH = 4
        *p++ = 192;  *p++ = 168; *p++ = 4; *p++ = 1;       // 192.168.4.1
        int outlen = p - buf;

        sendto(sock, buf, outlen, 0, (struct sockaddr *)&src, srclen);
    }
}

// HTTPD 404 handler — phones probe URLs we don't have routes for (Apple's
// /hotspot-detect.html, Android's /generate_204, /gen_204, etc). Redirect
// every miss to / so the OS's auto-pop browser ends up on our setup form.
static esp_err_t captive_redirect(httpd_req_t *req, httpd_err_code_t err) {
    httpd_resp_set_status(req, "302 Found");
    httpd_resp_set_hdr(req, "Location", "http://192.168.4.1/");
    httpd_resp_send(req, NULL, 0);
    return ESP_OK;
}

// ---- HTTP handlers ----

// URL-decode in place. Form-urlencoded: '+' → ' ', %XX → byte. No fancy
// unicode handling — passwords tend to be ASCII and ESP-IDF's printf chain
// is single-byte clean. Length stays the same or shrinks.
static void url_decode(char *s) {
    char *r = s, *w = s;
    while (*r) {
        if (*r == '+') { *w++ = ' '; r++; }
        else if (*r == '%' && r[1] && r[2]) {
            char hex[3] = { r[1], r[2], 0 };
            *w++ = (char)strtol(hex, NULL, 16);
            r += 3;
        } else {
            *w++ = *r++;
        }
    }
    *w = '\0';
}

// Find the value of `key` in a urlencoded body and url-decode it into `out`.
// Returns false if key not found.
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

static esp_err_t root_handler(httpd_req_t *req) {
    // Compose the HTML page in chunks so we never need a single big buffer.
    // Phone-friendly: no external assets, single column, comfortable input
    // sizing. Inline CSS keeps it self-contained.
    httpd_resp_set_type(req, "text/html; charset=utf-8");
    static const char head[] =
        "<!doctype html><html><head><meta charset=utf-8>"
        "<meta name=viewport content='width=device-width,initial-scale=1'>"
        "<title>Set up Duck</title>"
        "<style>"
        "body{font-family:-apple-system,system-ui,sans-serif;max-width:420px;"
        "margin:2em auto;padding:0 1em;color:#222}"
        "h1{font-size:1.4em}label{display:block;margin:1em 0 .25em;font-weight:600}"
        "input,select{width:100%;padding:.7em;font-size:1em;box-sizing:border-box;"
        "border:1px solid #aaa;border-radius:6px}"
        "button{margin-top:1.5em;width:100%;padding:.9em;font-size:1.05em;"
        "background:#f5b942;border:0;border-radius:6px;font-weight:600}"
        ".sub{color:#666;font-size:.9em}"
        "</style></head><body>"
        "<h1>🦆 Hi! Tell me your WiFi.</h1>"
        "<p class=sub>I'll join your network so I can talk to your printer.</p>"
        "<form method=POST action=/save>"
        "<label for=ssid>Network</label>"
        "<select id=ssid name=ssid required>";
    httpd_resp_send_chunk(req, head, sizeof(head) - 1);

    if (s_scan_count == 0) {
        static const char none[] = "<option value=''>(no networks found — type below)</option>";
        httpd_resp_send_chunk(req, none, sizeof(none) - 1);
    }
    for (int i = 0; i < s_scan_count; i++) {
        char opt[80];
        // SSID can contain HTML-special chars in theory (' " < >) but in
        // practice it's basically ASCII. We escape <, >, & defensively.
        char clean[33];
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

    // Defeat password-manager "suggest strong password" pop-up. iOS Keychain
    // / 1Password / Chrome treat any <input type=password> as a signup field
    // by default. The combination below is the conventional escape hatch:
    //   autocomplete=off            — generic disable (Chrome partially ignores)
    //   passwordrules=""            — Apple-specific "no rules apply"
    //   autocorrect/cap/spellcheck  — signal "not text input"
    //   name=pw (not "pass")        — dodges browser heuristics that key on
    //                                 the literal substring "pass" in name/id
    static const char tail[] =
        "</select>"
        "<label for=pw>Password</label>"
        "<input type=password id=pw name=pw autocomplete=off"
        " autocorrect=off autocapitalize=off spellcheck=false passwordrules=\"\">"
        "<button type=submit>Connect</button>"
        "</form></body></html>";
    httpd_resp_send_chunk(req, tail, sizeof(tail) - 1);
    httpd_resp_send_chunk(req, NULL, 0);  // end
    return ESP_OK;
}

static esp_err_t save_handler(httpd_req_t *req) {
    char body[256] = {0};
    int len = req->content_len < (int)sizeof(body) - 1 ? req->content_len : (int)sizeof(body) - 1;
    int got = httpd_req_recv(req, body, len);
    if (got <= 0) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }
    body[got] = '\0';

    char ssid[33] = {0};
    char pass[65] = {0};
    if (!form_get(body, "ssid", ssid, sizeof(ssid)) || ssid[0] == '\0') {
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_send(req, "Missing ssid", HTTPD_RESP_USE_STRLEN);
        return ESP_OK;
    }
    form_get(body, "pw", pass, sizeof(pass));  // optional (open networks)

    esp_err_t err = wifi_save_creds(ssid, pass);
    if (err != ESP_OK) {
        httpd_resp_send_500(req);
        return ESP_FAIL;
    }

    httpd_resp_set_type(req, "text/html; charset=utf-8");
    static const char ok[] =
        "<!doctype html><html><head><meta charset=utf-8>"
        "<meta name=viewport content='width=device-width,initial-scale=1'>"
        "<style>body{font-family:-apple-system,sans-serif;max-width:420px;"
        "margin:3em auto;padding:0 1em;text-align:center}</style>"
        "</head><body><h1>🦆 Got it!</h1>"
        "<p>Rebooting and connecting to your network. You can disconnect "
        "from the duck's WiFi now.</p></body></html>";
    httpd_resp_send(req, ok, sizeof(ok) - 1);

    s_provision_done = true;
    return ESP_OK;
}

// ---- Wizard orchestration ----

static esp_err_t scan_visible_networks(void) {
    // Scan in STA mode first — gets a fresh list of nearby APs without the
    // softap interference that you'd see in APSTA mode. Default is active
    // scan (probe requests). 4s total covers all 2.4 GHz channels.
    wifi_scan_config_t scan = {
        .ssid = NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = false,
        .scan_type = WIFI_SCAN_TYPE_ACTIVE,
        .scan_time.active = { .min = 100, .max = 300 },
    };
    esp_err_t err = esp_wifi_scan_start(&scan, true);  // blocking
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "scan failed: %s — proceeding without dropdown",
                 esp_err_to_name(err));
        s_scan_count = 0;
        return ESP_OK;  // not fatal; user can type SSID manually if needed
    }
    s_scan_count = SCAN_MAX;
    err = esp_wifi_scan_get_ap_records(&s_scan_count, s_scan_results);
    if (err != ESP_OK) s_scan_count = 0;
    ESP_LOGI(TAG, "scan found %d networks", s_scan_count);
    return ESP_OK;
}

esp_err_t wifi_provision_run(void) {
    ESP_LOGI(TAG, "starting SoftAP onboarding");

    // Compose the AP SSID from the WiFi MAC's last 4 hex chars so each
    // duck shows up uniquely on the user's phone WiFi list. Easier when
    // multiple ducks are around (or for support: "what's the number on
    // the back of your duck?").
    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_SOFTAP);
    char ap_ssid[32];
    snprintf(ap_ssid, sizeof(ap_ssid), "DuckDuckDuck-%02X%02X", mac[4], mac[5]);

    // Init netif + event loop. Idempotent if already initialized by a
    // failed wifi_connect_blocking call before us.
    esp_netif_init();
    esp_event_loop_create_default();

    // Need the AP netif handle so the HTTP server has somewhere to bind.
    // The default config gives us 192.168.4.1.
    esp_netif_create_default_wifi_ap();
    esp_netif_create_default_wifi_sta();  // also need STA for the scan step

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));

    // Phase A: STA-only mode for the scan.
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    scan_visible_networks();
    ESP_ERROR_CHECK(esp_wifi_stop());

    // Phase B: switch to AP mode and start broadcasting.
    wifi_config_t ap_cfg = {0};
    strncpy((char *)ap_cfg.ap.ssid, ap_ssid, sizeof(ap_cfg.ap.ssid));
    ap_cfg.ap.ssid_len = strlen(ap_ssid);
    ap_cfg.ap.channel = 1;
    ap_cfg.ap.max_connection = 4;
    ap_cfg.ap.authmode = WIFI_AUTH_OPEN;  // No password; UX-first.
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &ap_cfg));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "AP up: SSID=%s, IP=192.168.4.1", ap_ssid);

    // Phase C: HTTP server + captive-portal magic.
    httpd_handle_t server = NULL;
    httpd_config_t hcfg = HTTPD_DEFAULT_CONFIG();
    hcfg.lru_purge_enable = true;
    ESP_ERROR_CHECK(httpd_start(&server, &hcfg));

    httpd_uri_t root = { .uri = "/", .method = HTTP_GET, .handler = root_handler };
    httpd_uri_t save = { .uri = "/save", .method = HTTP_POST, .handler = save_handler };
    httpd_register_uri_handler(server, &root);
    httpd_register_uri_handler(server, &save);
    // Anything else (the OS's captive-portal probe URLs, /favicon.ico, etc.)
    // gets a 302 to / so the auto-pop browser lands on our form.
    httpd_register_err_handler(server, HTTPD_404_NOT_FOUND, captive_redirect);

    // DNS hijack — must run alongside HTTP so the OS's probe-URL hostnames
    // resolve to us. 4KB stack is plenty for the trivial UDP loop.
    xTaskCreate(dns_hijack_task, "dns_hijack", 4096, NULL, 5, NULL);

    // Phase D: wait for the user. The save_handler sets s_provision_done
    // AFTER sending the success page so the response flushes first.
    while (!s_provision_done) {
        vTaskDelay(pdMS_TO_TICKS(500));
    }

    // Brief settle so the HTTP TCP FIN gets out the door before we kill
    // the radio.
    vTaskDelay(pdMS_TO_TICKS(1500));

    ESP_LOGI(TAG, "provisioning complete — restarting");
    esp_restart();
    return ESP_OK;  // not reached
}
