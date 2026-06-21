# Duck Duck Duck — Cursor integration

These hooks connect the Duck Duck Duck widget to **Cursor** (1.7+), the same way
the `plugin/` hooks connect it to Claude Code. The widget's eval server
(`localhost:3333`) is shared — only the hook wiring differs, because Cursor's
hook events and JSON payloads are shaped differently from Claude Code's.

## One-click install (recommended)

Launch the widget. If Cursor is installed, the duck offers to connect itself —
or use the menu bar: **🦆 → Connect to Cursor**. That copies these scripts into
`~/.duck-duck-duck/cursor-hooks/` and merges the hook
wiring into `~/.cursor/hooks.json` (preserving any hooks you already have).
Then reload Cursor (**Cmd+Shift+P → Reload Window**).

## Hook mapping

| Duck behavior              | Cursor hook(s)                                | Endpoint                         |
| -------------------------- | --------------------------------------------- | -------------------------------- |
| Score the user's prompt    | `beforeSubmitPrompt`                          | `POST /evaluate` (source=user)   |
| Score the agent's reply    | `afterAgentResponse`                          | `POST /evaluate` (source=claude) |
| "Cursor's waiting" chirp   | `beforeShellExecution` + `beforeMCPExecution` | `POST /activity` (state=pending) |
| Clear the chirp on auto-run| `afterShellExecution`                         | `POST /activity` (state=resolved)|

**The duck does NOT gate Cursor's permissions.** Cursor keeps its own approval
UI and allow-list, and Cursor ignores a hook's `allow`/`ask` anyway (only `deny`
is honored). So `on-permission.sh` is a *non-blocking notifier*: it fires a
`pending` ping and returns instantly with no decision, leaving Cursor's native
approve/deny untouched. The widget pairs `pending` with the `resolved` ping from
`afterShellExecution`; if a command is still unresolved after a short grace
period, Cursor is parked on its approve prompt and the duck chirps once. Auto-run
commands resolve instantly and stay silent. (MCP has no confirmed resolve event
yet, so MCP pings are recorded but never chirp — no false alarms.)

We hook `beforeShellExecution` / `beforeMCPExecution` rather than the generic
`preToolUse` on purpose: `preToolUse` fires before *every* tool (including each
file read and edit), which would make the duck nag nonstop.

Cursor's `stop` hook only reports a status string (no message text), so response
scoring rides on `afterAgentResponse`, which carries the final assistant text.

Every hook also tags its `POST` with `app` (`cursor`) and `repo` (workspace
folder name) so the duck can say *which* tool/repo needs you when several run at
once.

## Manual install

1. Copy this `hooks/` folder somewhere stable **with no spaces in the path**
   (e.g. `~/.duck-duck-duck/cursor-hooks/`) and `chmod +x` the `*.sh` files.
   Cursor runs each hook command through a shell, so a space in the path
   (e.g. `Library/Application Support/…`) breaks it with exit 127.
2. Take `hooks.template.json`, replace every `__HOOKS_DIR__` with the absolute
   path to that folder, and merge it into `~/.cursor/hooks.json`.
3. Reload Cursor.

Requires Cursor 1.7 or newer (the release that introduced agent hooks).
