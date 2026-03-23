# Duck Duck Duck — Gemini CLI Integration

Your rubber duck companion watches Gemini CLI sessions and reacts with opinions, voice, and animations — just like it does with Claude Code.

## Setup

### 1. Install hooks

Copy the hooks directory somewhere permanent:

```bash
cp -r plugin-gemini/hooks ~/.gemini/duck-hooks
chmod +x ~/.gemini/duck-hooks/*.sh
```

### 2. Configure Gemini CLI

Add the hooks to your Gemini CLI settings. Edit `~/.gemini/settings.json` (create it if it doesn't exist):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "~/.gemini/duck-hooks/on-session-start.sh", "timeout": 5 }] }
    ],
    "BeforeModel": [
      { "hooks": [{ "type": "command", "command": "~/.gemini/duck-hooks/on-before-model.sh", "timeout": 10 }] }
    ],
    "AfterAgent": [
      { "hooks": [{ "type": "command", "command": "~/.gemini/duck-hooks/on-after-agent.sh", "timeout": 10 }] }
    ],
    "BeforeTool": [
      { "hooks": [{ "type": "command", "command": "~/.gemini/duck-hooks/on-before-tool.sh", "timeout": 35 }] }
    ]
  }
}
```

### 3. Run the widget

Make sure Duck Duck Duck is running (menu bar icon visible). The hooks POST to `localhost:3333`.

### 4. Start a Gemini CLI session

```bash
gemini
```

The duck will react to your prompts and Gemini's responses — same personality, same scoring, same voice.

## How it works

| Gemini CLI Hook | What it does | Claude Code equivalent |
|---|---|---|
| `BeforeModel` | Scores user prompts before they reach the LLM | `UserPromptSubmit` |
| `AfterAgent` | Scores Gemini's responses after each turn | `Stop` |
| `BeforeTool` | Voice approval gate for tool execution | `PermissionRequest` |
| `SessionStart` | Health check to mark widget connected | `SessionStart` |

All hooks POST to the same `localhost:3333` endpoints as the Claude Code plugin. The widget doesn't care which AI tool is running — it scores the text the same way.

## Intelligence picker

In the widget's menu bar, you can choose which LLM scores the text:

- **Foundation** — Apple on-device (~3B, free, fast)
- **Haiku** — Anthropic Claude Haiku (requires API key)
- **Gemini** — Google Gemini Flash (requires API key)

Get a Gemini API key at [aistudio.google.com](https://aistudio.google.com).

## Requirements

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) v0.26.0+
- `jq` (for JSON parsing in hook scripts)
- Duck Duck Duck widget running
