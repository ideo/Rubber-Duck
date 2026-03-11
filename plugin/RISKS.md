# Rubber Duck Plugin — Known Risks & Future Concerns

## Port 3333 hardcoded

The widget binds `localhost:3333` and the plugin scripts POST to it. If another app uses 3333, both break silently.

**Mitigation today**: Port 3333 is uncommon. duck-env.sh supports `DUCK_PORT` override via `~/.duck/config`.

**Problem when sandboxed**: The widget can't write `~/.duck/config` from inside an App Store sandbox. The plugin scripts can't discover the port dynamically.

**Future options**:
- Hardcode 3333 everywhere, fail with a clear error if taken
- Widget writes port to its sandbox container; plugin reads from a known container path (couples to bundle ID)
- App Group container shared between widget + a helper tool
- Bonjour/mDNS service advertisement (overkill but robust)

**Goal**: Nobody should ever have to think about this.

## ~/.duck/ directory not sandbox-safe

The widget currently writes to `~/.duck/` for:
- `config` — port, API key, preferences
- `.plugin-mode` — sentinel to prevent HookInstaller from running
- `hooks/` — shell scripts (eliminated by plugin, but dir still exists)

Under App Store sandbox, all of these need to move to the app's container or be eliminated. The plugin removed the need for `hooks/`, but `config` and `.plugin-mode` remain.

## Shell scripts in plugin require bash

The plugin's hook scripts use `#!/bin/bash`. If a user's system doesn't have bash at `/bin/bash` (unlikely on macOS but possible on exotic setups), hooks fail silently.

## Hooks cached at session start

Claude Code loads hooks once when a session starts. If the widget isn't running when Claude starts, hooks fire but fail (connection refused to localhost:3333). Restarting the widget mid-session fixes it, but the user might not realize they need to restart Claude too if hooks were misconfigured at launch.
