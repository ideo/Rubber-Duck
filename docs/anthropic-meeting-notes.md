# Anthropic Meeting — Tuesday

## What We Built

Rubber Duck is a **Claude Code plugin + companion app + hardware peripheral**.

### Architecture (current)
```
┌─────────────────────────────────────────────────┐
│  Claude Code (with Rubber Duck plugin)          │
│  ├─ Hooks: UserPrompt, ClaudeStop, Permission   │
│  ├─ Skills: /duck:status, /duck:voice-mode      │
│  └─ Agent: duck personality context             │
└──────────────┬──────────────────────────────────┘
               │ HTTP (hooks POST)
               ▼
┌─────────────────────────────────────────────────┐
│  Eval Service (server.py)                       │
│  ├─ Eval engine (Haiku scoring, 5 dimensions)   │
│  ├─ Permission gate (blocking HTTP → voice)     │
│  ├─ WebSocket hub (broadcast to all clients)    │
│  └─ tmux bridge (voice → Claude Code input)     │
└──┬────────────┬────────────┬────────────────────┘
   │ WebSocket  │ WebSocket  │ WebSocket
   ▼            ▼            ▼
 Widget      Dashboard    3D Viewer
 (SwiftUI)   (browser)   (browser)
   │
   ├─ Speech I/O (STT + TTS)
   └─ Serial → Teensy (servo/LED/piezo)
```

### Architecture (target — MCP-based)
```
┌─────────────────────────────────────────────────┐
│  Claude Code (with Rubber Duck plugin)          │
│  ├─ Hooks: UserPrompt, ClaudeStop, Permission   │
│  ├─ Skills: /duck:status, /duck:voice-mode      │
│  └─ Agent: duck personality context             │
└──────────────┬──────────────────────────────────┘
               │ stdio (MCP protocol)
               ▼
┌─────────────────────────────────────────────────┐
│  Duck MCP Server (= eval service, single proc)  │
│  ├─ stdio: Claude tools (speak, get_mood, ask)  │
│  ├─ HTTP: hook endpoints (/evaluate, /permission)│
│  ├─ WebSocket: broadcast to widget/dashboard     │
│  └─ Eval engine (Haiku scoring)                  │
└──┬────────────┬────────────┬─────────────────────┘
   │ WebSocket  │ WebSocket  │ WebSocket
   ▼            ▼            ▼
 Widget      Dashboard    3D Viewer
```

MCP server is the eval service — single process, dual interface:
- **stdio** → Claude Code calls tools: `duck.speak()`, `duck.get_mood()`, `duck.ask_user()`
- **HTTP + WebSocket** → hooks POST, widget/dashboard/viewer connect (same as today)

This kills the tmux hack — Claude can natively interact with the duck via MCP tools.

### Long-term vision: standalone hardware duck
```
┌─────────────────────────────────────────────────┐
│  Claude Code + Plugin + MCP Server              │
└──────────────┬──────────────────────────────────┘
               │ WebSocket (WiFi)
               ▼
┌─────────────────────────────────────────────────┐
│  ESP32-S3 Duck (standalone hardware)            │
│  ├─ WiFi → connects to MCP server               │
│  ├─ Mic + Speaker → Realtime API (STT/TTS)      │
│  ├─ Servos, LEDs, piezo (physical reactions)     │
│  └─ Voice permission gate (on-device)            │
└─────────────────────────────────────────────────┘
```

Desktop widget becomes a **software-only fallback** for users without hardware.
End-user story: **Install the plugin. Plug in the duck. Go.**

---

## Asks for Anthropic

### 1. Desktop UI: stale permission modals after hook approval
- When a `PermissionRequest` hook returns a decision, Claude Code's engine accepts it and continues — but Desktop still renders the permission modal overlay. User sees stale modals stacking up.
- Terminal Claude Code correctly clears the prompt. Desktop-specific bug.
- **Ask**: Auto-dismiss or don't show the modal when hook handles it.

### 2. Hook output format was undocumented
- The correct format (`hookSpecificOutput.decision.behavior`) was not obvious. A flat `{"decision": "allow"}` silently fails. We debugged this for hours.
- **Ask**: Better docs or error messages for malformed hook output.

### 3. Programmatic input to Claude Code sessions
- Voice input currently requires tmux `send-keys` — brittle workaround.
- MCP tools can provide output back to Claude, but can a tool push a new user prompt?
- **Ask**: Can MCP tools (or another mechanism) inject prompts into a running session?

### 4. Global session context injection
- Plugin agents provide duck context, but does this apply across all projects automatically?
- **Ask**: Confirm that user-scoped plugins inject their agent context into every session.

---

## Our TBDs (things we build)

### Plugin packaging
- Restructure repo as a Claude Code plugin: `.claude-plugin/plugin.json`, hooks, skills, MCP server config.
- Publish to plugin marketplace once stable.
- Plugin installs at user scope → works across all projects.

### MCP server consolidation
- Merge eval service into an MCP server that also serves HTTP + WebSocket.
- Claude Code talks to it via stdio (MCP tools). Hooks POST to it. Widget connects via WebSocket.
- Single process replaces eval service + tmux bridge.
- MCP tools: `duck.speak(text)`, `duck.get_scores()`, `duck.get_mood()`, `duck.ask_user(question)`

### Multi-session permission disambiguation
- Hook input includes `session_id` — map to friendly names.
- Service tracks `session_id` → "terminal" / "desktop".
- Duck says "Terminal Claude wants to use Bash" instead of just "Claude".

### Conversational permission gate
- Permission mode becomes a mini LLM conversation instead of keyword matching.
- User can ask "what does that do?" or "is that risky?" and the duck explains.
- Non-keyword utterances → Haiku with permission context → spoken explanation → keep listening.
- Depends on: Realtime API for natural back-and-forth.

### ESP32-S3 standalone duck
- Replace Teensy (USB serial, no networking) with ESP32-S3 (WiFi + BLE).
- On-device mic + speaker → Realtime API for STT/TTS.
- Connects to MCP server over WiFi WebSocket.
- Desktop widget becomes optional — physical duck IS the interface.
