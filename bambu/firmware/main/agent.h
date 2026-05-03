#pragma once
#include <stdbool.h>
#include <esp_err.h>

// Run an audio session to the relay. If `event` is non-NULL the relay treats
// this as a notification-triggered session: it suppresses the agent's default
// greeting and injects a "Printer notice: ..." user_message built from event
// + subtask, so the LLM phrases the announcement in its own voice. When
// event is NULL (button press), the agent opens normally. `subtask` may be
// NULL when unknown — the relay will say "your print" instead.
esp_err_t agent_run_session(const char *event, const char *subtask);

// Spawn the long-lived /ws/notify task. Call once after WiFi (STA) is up.
// On notify events the task triggers a session via the same code path as
// a button press, passing event+subtask through to the relay as query
// params. Idempotent — safe to call from the APSTA wizard then again
// from main.c (no-op the second time).
esp_err_t notify_task_start(void);

// True if the long-lived /ws/notify connection is currently open. Used by
// the captive-portal wizard to wait until the WS is up before sending
// bambu_login messages.
bool notify_ws_is_connected(void);

// State accessors used by wake.c (tap-to-wake) to gate the mic-monitor —
// during a session and during agent speech, tap detection is suppressed
// (otherwise the agent's own consonants and the spk-to-mic acoustic path
// would self-trigger).
bool agent_session_active(void);
bool agent_speaking(void);

// ---- Bambu login over the existing /ws/notify channel ----
//
// The captive-portal APSTA wizard uses this to forward credentials to
// the relay without the chip ever doing TLS itself (chip-side mbedtls
// reliably fails handshake against ngrok's Cloudflare edge — see git
// log around iteration B/C). Plain WebSocket frames travel over ngrok's
// TCP tunnel; the relay does the real Bambu cloud TLS via Python httpx.

typedef enum {
    BAMBU_LOGIN_WS_OK         = 0,
    BAMBU_LOGIN_WS_NEED_2FA   = 1,
    BAMBU_LOGIN_WS_BAD_CREDS  = 2,
    BAMBU_LOGIN_WS_RELAY_DOWN = 3,
    BAMBU_LOGIN_WS_TIMEOUT    = 4,
} bambu_login_ws_result_t;

// Send {"type":"bambu_login","email","password","code","user_id"} over the
// long-lived /ws/notify WS to the relay, block until the matching
// {"type":"bambu_login_result"} comes back or timeout_ms elapses.
// Requires notify_task_start() to have been called and the WS to be up.
// Empty `code` is fine for the first attempt; relay returns NEED_2FA,
// captive portal collects the code and re-calls.
bambu_login_ws_result_t bambu_login_via_ws(const char *email,
                                            const char *password,
                                            const char *code,
                                            const char *user_id,
                                            int timeout_ms);
