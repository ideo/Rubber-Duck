# Rubber Duck — Claude Code Plugin Plan

## Goal

Package the Rubber Duck hook scripts as a proper Claude Code plugin so users can install with:

```
/plugin marketplace add ideo/Rubber-Duck
/plugin install rubber-duck
```

This replaces the current auto-install approach (widget writing to `~/.claude/settings.json`) with the official Claude Code plugin system.

## How It Works Today

1. Widget launches → extracts hook scripts to `~/.duck/hooks/`
2. Widget merges hook entries into `~/.claude/settings.json` (global)
3. Hook scripts fire on Claude Code events → POST to `localhost:3333`
4. Widget's embedded server evaluates via Claude Haiku, broadcasts results

**Problem**: Writing to `~/.claude/settings.json` is fragile — can conflict with other tools, doesn't support versioning, can't be cleanly uninstalled.

## Plugin Architecture

```
plugin/
├── .claude-plugin/
│   └── plugin.json           # Manifest — name, version, author, component paths
├── hooks/
│   ├── hooks.json            # Registers 3 hook events with Claude Code
│   ├── on-user-prompt.sh     # UserPromptSubmit → POST /evaluate
│   ├── on-claude-stop.sh     # Stop → POST /evaluate (with context)
│   ├── on-permission-request.sh  # PermissionRequest → POST /permission (blocking)
│   └── duck-env.sh           # Shared config loader (reads ~/.duck/config)
└── README.md                 # What this plugin does, prerequisites
```

### plugin.json

> **Key learning**: Do NOT include a `"hooks"` field in plugin.json. Claude Code auto-discovers `hooks/hooks.json` from the `hooks/` directory. Including a `"hooks"` path breaks loading.

```json
{
  "name": "rubber-duck",
  "description": "Rubber Duck companion — eval scoring, voice permissions, TTS reactions for Claude Code",
  "author": {
    "name": "Daniel Deruntz",
    "url": "https://github.com/ideo"
  }
}
```

### hooks/hooks.json

> **Key learnings**:
> - Must have a top-level `"description"` field
> - Must NOT include `"matcher"` or `"async"` fields (those are settings.json format only)
> - Use `"timeout"` instead of `"async"`
> - Only `"type": "command"` and `"type": "prompt"` work in plugins — `"type": "http"` does NOT work in plugins
> - Reference format: match the `hookify` plugin from the official Anthropic marketplace

```json
{
  "description": "Rubber Duck hooks — eval scoring, voice permissions for Claude Code",
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/on-user-prompt.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/on-claude-stop.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/on-permission-request.sh",
            "timeout": 35
          }
        ]
      }
    ]
  }
}
```

Key: `${CLAUDE_PLUGIN_ROOT}` auto-expands to the installed plugin directory. No hardcoded paths.

### Hook Scripts

Same scripts as today (`scripts/on-*.sh`), with one change:
- `duck-env.sh` is sourced via `${CLAUDE_PLUGIN_ROOT}/hooks/duck-env.sh` (or relative `./duck-env.sh` since CWD is the hook dir)

The scripts themselves don't change — they still:
- Source `duck-env.sh` (which reads `~/.duck/config`)
- POST to `localhost:3333/evaluate` or `/permission`
- Handle the same stdin JSON from Claude Code

## Distribution Options

### Option A: GitHub Marketplace (self-hosted)

Users add our repo as a marketplace source:
```
/plugin marketplace add ideo/Rubber-Duck
/plugin install rubber-duck
```

The `plugin/` directory in our repo IS the plugin. Marketplace discovery is via the repo itself.

**Requires**: A `.claude-plugin/marketplace.json` at repo root (or in the plugin dir) listing the plugin.

### Option B: Official Anthropic Marketplace

Submit at `claude.ai/settings/plugins/submit`. Users browse and install from the built-in plugin UI:
```
/plugin
→ Discover tab → search "rubber duck" → Install
```

**Requires**: Anthropic review/approval.

### Option C: Direct Install (no marketplace)

Users clone the repo and point to it:
```
claude --plugin-dir ./plugin
```

Good for development and testing.

## Install Scopes

