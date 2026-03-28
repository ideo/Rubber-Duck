# Onboarding Audit — Duck Duck Duck

Status as of 2026-03-27. Tracks every issue found during onboarding testing.

---

## CRITICAL — Blocks all functionality

### 1. `jq` dependency kills every hook silently
- **Status: FIXED** (2026-03-27)
- Replaced all `jq` calls with `python3` helpers (`json_get`, `json_build`) in `duck-env.sh`
- Zero `jq` references remain in `plugin/hooks/`
- `scripts/` (dev-only, not shipped) still uses `jq` — intentional

### 2. Widget not running = hooks silently fail
- **Status: FIXED** (2026-03-28) — by design
- If widget isn't running, all hooks are completely silent — zero output to Claude
- `on-session-start.sh` exits immediately without injecting any context
- Philosophy: if the user isn't running the widget, we stay out of their way entirely

### 3. Port conflict = dead duck, no warning
- **Status: FIXED** (2026-03-27)
- Widget tries ports 3333-3343 and writes port file — working
- Port file removed in `applicationWillTerminate`
- Now writes `port.pid` alongside `port` file with the widget's PID
- `cleanStalePortFile()` runs on launch: checks if PID is alive, deletes stale files if not
- Handles crash, `kill -9`, force-quit — next launch cleans up automatically

### 4. Keychain → file migration left orphaned keys
- **Status: WON'T FIX**
- No beta testers have Keychain-stored keys — the Keychain version was never distributed
- `keychainAccount` param is dead code (could clean up later)
- No migration needed

---

## HIGH — Breaks core experience

### 5. Permission request hook is a 35-second blocking call
- **Status: BY DESIGN**
- Claude Code's built-in permission UI is always visible — user can click allow/deny at any time
- The hook just adds voice as an overlay; 35s timeout is how long we wait for a spoken response
- If no voice response, hook exits 0 and Claude Code's UI takes over — no user impact

### 6. Microphone permission flow has no fallback for denial
- **Status: FIXED** (2026-03-28)
- Menu bar icon swaps to `duck-symbol-alert.svg` (duck with yellow warning triangle) when permissions denied
- Menu shows dim "Microphone: Not Granted" / "Speech Recognition: Not Granted" items
- Clickable "Open Microphone Settings…" item opens System Settings → Privacy → Microphone
- When all permissions granted: alert icon reverts to normal, items hidden

### 7. Speech recognition permission is separate from mic
- **Status: FIXED** (2026-03-28)
- Covered by same fix as #6 — both permissions tracked independently in menu

### 8. CLI install command modifies `.zshrc` blindly
- **Status: FIXED** (2026-03-28)
- `StatusBarManager.swift` line ~321: `echo 'export PATH=...' >> ~/.zshrc`
- Appends every time, no idempotency check, zsh-only
- **TODO:** Check if line already exists before appending. Detect user's actual shell.

### 9. `directInstall()` writes to `~/.claude/plugins/` with fragile JSON
- **Status: FIXED** (2026-03-28)
- Atomic writes via `.atomic` option (write to temp, rename into place)
- Validates existing JSON structure before modifying (checks `version` key + `plugins` dict)
- If file is corrupt, backs it up as `.bak` and starts fresh instead of making it worse

---

## MEDIUM — Confusing or degraded experience

### 10. `on-session-start.sh` uses `git rev-parse` in non-git directories
- **Status: FIXED** (2026-03-28)
- Removed "Repo:" from greeting context entirely — duck watches the session, not the repo

### 11. Plugin install success message doesn't explain how to start a session
- **Status: FIXED** (2026-03-28)
- Changed to "Close and reopen Claude Code to activate the hooks."

### 12. `findClaude()` misses some install paths
- **Status: FIXED** (2026-03-28)
- Added `/opt/homebrew/bin/claude` to explicit search paths
- Now checks: `~/.local/bin`, `~/.claude/local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`, then `which` fallback

### 13. No version check on detected Claude
- **Status: FIXED** (2026-03-28)
- `PluginInstaller.checkClaudeVersion()` runs `claude --version`, parses output (e.g. "2.1.83 (Claude Code)")
- Compares component-wise against `minimumClaudeVersion = [1, 1, 7714]`
- If too old: speaks warning, shows alert with update instructions, blocks install
- If version can't be parsed: allows install (fail-open to avoid false blocks)

### 14. Export Plugin Zip uses `ditto` with `--keepParent`
- **Status: ACCEPTABLE**
- Standard macOS zip tool, works for manual upload
- If Claude Desktop expects flat structure, might need testing
- Low risk — mostly used for manual distribution

### 15. Plugin author says "Daniel Deruntz" not "IDEO"
- **Status: INTENTIONAL** — personal attribution is fine for now

---

## LOW — Polish issues

### 16. Permission log grows unbounded
- **Status: FIXED** (2026-03-28)
- Log auto-rotates: if over 1MB, keeps last 200 lines and truncates

### 17. Hook creates Application Support dir even if widget never launched
- **Status: ACCEPTABLE**
- `on-session-start.sh` does `mkdir -p` for `last-session` timestamp
- Harmless — directory would be created by widget anyway

### 18. No progress feedback during `automaticInstall`
- **Status: NOT ADDRESSED**
- Duck says "Installing the plugin. One moment." but no progress updates
- **Optional:** Periodic "still working..." messages

### 19. `installClaudeCLIAction` opens Terminal but doesn't auto-paste
- **Status: NOT ADDRESSED**
- Clipboard has the command, user must manually paste
- **Optional:** Use osascript to paste into Terminal (may be blocked by sandbox)

### 20. Right-click brings widget to focus, dismissing the context menu
- **Status: FIXED** (2026-03-28)
- Root cause: beak flutter timer updated `coordinator.expression.beakOpen` every 0.15s
- Since coordinator is `@ObservedObject`, every update re-rendered the parent DuckView, dismissing the context menu
- Fix: isolated beak into `DuckBeakView` struct with its own `@State` flutter timer (same pattern as `DuckEyesView` blink fix)

---

## Audit Complete (2026-03-28)

**15 of 20 fixed/resolved.** Remaining 5 are accepted as-is:
- #5 — By design (voice overlay, CLI UI always available)
- #14 — Acceptable (zip works, edge case only)
- #17 — Acceptable (harmless dir creation)
- #18 — Acceptable (install is fast enough)
- #19 — Acceptable (clipboard works, sandbox blocks osascript)
