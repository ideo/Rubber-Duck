# Duck Duck Duck Plugin — Known Risks & Future Concerns

## Port 3333 hardcoded

The widget binds `localhost:3333` and the plugin scripts POST to it. If another app uses 3333, both break silently.

**Mitigation today**: Port 3333 is uncommon. duck-env.sh supports `DUCK_PORT` override via `~/.duck/config`.

**Problem when sandboxed**: The widget can't write `~/.duck/config` from inside an App Store sandbox. The plugin scripts can't discover the port dynamically.

**Future options**:
- Hardcode 3333 everywhere, fail with a clear error if taken
- Widget writes port to its sandbox container; plugin reads from a known container path (couples to bundle ID)
- App Group container shared between widget + a helper tool
- Bonjour/mDNS service advertisement (overkill but robust)

**Goal**: Nobody should ever have to think about this.

## ~/.duck/ directory (resolved)

All widget storage moved to `~/Library/Application Support/DuckDuckDuck/` (sandbox-safe). The widget no longer writes to `~/.duck/`. Legacy migration code has been removed.

## Mac App Store sandbox violations

Tested via `make sandbox` (ad-hoc signed with App Sandbox entitlements) on 2026-03-11.

### Confirmed working in sandbox

| Feature | How tested | Notes |
|---------|-----------|-------|
| App launch + storage dir | App launched, API key prompt appeared | `~/Library/Application Support/DuckDuckDuck/` works |
| API key storage | Pasted key, app saved and loaded it | FileManager container APIs fine |
| TTS via `/usr/bin/say` | Duck spoke greeting on launch | No Process() restriction for system binaries |
| LaunchGreeting | "They're back already" — context-aware | Time/recency logic works |
| NWListener (localhost:3333) | Dashboard loaded in browser | Server binding works |
| Microphone + STT | "ducky hello" recognized | SFSpeechRecognizer + mic entitlement work |
| PluginInstaller clipboard | Dialog appeared, copied command, pasted in Terminal | UX needs polish but functional |
| SPM resource bundle | Beak PNG, dashboard HTML loaded | Fixed: copy to Contents/Resources/ + Resources.bundle helper |
| USB serial (Teensy) | Servo movements + piezo chirps on eval | Requires `com.apple.security.device.serial` entitlement |

### Confirmed blocked in sandbox (GitHub-only features)

These features work in the notarized GitHub release but not in App Store sandbox. This is by design — two distribution tiers:

- **App Store**: critic mode + eval scoring + TTS reactions + voice permissions. The core experience.
- **GitHub release**: everything above + relay mode (tmux voice → CLI commands). Power user install.

| Feature | File | What happens | GitHub release? | Future path |
|---------|------|-------------|----------------|-------------|
| **TmuxBridge** | TmuxBridge.swift | Voice heard but command can't reach CLI | Works | Agent teams inbox (rethink needed) |
| **ClaudeSession launcher** | StatusBarManager.swift | Nothing happens (osascript blocked) | Works | Clipboard fallback (like PluginInstaller) |

### Previously resolved

- ~~PluginInstaller~~ — dual-mode: automatic CLI in dev, clipboard + open Terminal in sandbox
- ~~SpeechService log~~ — moved to `DuckConfig.storageDir` (Application Support)
- ~~Legacy `~/.duck/api_key` migration~~ — removed from DuckConfig
- ~~Legacy `Application Support/RubberDuck/` migration~~ — removed from DuckConfig
- ~~HookInstaller.swift~~ — deleted (accessed `~/.duck/`, `~/.claude/settings.json`)
- ~~`.env` file loader~~ — removed (walked filesystem outside sandbox)
- ~~TTSEngine `/usr/bin/say`~~ — confirmed working in sandbox (no fix needed)
- ~~Bundle.module crash~~ — fixed: resource bundle copied to Contents/Resources/, Resources.bundle helper

## Auto-launch & Dormant Mode

The app starts dormant (menu bar icon only, no window, no dock icon). The full duck companion activates when the user clicks "Turn On Duck-Duck-Duck" in the menu or plugs in a duck USB device (serial auto-detect).

### Launch at Login (SMAppService — App Store safe)

Menu bar toggle: `🦆 → Launch at Login`. Uses `SMAppService.mainApp` to register/unregister the app as a Login Item. Works in sandbox. Combined with USB auto-detect, the duck is effectively always available: Mac boots → app starts dormant → plug in duck → companion activates.

