# Duck Duck Duck Plugin — Known Risks & Future Concerns

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

## ~/.duck/ directory (resolved)

All widget storage moved to `~/Library/Application Support/DuckDuckDuck/` (sandbox-safe). The widget no longer writes to `~/.duck/`. Legacy migration in `HookInstaller.migrateLegacy()` cleans up old installs.

## Shell scripts in plugin require bash

The plugin's hook scripts use `#!/bin/bash`. If a user's system doesn't have bash at `/bin/bash` (unlikely on macOS but possible on exotic setups), hooks fail silently.

## Hooks cached at session start

Claude Code loads hooks once when a session starts. If the widget isn't running when Claude starts, hooks fire but fail (connection refused to localhost:3333). Restarting the widget mid-session fixes it, but the user might not realize they need to restart Claude too if hooks were misconfigured at launch.

## Renaming checklist

If the product name changes again, update all of these:

| What | Where |
|------|-------|
| Plugin name | `plugin/.claude-plugin/plugin.json` → `"name"` |
| Plugin description | `plugin/.claude-plugin/plugin.json` → `"description"` |
| Marketplace name | `.claude-plugin/marketplace.json` → `"name"` |
| Marketplace plugin entry | `.claude-plugin/marketplace.json` → `plugins[0].name` + `description` |
| Hooks description | `plugin/hooks/hooks.json` → `"description"` |
| Bundle ID | `widget/Info.plist` → `CFBundleIdentifier` |
| Display name | `widget/Info.plist` → `CFBundleName` |
| Permission strings | `widget/Info.plist` → `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` |
| App Support dir | `widget/Sources/.../DuckConfig.swift` → `storageDir` path component |
| API key dialog | `widget/Sources/.../DuckConfig.swift` → `promptForAPIKey()` text |
| Log file name | `widget/Sources/.../DuckLog.swift` → `logURL` path component |
| Log file comment | `widget/Sources/.../DuckLog.swift` → header comment |
| Speech log name | `widget/Sources/.../SpeechService.swift` → `logURL` + header comment |
| Plugin README | `plugin/README.md` |
| Plugin PLAN | `plugin/PLAN.md` (historical, bulk replace) |

After updating, also:
1. `cd widget && swift build` — verify it compiles
2. Remove old marketplace: `claude plugin marketplace remove <old-name>-marketplace`
3. Push changes to GitHub
4. Re-add marketplace: `claude plugin marketplace add ideo/Rubber-Duck`
5. Install new plugin: `claude plugin install <new-name>`
6. Start a new Claude Code session (hooks are cached at session start)
