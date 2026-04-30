#pragma once
#include <esp_err.h>

// Run an audio session to the relay. If `first_message` is non-NULL, it's
// passed to the relay as a query param so the agent leads with that text
// instead of "Yeah?" — used for notification-triggered sessions.
esp_err_t agent_run_session(const char *first_message);

// Spawn the long-lived /ws/notify task. Call once at boot after WiFi up.
// On notify events, the task triggers a session via the same code path as
// a button press, with the headline as first_message.
esp_err_t notify_task_start(void);
