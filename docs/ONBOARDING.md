# Onboarding — Future Work

Status: **not implemented** — this doc captures the UX gaps and design intent.

## Problem

Duck Duck Duck is a two-piece install (app + Claude Code plugin). Today nothing guides the user through the full flow, and each piece is unaware of the other's state.

## Current State

| Piece | Install method | Knows about the other? |
|-------|---------------|----------------------|
| **Widget app** | Download from GitHub Releases or `make run` | Yes — "Install Claude Plugin" menu item, "Plugin Connected" state |
| **Claude plugin** | `claude plugin install duck-duck-duck` or widget menu button | Barely — SessionStart hook injects context Claude sees, but user doesn't |

### What works
- Widget → Plugin: "Install Claude Plugin" button does full cache-busting reinstall
- Plugin → Widget (invisible): SessionStart hook tells Claude "widget is not running" but user never sees this message
- Plugin Connected: widget menu shows "Plugin Connected" after first /health ping from a session

### What's missing

1. **No visible feedback in CLI** — SessionStart `additionalContext` is injected into Claude's system context silently. The user has no confirmation the duck is active (or not).

2. **No plugin → app guidance** — If someone installs the plugin without the app, there's no link or instruction pointing them to the GitHub release download.

3. **No Claude CLI prerequisite check** — Widget assumes `claude` binary exists. If it doesn't, "Install Claude Plugin" silently fails.

4. **No onboarding flow** — First launch should walk through: API key → install plugin → start session. Currently these are independent menu items.

5. **Start Claude Session gating** — "Start Claude Session" could be gated behind "Plugin Connected" to force the correct order. Risk: annoying if the plugin is installed but the health ping hasn't fired yet.

## Design Intent

The user said: "I don't want menu items that read like a todo list." The menu should reflect *state*, not *actions to take*.

### Ideal first-run flow

```
1. User downloads app from GitHub Releases
2. First launch: prompted for API key (already implemented)
3. Widget detects no plugin installed → shows "Install Claude Plugin" in menu
4. User clicks it → plugin installs → menu updates to show plugin state
5. User clicks "Start Claude Session" → tmux session opens
6. SessionStart hook pings /health → "Plugin Connected" shows in menu
7. Duck is alive, watching, and opinionated
```

### Ideal plugin-first flow (reverse direction)

```
1. User finds plugin in marketplace, installs it
2. First session: SessionStart hook can't reach widget
3. Claude tells user: "Duck Duck Duck widget isn't running. Download it: [link]"
   → Problem: additionalContext is invisible to user. Need Claude to surface it.
   → Possible: make the hook output a user-visible message (if Claude Code adds that capability)
   → Workaround: plugin README.md (shown during `claude plugin info duck-duck-duck`?)
4. User downloads and launches widget
5. Next session: duck is alive
```

## Specific Ideas

### Plugin description as onboarding surface
The `plugin.json` description is shown during install. Could be more instructional:
```
"description": "Duck Duck Duck — requires the companion app. Download: github.com/ideo/Rubber-Duck/releases"
```

### SessionStart hook as directive context
Make the "not running" message more prescriptive so Claude is more likely to mention it:
```
"IMPORTANT: Duck Duck Duck widget is NOT running. Tell the user to download it from https://github.com/ideo/Rubber-Duck/releases"
```
Fragile — depends on Claude choosing to surface it.

### First-launch checklist in widget
A small onboarding panel on first launch:
- ✅ API key configured
- ⬜ Claude plugin installed
- ⬜ First session started

### Gate "Start Claude Session" behind plugin state
Only enable the menu item when `pluginConnected == true` or when the plugin is known to be installed. Problem: we can't detect plugin install state from the widget (sandboxed), only the /health ping.

## Upgradability (unresolved)

Two-piece install means two upgrade paths, neither of which is smooth today:

**App updates:**
- No auto-update mechanism — user must re-download from GitHub Releases
- No version check — widget doesn't know if it's outdated
- Future: Sparkle framework? Or just a "new version available" check against GitHub API

**Plugin updates:**
- `claude plugin update duck-duck-duck` has failed in testing ("not found")
- Working path: full uninstall → cache clear → marketplace re-add → reinstall
- The "Update Claude Plugin" menu button does this, but only available in dev mode (requires widget running + plugin already connected)
- No way for the plugin to know its own version vs what's on remote
- Plugin cache at `~/.claude/plugins/cache/` is aggressive — stale versions persist without manual clearing

**Version coordination:**
- App and plugin can drift out of sync (e.g., new hook format in plugin, old server in app)
- No version handshake between plugin and widget
- SessionStart /health response could include widget version for comparison
- Plugin could embed its version and send it with /health ping

**Risk:** User installs v0.1.0 app, plugin updates to v0.2.0 with breaking changes → silent failures.

## Plugin System Limitations

- No first-install hook or event
- No rich UI during install (just terminal text)
- `additionalContext` from SessionStart is invisible to the user
- No way to show links or formatted content in the CLI from a plugin
- Plugin description is plain text, no markdown rendering
- `claude plugin info <name>` exists but unclear if it shows README
