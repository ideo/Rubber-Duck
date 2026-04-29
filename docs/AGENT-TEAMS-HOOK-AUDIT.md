# Agent Teams Hook Audit

How the Duck Duck Duck plugin's hooks behave when Claude spawns sub-agents (the `Agent` tool / agent teams), and what — if anything — should change.

Sources:
- Hook events & payload fields: https://code.claude.com/docs/en/hooks
- Plugin hooks live in `plugin/hooks/`, registered via `plugin/hooks/hooks.json`.

## Sub-agent fields (recap)

When a hook fires *inside* a sub-agent's execution, two extra fields appear on the JSON stdin:

- `agent_id` — unique per sub-agent invocation
- `agent_type` — agent name (e.g. `"Explore"`, `"general-purpose"`)

Per the docs, these fields are absent for main-session hook firings. Plugin v3 already uses this in `on-permission-request.sh` (line 44–53).

## Which events even fire for sub-agents

Per the docs:

| Event | Fires inside sub-agent? |
|---|---|
| `UserPromptSubmit` | ❌ no — main session only |
| `Stop` | ❌ no — converts to `SubagentStop` |
| `SubagentStart` / `SubagentStop` | ✅ yes (we don't subscribe) |
| `PermissionRequest` | ✅ yes (carries `agent_id`) |
| `PreToolUse` / `PostToolUse` | ✅ yes (carries `agent_id`) |
| `SessionStart` / `SessionEnd` | ❌ no |
| `PreCompact` / `PostCompact` | ❌ no |
| `Notification` / `StopFailure` | docs imply session-level; treat as main-only |

This is the load-bearing fact: most of our hooks **simply will not fire** inside sub-agents, so most of the worry is moot. The only hook today that meaningfully fires inside a sub-agent is `PostToolUse`, plus `PermissionRequest` (which is already filtered).

## Hook inventory

| Hook script | Lines | Event | What it does | Fires for sub-agents? | Sub-agent filter today |
|---|---|---|---|---|---|
| [on-user-prompt.sh](plugin/hooks/on-user-prompt.sh) | 29 | `UserPromptSubmit` | POSTs prompt to `/evaluate` so the duck reacts to the user's message | ❌ never | n/a (event doesn't fire) |
| [on-claude-stop.sh](plugin/hooks/on-claude-stop.sh) | 82 | `Stop` | POSTs Claude's last message + last user message to `/evaluate` | ❌ never (becomes `SubagentStop`, which we don't subscribe to) | n/a |
| [on-permission-request.sh](plugin/hooks/on-permission-request.sh) | 159 | `PermissionRequest` | Voice-prompts the user, blocks until allow/deny | ✅ yes | **already filters** — early-exit if `agent_id` non-empty (lines 44–53) |
| [on-session-start.sh](plugin/hooks/on-session-start.sh) | 76 | `SessionStart` | Health-checks widget, version-pings, injects greeting context | ❌ never | n/a |
| [on-session-end.sh](plugin/hooks/on-session-end.sh) | 19 | `SessionEnd` | Pings `/session-end` so duck says goodbye | ❌ never | n/a |
| [on-pre-compact.sh](plugin/hooks/on-pre-compact.sh) | 19 | `PreCompact` | Tells widget to start "Jeopardy" thinking melody | ❌ never | n/a |
| [on-post-compact.sh](plugin/hooks/on-post-compact.sh) | 19 | `PostCompact` | Tells widget to stop the melody | ❌ never | n/a |
| [on-post-tool-use.sh](plugin/hooks/on-post-tool-use.sh) | 14 | `PostToolUse` | Pings `/permission-clear` to clear the duck's permission-pending state | ✅ yes | **none** — fires for every sub-agent tool use too |
| [on-stop-failure.sh](plugin/hooks/on-stop-failure.sh) | 19 | `StopFailure` | Pings `/stop-failure` so duck reacts to API errors | unclear; treat as main-only | none |

Note: `on-stop-failure.sh` exists on disk but is **not registered in `hooks.json`** (no `StopFailure` entry). It's currently dead code — worth noting but out of scope.

## Recommendations

| Hook | Sub-agent behavior today | Recommended | Notes |
|---|---|---|---|
| `on-user-prompt.sh` | Cannot fire inside sub-agents | **No change** | Already correct by virtue of the event |
| `on-claude-stop.sh` | Cannot fire inside sub-agents (`Stop` ≠ `SubagentStop`) | **No change** | If we ever subscribe to `SubagentStop`, gate it behind a "score sub-agents?" toggle (default off). Otherwise the duck would react to internal agent monologues the user never sees |
| `on-permission-request.sh` | Pass-through when `agent_id` set | **Keep** | Correct — main session's UI handles the dialog; duck speaking up too would be confusing |
| `on-session-start.sh` | Cannot fire | No change | — |
| `on-session-end.sh` | Cannot fire | No change | — |
| `on-pre-compact.sh` / `on-post-compact.sh` | Cannot fire | No change | — |
| `on-post-tool-use.sh` | Fires for every sub-agent tool — clears permission-pending state | **Add `agent_id` skip** | Low-priority but a real wart: while a sub-agent is running, every tool it uses will spam `/permission-clear`. If a real permission dialog is open in the main session, a sub-agent tool firing could prematurely clear the duck's "alert" state. Cheap one-liner fix: `[ -n "$(json_get "$INPUT" agent_id "")" ] && exit 0` |
| `on-stop-failure.sh` | Not registered in `hooks.json` | **Either wire it up or delete** | Out of scope here — flagging as separate cleanup |

### Future: do we want to react to sub-agents at all?

Today the duck is invisible to sub-agent activity, which is probably the right default — sub-agents can be dozens of internal tool calls, and scoring each one would drown the user in chatter. Two things worth considering later:

- **`SubagentStart` chime** — a brief "duck noticed a sub-agent kicked off" cue, no eval. Useful UX signal that work is happening in the background.
- **`SubagentStop` summary score** — score the sub-agent's *final* message only, with a distinct visual (e.g. dimmer or different hue). Keep main-session scoring as the loud channel.

Both are deferrable; they need their own design pass.

## What's worth changing first

1. **Add `agent_id` skip to `on-post-tool-use.sh`.** One line, prevents sub-agent tool spam from clobbering the duck's permission-pending state during real main-session prompts. Low risk, ~30 seconds of work.
2. **Decide what to do with `on-stop-failure.sh`.** It's not registered in `hooks.json` — either wire it up or delete the file. Not sub-agent related, just stale.
3. **Everything else: leave alone.** Most hooks physically can't fire inside sub-agents, so there's no bug to fix, just a future design question (do we *want* to react to sub-agents?) that can wait.
