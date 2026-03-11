# Rubber Duck — Claude Code Plugin

Eval scoring, voice permissions, and TTS reactions for Claude Code sessions.

## Prerequisites

- macOS 26+ (Tahoe)
- Claude Code 1.0.33+
- Rubber Duck Widget app running (`localhost:3333`)

## Install

### From the terminal (recommended)

```bash
claude plugin marketplace add ideo/Rubber-Duck
claude plugin install rubber-duck
```

### From inside Claude Code

```
/plugin marketplace add ideo/Rubber-Duck
/plugin install rubber-duck
```

### Local development

```bash
claude --plugin-dir ./plugin
```

## How it works

The plugin registers three hook scripts that POST to the widget's server on `localhost:3333`:

| Hook | What it does |
|------|-------------|
| UserPromptSubmit | Sends your prompt to the duck for eval scoring |
| Stop | Sends Claude's response to the duck for eval scoring |
| PermissionRequest | Asks the duck (via voice) whether to allow the action |

The widget app must be running to receive these events. If the widget isn't running, hooks fail silently and Claude Code continues normally.
