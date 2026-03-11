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

All widget storage moved to `~/Library/Application Support/DuckDuckDuck/` (sandbox-safe). The widget no longer writes to `~/.duck/`. Legacy migration code has been removed.

## Mac App Store sandbox violations

Tested via `make sandbox` (ad-hoc signed with App Sandbox entitlements) on 2026-03-11.

### Confirmed working in sandbox

| Feature | How tested | Notes |
|---------|-----------|-------|
| App launch + storage dir | App launched, API key prompt appeared | `~/Library/Application Support/DuckDuckDuck/` works |
| API key storage | Pasted key, app saved and loaded it | FileManager container APIs fine |
| TTS via `/usr/bin/say` | Duck spoke greeting on launch | No Process() restriction for system binaries |
| LaunchGreeting | "They're back already" — context-aware | Time/recency logic works |
| NWListener (localhost:3333) | Dashboard loaded in browser | Server binding works |
| Microphone + STT | "ducky hello" recognized | SFSpeechRecognizer + mic entitlement work |
| PluginInstaller clipboard | Dialog appeared, copied command, pasted in Terminal | UX needs polish but functional |
| SPM resource bundle | Beak PNG, dashboard HTML loaded | Fixed: copy to Contents/Resources/ + Resources.bundle helper |

### Confirmed blocked in sandbox (GitHub-only features)

These features work in the notarized GitHub release but not in App Store sandbox. This is by design — two distribution tiers:

- **App Store**: critic mode + eval scoring + TTS reactions + voice permissions. The core experience.
- **GitHub release**: everything above + relay mode (tmux voice → CLI commands). Power user install.

| Feature | File | What happens | GitHub release? | Future path |
|---------|------|-------------|----------------|-------------|
| **TmuxBridge** | TmuxBridge.swift | Voice heard but command can't reach CLI | Works | Agent teams inbox (rethink needed) |
| **ClaudeSession launcher** | StatusBarManager.swift | Nothing happens (osascript blocked) | Works | Clipboard fallback (like PluginInstaller) |

### Previously resolved

- ~~PluginInstaller~~ — dual-mode: automatic CLI in dev, clipboard + open Terminal in sandbox
- ~~SpeechService log~~ — moved to `DuckConfig.storageDir` (Application Support)
- ~~Legacy `~/.duck/api_key` migration~~ — removed from DuckConfig
- ~~Legacy `Application Support/RubberDuck/` migration~~ — removed from DuckConfig
- ~~HookInstaller.swift~~ — deleted (accessed `~/.duck/`, `~/.claude/settings.json`)
- ~~`.env` file loader~~ — removed (walked filesystem outside sandbox)
- ~~TTSEngine `/usr/bin/say`~~ — confirmed working in sandbox (no fix needed)
- ~~Bundle.module crash~~ — fixed: resource bundle copied to Contents/Resources/, Resources.bundle helper

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