Plugins can be installed at three scopes:
- **User** — works across all projects (recommended for Rubber Duck)
- **Project** — added to `.claude/settings.json`, shared with collaborators
- **Local** — only for current user in current repo

## Migration Path

### Phase 1 (current): Auto-install via widget
Widget extracts scripts to `~/.duck/hooks/` and writes to `~/.claude/settings.json`. Works today, no plugin system needed.

### Phase 2 (this branch): Plugin structure ✅
Create the plugin directory, test with `claude --plugin-dir ./plugin`. Keep the auto-install as fallback.

### Phase 3: Marketplace submission
Submit to official Anthropic marketplace. Update widget to detect plugin vs auto-install and prefer the plugin path.

### Phase 4: Remove auto-install
Once the plugin is in the marketplace, remove `HookInstaller.swift` from the widget. The plugin handles everything.

## Widget ↔ Plugin Relationship

The **plugin** handles Claude Code integration (hooks that fire on events).
The **widget** handles everything else (eval server, TTS, voice gate, serial, UI).

Both are needed:
1. Install widget app (macOS .app)
2. Install plugin (`/plugin install rubber-duck`)
3. Widget runs the server, plugin sends events to it

The widget still writes `~/.duck/config` on launch so the plugin's hook scripts know the port/URL.

## Prerequisites for Users

- macOS 26+ (Tahoe)
- Claude Code 1.0.33+ (plugin support)
- Anthropic API key (for eval scoring)
- Rubber Duck Widget app running

## UX Considerations — Onboarding

### The Two-Piece Problem

Rubber Duck requires both a **Mac app** (widget) and a **Claude Code plugin** (hooks). Neither works alone. The onboarding challenge: how to make installing two things feel like one.

### What the Plugin System Can Do

- **SessionStart hook** — fires every time Claude Code opens a session. Can run a health check (`curl localhost:3333/health`), launch the widget if missing (`open -a RubberDuckWidget`), and inject context into Claude's awareness ("Duck is watching" or "Widget not running — install instructions").
- **Stdout injection** — hook output goes into Claude's context. Claude sees it and can relay it to the user conversationally. This is the only communication channel (no native notifications, no dialogs).
- **First-run detection** — use a sentinel file (`~/.duck/.plugin-welcomed`). If missing, print a welcome message. Create the file so it only shows once.
- **No post-install hook** — there's no mechanism to run setup when the plugin is first installed. Everything happens at session start.

### What the Mac App Can Do

- **Install the plugin itself** — the app can run `claude plugin marketplace add ideo/Rubber-Duck && claude plugin install rubber-duck` via a `Process` shell command. Could be a menu bar item: "Install Claude Code Plugin".
- **Detect if plugin is installed** — check for the plugin in `~/.claude/` or run `claude plugin list` and grep for rubber-duck.
- **Fallback to auto-install** — if the plugin system isn't available (old Claude Code version), fall back to the current `HookInstaller.swift` approach of writing to `~/.claude/settings.json`.

### Ideal Onboarding Flow

**Path A: Start from the app (recommended)**
1. User downloads `.app` from GitHub releases, drags to Applications
2. First launch: API key prompt (already exists)
3. App detects Claude Code is installed → offers "Connect to Claude Code" button in menu bar
4. Button runs `claude plugin install` → done
5. If Claude Code not installed, falls back to auto-install hooks (current behavior)

**Path B: Start from the plugin**
1. User runs `/plugin marketplace add ideo/Rubber-Duck` → `/plugin install rubber-duck`
2. First Claude Code session: `SessionStart` hook checks for widget
3. Widget not found → Claude tells user: "Rubber Duck plugin is installed but the widget app isn't running. Download it from github.com/ideo/Rubber-Duck/releases"
4. Widget found → "Duck is watching this session" (silent, conversational)

**Path C: One-liner install script**
```bash
curl -fsSL https://raw.githubusercontent.com/ideo/Rubber-Duck/main/scripts/install.sh | bash
```
Downloads the app, moves to /Applications, installs the plugin. Everything in one command.

### Session Health Check (plugin adds this)

