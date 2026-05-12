# Duck Duck Duck for Codex

Codex plugin hooks for Duck Duck Duck. The plugin sends Codex session events to
the local Duck Duck Duck app at `http://localhost:3333`.

## What It Does

- `SessionStart` pings the widget and injects a short context note.
- `UserPromptSubmit` sends user prompts to `/evaluate`.
- `Stop` sends Codex responses to `/evaluate`.
- `PermissionRequest` asks the widget for voice approval and returns Codex
  allow/deny decisions.

## Local Testing

Enable Codex hooks:

```toml
[features]
codex_hooks = true
```

Then add this repository as a local marketplace:

```bash
codex plugin marketplace add .
```

Install or enable `duck-duck-duck-codex` from the Codex plugin UI.

Start the Duck Duck Duck app before starting a Codex session. If the app is not
running, hooks stay silent and Codex falls back to its normal behavior.
