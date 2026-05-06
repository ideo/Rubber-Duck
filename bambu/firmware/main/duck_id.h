#pragma once
// Stable per-chip identifier, derived once at first call from the
// SoftAP MAC. Format: 12 hex chars, lowercase, no separators (e.g.
// "1cdbd45a7e34"). Used as the duck's tenancy key on the relay —
// every WS handshake carries it as `X-Duck-Id`, and the bambu_login
// JSON body includes it so the relay knows which row to write.
//
// Same MAC source as the captive portal's AP SSID — keeps the two
// stable identifiers (AP name suffix and tenant id) in sync, which
// makes "the AP I joined was DuckDuckDuck-XXXX" match "the duck row
// is the one ending in XXXX" when an operator stares at the DB.
//
// Thread-safe — internal init guarded by a one-shot. Returns a
// pointer to a static buffer, valid for the life of the program.
const char *duck_id_get(void);