Add a `SessionStart` hook that runs every session:
```bash
#!/bin/bash
# check-widget.sh — silent health check, injects context
if curl -sf http://localhost:3333/health > /dev/null 2>&1; then
  echo "Rubber Duck is watching this session."
else
  echo "Rubber Duck Widget is not running. Start it: open -a RubberDuckWidget"
fi
exit 0
```

Claude sees this output and knows whether the duck is active. No user action needed when it's working.

### Bidirectional Detection (inspired by 1Password + CLI pattern)

- **App detects plugin**: Check `claude plugin list` output or look for plugin files in `~/.claude/`
- **Plugin detects app**: `curl localhost:3333/health` in SessionStart hook
- **Both missing**: Auto-install hooks (current HookInstaller.swift) as universal fallback

### Project-Level Auto-Prompt

For repos that use Rubber Duck, `.claude/settings.json` can include:
```json
{
  "extraKnownMarketplaces": {
    "rubber-duck-marketplace": {
      "source": { "source": "github", "repo": "ideo/Rubber-Duck" }
    }
  },
  "enabledPlugins": {
    "rubber-duck@rubber-duck-marketplace": true
  }
}
```
When someone clones and trusts the repo, Claude Code auto-prompts them to install the marketplace and plugin.

### Known Limitations

- **No native UI from plugins** — can't show macOS alerts or notifications. Only stdout text that Claude sees.
- **SessionStart hook bug** — documented issue where hooks from newly installed plugins sometimes fail on the very first session. Works on subsequent sessions.
- **`claude` CLI location varies** — the app needs to find the binary (`~/.claude/local/bin/claude`, `/usr/local/bin/claude`, etc.) to trigger plugin install.

### GitHub Release Page Copy

```
## Quick Install

### Option 1: Download the app (recommended)
1. Download RubberDuckWidget.zip below → drag to /Applications → launch
2. Click "Install Claude Plugin" from the 🦆 menu bar

### Option 2: One-liner
curl -fsSL https://raw.githubusercontent.com/ideo/Rubber-Duck/main/scripts/install.sh | bash

### Option 3: Manual
1. Download and run the widget app
2. In Claude Code: /plugin marketplace add ideo/Rubber-Duck
3. Then: /plugin install rubber-duck
```

## Open Questions

- [ ] Should the plugin include a skill (e.g., `/rubber-duck:status`) that checks if the widget is running?
- [ ] Should the plugin include an MCP server for richer Claude ↔ duck communication?
- [x] ~~Can we use HTTP hooks (`"type": "http"`) instead of command hooks?~~ **No.** HTTP hooks only work in `settings.json`, not in plugins. Plugins only support `"type": "command"` and `"type": "prompt"`.
- [x] ~~Marketplace.json format — does it go at repo root or can it reference a subdirectory?~~ **Repo root.** `.claude-plugin/marketplace.json` at repo root, with `"source": "./plugin"` pointing to the plugin subdirectory. Users add via `claude plugin marketplace add ideo/Rubber-Duck`.

## Completed (2026-03-10)

- [x] Plugin structure created and tested with `claude --plugin-dir ./plugin`
- [x] All 3 hooks (UserPromptSubmit, Stop, PermissionRequest) register and fire correctly
- [x] Plugin mode sentinel (`~/.duck/.plugin-mode`) prevents HookInstaller from conflicting
- [x] `/hook/*` HTTP endpoints added to DuckServer.swift (for potential future use)
- [x] Hooks show as read-only "Plugin Hooks — disable rubber-duck to remove" in `/hooks` UI

## Testing

```bash
# Local plugin testing
claude --plugin-dir ./plugin

# Verify hooks fire
# (do something in Claude Code, check widget reacts)

# Check hook registration
/hooks

# Reload after changes
/reload-plugins
```

## Files to Create

| File | Purpose |
|------|---------|
| `plugin/.claude-plugin/plugin.json` | Plugin manifest |
| `plugin/hooks/hooks.json` | Hook event registration |
| `plugin/hooks/on-user-prompt.sh` | UserPromptSubmit hook |
| `plugin/hooks/on-claude-stop.sh` | Stop hook |
| `plugin/hooks/on-permission-request.sh` | PermissionRequest hook |
| `plugin/hooks/duck-env.sh` | Shared config loader |
| `plugin/README.md` | User-facing docs |
