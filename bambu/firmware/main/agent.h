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

// Spawn the long-lived /ws/notify task. Call once at boot after WiFi up.
// On notify events the task triggers a session via the same code path as
// a button press, passing event+subtask through to the relay as query params.
esp_err_t notify_task_start(void);

// State accessors used by wake.c (tap-to-wake) to gate the mic-monitor —
// during a session and during agent speech, tap detection is suppressed
// (otherwise the agent's own consonants and the spk-to-mic acoustic path
// would self-trigger).
bool agent_session_active(void);
bool agent_speaking(void);