**TBD:**
- Should we prompt users to enable this on first launch?
- Login Items appear in System Settings → General → Login Items — users can manage it there too.

### USB auto-launch via LaunchAgent (removed)

Previously explored IOKit matching via a launchd LaunchAgent plist to launch the app on USB plug-in. Removed because:
- ESP32-C3's built-in USB JTAG/serial has ROM-level descriptors that ignore `USB_PRODUCT`, so the device can't be named "Duck Duck Duck"
- Matching on Espressif VID would trigger on any ESP32 dev board
- Login Item + serial auto-detect achieves the same UX without the naming problem

## Shell scripts in plugin require bash

The plugin's hook scripts use `#!/bin/bash`. If a user's system doesn't have bash at `/bin/bash` (unlikely on macOS but possible on exotic setups), hooks fail silently.

## Hooks cached at session start

Claude Code loads hooks once when a session starts. If the widget isn't running when Claude starts, hooks fire but fail (connection refused to localhost:3333). Restarting the widget mid-session fixes it, but the user might not realize they need to restart Claude too if hooks were misconfigured at launch.

## Renaming checklist

If the product name changes again, update all of these:

| What | Where |
|------|-------|
| Plugin name | `plugin/.claude-plugin/plugin.json` → `"name"` |
| Plugin description | `plugin/.claude-plugin/plugin.json` → `"description"` |
| Marketplace name | `.claude-plugin/marketplace.json` → `"name"` |
| Marketplace plugin entry | `.claude-plugin/marketplace.json` → `plugins[0].name` + `description` |
| Hooks description | `plugin/hooks/hooks.json` → `"description"` |
| Bundle ID | `widget/Info.plist` → `CFBundleIdentifier` |
| Display name | `widget/Info.plist` → `CFBundleName` |
| Permission strings | `widget/Info.plist` → `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` |
| App Support dir | `widget/Sources/.../DuckConfig.swift` → `storageDir` path component |
| API key dialog | `widget/Sources/.../DuckConfig.swift` → `promptForAPIKey()` text |
| Log file name | `widget/Sources/.../DuckLog.swift` → `logURL` path component |
| Log file comment | `widget/Sources/.../DuckLog.swift` → header comment |
| Speech log name | `widget/Sources/.../SpeechService.swift` → `logURL` + header comment |
| Plugin README | `plugin/README.md` |
| Plugin PLAN | `plugin/PLAN.md` (historical, bulk replace) |

## Future R&D: Other AI CLI Tools

### Cursor (hooks system — mostly compatible)

Cursor 1.7+ (October 2025) has lifecycle hooks via `.cursor/hooks.json`. Cursor 2.5 (February 2026) added a plugin marketplace that bundles hooks, MCP servers, skills, subagents, and rules into installable packages.

**Hook mapping:**

| Duck Duck Duck | Claude Code | Cursor |
|---|---|---|
| `on-user-prompt.sh` | `UserPromptSubmit` | `beforeSubmitPrompt` ✅ (full prompt on stdin) |
| `on-claude-stop.sh` | `Stop` | `stop` ⚠️ (fires, but response text not confirmed in payload) |
| `on-permission-request.sh` | `PermissionRequest` | `beforeShellExecution` / `beforeMCPExecution` 🔶 (per-tool gate, not single event) |

**Gaps & risks:**
- **Response text missing from `stop` hook** — can score user prompts but may not be able to score AI responses without workaround (proxy, scraping)
- **Permission model is per-tool, not per-action** — no single "the agent wants permission" event. Would need to rethink the duck's voice approval flow into per-tool gates
- **Hook stability issues** — multiple forum reports of regressions in hook response fields (userMessage, agentMessage broken in v2.0.x). Fragile foundation to build on
- **Marketplace distribution** — `cursor.com/marketplace` could host our plugin, but packaging format differs from Claude plugins

**Verdict:** Doable for critic mode (prompt scoring only). Response scoring and voice permissions need workarounds or Cursor-side fixes. Wait for their hooks to stabilize.

**References:**
- Hooks docs: `cursor.com/docs/hooks`
- Marketplace: `cursor.com/docs/plugins/building`
- Regression tracker: `forum.cursor.com/t/regression-hook-response-fields-user-message-agent-message-still-ignored-in-windows-v2-0-77/142589`

### Codex CLI (notify mechanism — limited)

OpenAI's Codex CLI (`github.com/openai/codex`, Rust, 65K+ stars) has two hook mechanisms: a simple `notify` config and a feature-flagged hooks system.

