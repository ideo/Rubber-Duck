# Rubber Duck — Claude Code Plugin

Eval scoring, voice permissions, and TTS reactions for Claude Code sessions.

## Prerequisites

- macOS 26+ (Tahoe)
- Claude Code 1.0.33+
- Rubber Duck Widget app running (`localhost:3333`)

## Install

### From the widget app (recommended)

Click **Install Claude Plugin** from the menu bar icon.

### Manual

```bash
# Add marketplace
/plugin marketplace add ideo/Rubber-Duck

# Install
/plugin install rubber-duck
```

### Local development

```bash
claude --plugin-dir ./plugin
```

## How it works

This plugin uses HTTP hooks — Claude Code POSTs directly to the widget's server on `localhost:3333`. No shell scripts involved.

| Hook | Endpoint | Purpose |
|------|----------|---------|
| UserPromptSubmit | `/hook/prompt` | Evaluate user prompts |
| Stop | `/hook/stop` | Evaluate Claude responses |
| PermissionRequest | `/hook/permission` | Voice-gated permission approval |

The widget app must be running to receive these events. If the widget isn't running, hooks fail silently and Claude Code continues normally.
