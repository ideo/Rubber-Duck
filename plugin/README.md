# Duck Duck Duck — Claude Code Plugin

Eval scoring, voice permissions, and TTS reactions for Claude Code sessions.

## Prerequisites

- macOS 26+ (Tahoe)
- Claude Code 1.0.33+
- Duck Duck Duck widget app running (`localhost:3333`)

## Install

### From the marketplace (recommended)

```bash
claude plugin marketplace add ideo/Rubber-Duck
claude plugin install duck-duck-duck
```

Or from the widget app: right-click the duck and select **Install Plugin**.

### From inside Claude Code

```
/plugin marketplace add ideo/Rubber-Duck
/plugin install duck-duck-duck
```

### Local development

```bash
claude --plugin-dir ./plugin
```

This loads hooks directly from your local `plugin/` directory — no GitHub push needed. Great for testing hook changes before merging.

## How it works

The plugin registers hook scripts that POST to the widget's server on `localhost:3333`:

| Hook | What it does |
|------|-------------|
| **SessionStart** | Injects greeting context (time of day, recency) |
| **UserPromptSubmit** | Sends your prompt to the duck for eval scoring |
| **Stop** | Sends Claude's response to the duck for eval scoring |
| **PermissionRequest** | Asks the duck (via voice) whether to allow the action |
| **PostToolUse** | Clears stuck permission state when you approve via CLI |
| **SessionEnd** | Duck says goodbye when the session closes |
| **StopFailure** | Duck reacts to API errors (rate limit, auth, etc.) |
| **PreCompact** | Starts the Jeopardy thinking melody during context compaction |
| **PostCompact** | Stops the melody when compaction finishes |

The widget app must be running to receive these events. If the widget isn't running, hooks fail silently and Claude Code continues normally.

## Updating the plugin

The marketplace install pulls from the **default branch** (main) on GitHub. If you've added or changed hooks on a feature branch, they won't appear until you merge to main and reinstall.

After reinstalling:
- **New session**: hooks load automatically
- **Current session**: run `/reload-plugins` to pick up changes without restarting

## Troubleshooting

### Hooks not showing up after install

Run `/hooks` in Claude Code to see active hooks. If your new hooks are missing:

1. **Check the branch.** Marketplace installs pull from `main`. If your changes are on a feature branch, they won't be included. Merge first, then reinstall.
2. **Reinstall the plugin.** The widget's right-click menu has "Install Plugin", or run `claude plugin install duck-duck-duck` from the terminal.
3. **Reload or restart.** Run `/reload-plugins` in your current session, or start a new session. Hooks are cached at session start.

### Widget not responding

1. Check the widget is running — look for the duck icon in the menu bar.
2. Verify the server: `curl http://localhost:3333/health` should return JSON.
3. Check logs: `tail -f ~/Library/Application\ Support/DuckDuckDuck/DuckDuckDuck.log`

### Permission voice gate stuck

If the duck stays in "asking permission" state after you've already approved:
- This happens when you approve via the CLI instead of voice. The **PostToolUse** hook auto-clears this — make sure it's installed (check `/hooks`).
- Manual fix: the next eval (user prompt or Claude response) also clears the stuck state.

### Dev workflow: testing hook changes

Use `claude --plugin-dir ./plugin` from the repo root to load hooks from your local files. This bypasses the marketplace entirely — no need to push, merge, or reinstall. When you're happy with the changes, merge to main and reinstall for the marketplace version to pick them up.