**Hook mapping:**

| Duck Duck Duck | Claude Code | Codex CLI |
|---|---|---|
| `on-user-prompt.sh` | `UserPromptSubmit` | ❌ No per-prompt hook (SessionStart fires once) |
| `on-claude-stop.sh` | `Stop` | `notify` ✅ (carries `input_messages` + `last_assistant_message` as JSON argv) |
| `on-permission-request.sh` | `PermissionRequest` | ❌ No equivalent (has internal guardian subagent, no external hook) |

**Integration path:**
```toml
# ~/.codex/config.toml
notify = ["/path/to/duck-notify.sh"]
```
One line config. Script receives JSON with both prompt and response after each agent turn.

**Gaps & risks:**
- **No per-prompt hook** — can only score after the full turn completes, not when user submits. Loses real-time "incoming!" reaction
- **No permission hook** — Codex has its own approval system (`approval_policy`, guardian subagent) but no way for external tools to intercept. Voice permissions impossible
- **Feature flag gating** — hooks system requires `codex_hooks = true` in config, may not be enabled by default
- **No plugin marketplace** — no distribution story, manual config only
- **Fire-and-forget** — `notify` sends JSON as argv (not stdin), stdin/stdout/stderr all go to `/dev/null`. No way to block or respond

**Verdict:** Lowest priority. `notify` is trivially easy to wire up for after-the-fact scoring, but no real-time prompt reactions and no voice permissions. Worth a quick "works with Codex" badge but not a first-class integration.

**References:**
- GitHub: `github.com/openai/codex`
- Config docs: search for `notify` in repo README

## Gemini CLI integration — what's done, what's left

### Working now
- **Gemini evaluator** — `GeminiEvaluator.swift`, calls Gemini 2.5 Flash API with `thinkingBudget: 0` for fast structured JSON scoring
- **Intelligence picker** — Gemini appears in the menu bar alongside Foundation and Haiku, with API key prompt/storage/deletion
- **BeforeModel hook** — scores user prompts before they reach the LLM (equivalent to Claude's `UserPromptSubmit`)
- **AfterAgent hook** — scores Gemini's responses after each turn (equivalent to Claude's `Stop`)
- **Project-level config** — `.gemini/settings.json` in repo root, hooks auto-discovered when `gemini` is run from repo root

### Built but untested
- **Tmux permission relay** — `Notification` hook (`on-notification.sh`) fires on `ToolPermission`, POSTs to `/permission-gemini` endpoint. Widget speaks question, listens for voice, TmuxBridge types `y`/`n` into Gemini's tmux pane. GitHub-release only (TmuxBridge blocked in sandbox). Endpoint + hook built, needs live testing in tmux.
- **BeforeTool blocking hook** — `on-before-tool.sh` POSTs to `/permission` and blocks (exit 2 to deny). Works but fires for ALL tools, not just ones needing permission. Disabled in `.gemini/settings.json` — enable only if you want voice gating on every tool call.

### Not yet implemented
- **SessionStart greeting** — Gemini hooks don't support `additionalContext` injection like Claude's `SessionStart`. Could use `BeforeAgent` with `systemMessage` in the response JSON to inject duck personality context.
- **Hook auto-setup** — User must run `gemini` from repo root for `.gemini/settings.json` to be found. No plugin marketplace equivalent for Gemini CLI yet.

### Needs refinement
- **Foundation Models wildcard voice tuning** — Two-pass voice picking works (score first, pick voice second) but the 3B model's voice selection needs calibration in `widget/Playground/`. Current prompt gets superstar ~80% right but other voices trigger too eagerly for middle-of-the-road content. Iterate with real eval outputs.

### Known limitations
- Gemini CLI hooks only fire when run from a directory containing `.gemini/settings.json` (or a parent with one)
- `gemini-2.0-flash` is deprecated for new API keys — must use `gemini-2.5-flash` or newer
- Gemini 2.5 Flash is a thinking model — `thinkingBudget: 0` disables thinking for fast eval; without it, thinking tokens eat the output budget and responses get truncated

---

After updating, also:
1. `cd widget && swift build` — verify it compiles
2. Remove old marketplace: `claude plugin marketplace remove <old-name>-marketplace`
3. Push changes to GitHub
4. Re-add marketplace: `claude plugin marketplace add ideo/Rubber-Duck`
5. Install new plugin: `claude plugin install <new-name>`
6. Start a new Claude Code session (hooks are cached at session start)
