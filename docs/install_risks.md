# Plugin Installation — Brittle Choices & Known Risks

Last updated: 2026-04-08

## 1. Writing directly to `settings.json`

**What we do:** `directInstall()` reads `~/.claude/settings.json`, adds `enabledPlugins["duck-duck-duck@..."] = true` and `extraKnownMarketplaces`, then atomically writes it back.

**Why it's brittle:**
- `settings.json` is owned by Claude (Desktop and CLI). Its schema is undocumented and can change without notice.
- If Claude Desktop writes to the same file concurrently, our atomic write could clobber their changes (last-writer-wins).
- If Claude adds required fields, validation, or moves to a different config format, our writes could produce a malformed file that breaks Claude entirely — not just our plugin.
- The `enabledPlugins` key name and `true` value are reverse-engineered from observation, not from a public API.

**Mitigation:** We only write if the key is missing or false. We never remove other keys. We use `.atomic` writes to avoid partial corruption. The CLI path (`automaticInstall`) is always preferred when available.

**If this breaks:** Users will need to manually enable the plugin in Claude Desktop's UI or run `claude plugin install duck-duck-duck` from the CLI.

## 2. Writing directly to `installed_plugins.json`

**What we do:** `directInstall()` writes a plugin entry into `~/.claude/plugins/installed_plugins.json` with `version: 2` schema.

**Why it's brittle:**
- The schema (`version: 2`, array-of-dicts per plugin key, specific field names) is inferred from the current CLI behavior.
- A `version: 3` schema change would make our entries unreadable or ignored.
- The plugin key format (`name@marketplace`) is a convention, not a contract.

**Mitigation:** We check for and preserve the existing file structure. We back up corrupt files before overwriting. The CLI path handles this properly when available.

## 3. File copy to `~/.claude/plugins/cache/`

**What we do:** Copy the bundled plugin folder into `~/.claude/plugins/cache/duck-duck-duck-marketplace/duck-duck-duck/{version}/`.

**Why it's brittle:**
- The cache directory structure (`cache/{marketplace}/{plugin}/{version}/`) is an implementation detail of Claude's plugin system.
- Claude could reorganize this at any time (flat structure, content-addressable, database-backed, etc.).
- We use a synthetic version string (`direct-{timestamp}`) that doesn't match Claude's expected versioning — could confuse update checks.

**Mitigation:** We always prefer the CLI install path. Direct copy is a fallback for when no CLI exists.

## 4. Priority order: CLI first, direct copy fallback

**What we do:** `install()` checks `findClaude()` first. If found, uses `automaticInstall()` (runs `claude plugin marketplace add` + `claude plugin install`). Only falls back to `directInstall()` if no CLI.

**Why this matters:**
- The CLI path is the "blessed" way to install plugins — it handles schema changes, registration, and enablement internally.
- Direct copy is a best-effort shim for Desktop-only users who don't have the CLI.
- If Anthropic ships a CLI bundled with Desktop in the future, `findClaude()` needs to find it (currently only checks well-known paths).

**Risk:** A user could have an old/broken CLI in their PATH that `findClaude()` finds. We check minimum version (`1.1.9669`) to mitigate this, but a broken binary could hang or crash.

## 5. Belt-and-suspenders CLI activation in `directInstall()`

**What we do:** After direct file copy succeeds, if `findClaude()` returns a path, we also run `claude plugin install duck-duck-duck`.

**Why it's brittle:**
- This runs the CLI install on top of a manual file copy, which could conflict (e.g., CLI expects a clean state, finds our files, gets confused).
- The CLI might prompt for confirmation in a future version, causing the process to hang.

**Mitigation:** We don't check the return value critically — if it fails, the direct copy + settings.json write is our primary path. This is purely a bonus.

## 6. `findBundledPlugin()` resource discovery

**What we do:** Look for the plugin in `Bundle.main.resourcePath/plugin/` first, then next to the `.app` as a sibling directory.

**Why it's brittle:**
- Depends on the Makefile correctly copying the `plugin/` directory into the app bundle's Resources.
- If the build process changes or the plugin directory is renamed, `findBundledPlugin()` returns nil and installation fails with "Bundled plugin not found."
- The sibling-directory fallback only works during development — in production (app in /Applications), there's no sibling.

## 7. Hidden directory `.claude-plugin/` not copied in `directInstall()` — ACTIVE BUG

**What happens:** `FileManager.contentsOfDirectory(atPath:)` on line 736 of `StatusBarManager.swift` skips hidden directories (those starting with `.`). The `.claude-plugin/` directory — which contains `plugin.json`, the plugin manifest Claude needs to load hooks — is never copied to the install directory.

**Symptom:** Plugin appears in Claude Desktop's plugin browser (marketplace entry is correct) but shows a red dot / inactive state. Hooks don't fire. The user sees the plugin as "installed" but it doesn't work.

**Why it matters:** This is the primary path for Desktop-only users who don't have the CLI. The CLI path (`automaticInstall`) works correctly because `claude plugin install` handles the copy internally.

**Fix:** Replace `contentsOfDirectory(atPath:)` with a method that includes hidden entries. Options:
- Use `contentsOfDirectory(at:includingPropertiesForKeys:options:)` which includes hidden items by default
- Or explicitly copy `.claude-plugin/` after the loop
- Or use a shell `cp -a` which preserves hidden files

**Workaround:** If a user hits this, they can install the CLI (`claude.com/download`) and re-run the install from the widget menu — the CLI path handles everything correctly.

## Summary

The safest path is always the CLI install (`automaticInstall`). Every piece of the direct install path is built on reverse-engineered assumptions about Claude's internal file structure. When these assumptions break, the failure mode is silent — the plugin appears installed but hooks don't fire.

**Recommended periodic checks:**
- After major Claude Desktop updates, verify `settings.json` schema hasn't changed
- After major Claude CLI updates, verify `installed_plugins.json` schema and cache directory layout
- Monitor for a bundled CLI in Claude Desktop (would let us drop most of the direct install path)
