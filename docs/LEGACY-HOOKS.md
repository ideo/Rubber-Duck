# Legacy Hook Architecture (Pre-Plugin)

Preserved for reference in case we need to revert or support older Claude Code versions without plugin support.

## How it worked

On every app launch, `HookInstaller.swift` would:

1. Extract bundled shell scripts to `~/.duck/hooks/`
2. Merge hook entries into `~/.claude/settings.json` (global scope)
3. Scripts fire on Claude Code events → POST to `localhost:3333`

## Files written by the widget

| Path | Purpose |
|------|---------|
| `~/.duck/hooks/on-user-prompt.sh` | UserPromptSubmit hook |
| `~/.duck/hooks/on-claude-stop.sh` | Stop hook |
| `~/.duck/hooks/on-permission-request.sh` | PermissionRequest hook |
| `~/.duck/hooks/duck-env.sh` | Shared config loader |
| `~/.duck/config` | Runtime config (port, voice, tmux session) |
| `~/.duck/api_key` | Anthropic API key |
| `~/.duck/duck.pid` | PID file |
| `~/.duck/permission.log` | Permission hook debug log |
| `~/.duck/.plugin-mode` | Sentinel to skip auto-install |
| `~/.claude/settings.json` | Hook registration (merged, not overwritten) |

## settings.json hook format

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/you/.duck/hooks/on-user-prompt.sh",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/you/.duck/hooks/on-claude-stop.sh",
            "async": true
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/you/.duck/hooks/on-permission-request.sh",
            "async": false
          }
        ]
      }
    ]
  }
}
```

Note: settings.json format uses `"matcher"` and `"async"` — these do NOT work in plugin hooks.json.

## Runtime config format (~/.duck/config)

```bash
# Rubber Duck Runtime Config — written by widget on launch.
DUCK_SERVICE_PORT=3333
DUCK_SERVICE_URL=http://localhost:3333
DUCK_TMUX_SESSION=duck
DUCK_TMUX_WINDOW=claude
DUCK_PID_FILE=/Users/you/.duck/duck.pid
DUCK_VOICE=Boing
DUCK_SERIAL_PREFIX=tty.usbmodem
DUCK_AUDIO_DEVICE_NAME=teensy
```

Shell scripts `source duck-env.sh` which reads this file.

## HookInstaller.swift key methods

- `install()` — extract scripts + merge settings (skipped if `.plugin-mode` exists)
- `uninstallHooks()` — remove `.duck/hooks/` entries from settings.json
- `enablePluginMode()` — create sentinel + uninstall hooks
- `disablePluginMode()` — remove sentinel (next launch re-installs)

## Why we moved away

- Widget writing to `~/.claude/settings.json` is a sandbox violation (App Store)
- Widget writing executable scripts to `~/.duck/hooks/` is a sandbox violation
- Hardcoded paths break on multi-user systems
- No clean uninstall — deleting the app leaves orphaned hooks in settings.json
- Plugin system handles all of this properly
