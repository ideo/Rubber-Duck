#pragma once
#include <esp_err.h>

// Open a WebSocket session to ElevenAgents using `signed_url`. Spawns a
// task that pumps mic frames up and audio events down. Blocks until the
// session ends (button release, idle timeout, or WS close).
esp_err_t agent_run_session(const char *signed_url);
