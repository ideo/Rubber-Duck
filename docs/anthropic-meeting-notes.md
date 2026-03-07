# Anthropic Meeting — Tuesday

## Items to Raise

### 1. PermissionRequest hook: Desktop UI doesn't dismiss modal after hook approval
- **Bug**: When a `PermissionRequest` hook returns `{"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}`, Claude Code's engine correctly accepts the decision and continues execution. However, Claude Code Desktop still renders the permission modal overlay.
- **Impact**: User sees stale modals stacking up that they have to manually dismiss, even though the actions already completed.
- **Ask**: When a PermissionRequest hook returns a decision, Desktop should either (a) not show the modal at all, or (b) auto-dismiss it.
- **Confirmed**: This is Desktop-specific. Terminal Claude Code correctly clears the permission prompt after hook approval.

### 2. PermissionRequest hook output format was undocumented
- The correct output format (`hookSpecificOutput.decision.behavior`) was not obvious from docs. A flat `{"decision": "allow"}` silently fails — no error, just falls through to the manual UI.
- Better error messages or documentation would help.

### 3. Multi-session permission disambiguation
- **Scenario**: Multiple Claude Code sessions (e.g. Desktop + terminal tmux) share the same project hooks. When a PermissionRequest hook fires, our voice-gated approval flow doesn't know which session is asking.
- **Ask**: Does the hook input include enough info to distinguish sessions? The `session_id` field is there but opaque. Would be useful to have a human-readable session label or the ability to tag sessions (e.g. "duck-terminal" vs "desktop") so external tools can route approvals correctly.
- **TBD**: For now we avoid running both simultaneously. Long-term need a way to disambiguate.

---

## Internal TBDs

### tmux dependency for voice input bridge
- Voice input sends text to Claude Code via `tmux send-keys`. This requires tmux to be installed (`brew install tmux`).
- Not acceptable for end users. Need a better approach:
  - Claude Code stdin pipe / programmatic input API?
  - MCP server that accepts text input?
  - AppleScript to type into Terminal window directly?
- **For now**: tmux is a dev/demo dependency. Document it in setup instructions.

### CLAUDE.md injection for arbitrary projects
- Currently, `CLAUDE.md` lives in the Rubber Duck repo so sessions launched there are duck-aware. But the duck widget should work with *any* project — a user installs the widget app, opens any repo, and the duck just works.
- Need a way to inject duck context into any Claude Code session without polluting the target project's repo. Options:
  - User-level `~/.claude/CLAUDE.md` (if Claude Code supports it) for global context
  - The widget could write a temporary `CLAUDE.md` into the project when launching a duck session, clean up on quit
  - A hook (`UserPromptSubmit`) that prepends duck context as a system message
  - An MCP server that provides duck context on demand
- **Goal**: "Install duck widget, run any project, duck is aware" — zero config in the target project.
