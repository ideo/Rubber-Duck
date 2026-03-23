# Duck Duck Duck — Claude Code Plugin

A companion plugin that connects Claude Code to the [Duck Duck Duck](https://github.com/ideo/Rubber-Duck) desktop app. The duck watches your coding sessions, scores every prompt and response, speaks opinionated reactions, and handles permissions by voice.

🔒 **Default intelligence is fully on-device and private.** All eval scoring runs via Apple Foundation Models — nothing leaves your machine. No audio is sent to the cloud. [Learn more about privacy.](https://github.com/ideo/Rubber-Duck#data--privacy)

## Requirements

- **macOS 26** (Tahoe) or later, Apple Silicon
- **Claude Code** or **Claude Desktop**
- **Duck Duck Duck app** running — [download here](https://github.com/ideo/Rubber-Duck/releases)

## Install

The easiest way: **right-click the duck → Install Claude Plugin**. The app handles everything.

Or install manually:

```bash
claude plugin marketplace add ideo/Rubber-Duck
claude plugin install duck-duck-duck
```

Works in Claude Code CLI and Claude Desktop.

## How It Works

The plugin registers hooks that fire on Claude Code events and POST to the widget's server on `localhost:3333`. The widget scores the text, animates the duck, and speaks reactions.

| Hook | What it does |
|------|-------------|
| **SessionStart** | Health check — tells Claude if the duck is active |
| **UserPromptSubmit** | Sends your prompt for eval scoring |
| **Stop** | Sends Claude's response for eval scoring |
| **PermissionRequest** | Voice-confirmed permission gate — duck asks, you speak |
| **PostToolUse** | Clears permission state after CLI approval |
| **SessionEnd** | Duck acknowledges session close |
| **StopFailure** | Duck reacts to API errors |
| **PreCompact / PostCompact** | Thinking melody during context compaction |

If the widget isn't running, hooks fail silently and Claude Code continues normally.

## Updating

After updating the plugin (`claude plugin update duck-duck-duck`):
- **New session**: hooks load automatically
- **Current session**: run `/reload-plugins` to pick up changes

## Troubleshooting

**Hooks not showing up** — Run `/hooks` to check. If missing: reinstall the plugin, then `/reload-plugins` or start a new session. Hooks are cached at session start.

**Widget not responding** — Check the duck icon is in your menu bar. Verify: `curl http://localhost:3333/health` should return JSON.

**Permission stuck** — If the duck stays in "asking permission" after you approved via CLI click, the PostToolUse hook auto-clears it. If stuck, the next eval also clears it.

**Plugin not found** — Make sure the marketplace is added: `claude plugin marketplace add ideo/Rubber-Duck`

## Development

```bash
claude --plugin-dir ./plugin
```

Loads hooks from local files — no push or reinstall needed. Run `/reload-plugins` after changes.

## License

[MIT](https://github.com/ideo/Rubber-Duck/blob/main/LICENSE)
