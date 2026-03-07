# Rubber Duck — Claude Code Context

You are running inside the **Rubber Duck** project. A physical rubber duck companion is watching this session, evaluating your work, and reacting with opinions via voice, animations, and hardware actuators.

## What's happening

- Every prompt you receive and every response you generate is being sent to an eval service that scores it on creativity, soundness, ambition, elegance, and risk.
- The duck widget (a yellow SwiftUI cube on the user's desktop) animates based on those scores and speaks gut reactions out loud.
- If you are running in a tmux session named "duck", the user can speak voice commands to you by saying "ducky [command]".

## Hooks active in this project

These fire automatically for your session:

- **UserPromptSubmit** (`scripts/on-user-prompt.sh`) — sends the user's prompt to the eval service
- **Stop** (`scripts/on-claude-stop.sh`) — sends your response to the eval service
- **PermissionRequest** (`scripts/on-permission-request.sh`) — blocks and asks the user via voice whether to allow the action. The duck will speak the question and listen for "yes" or "no". You don't need to do anything special — just proceed normally and the hook handles approval.

## Architecture overview

```
Widget (SwiftUI) — owns speech (STT/TTS), serial (Teensy), duck UI
    |
    WebSocket
    |
Eval Service (Python :3333) — scores via Claude Haiku, broadcasts results
    |
    hooks
    |
You (Claude Code) — this session
```

## Key files

- `widget/Sources/RubberDuckWidget/` — SwiftUI app (DuckView, SpeechService, SerialManager, EvalService, ServiceProcess)
- `service/server.py` — eval service, WebSocket, permission gate, tmux bridge
- `scripts/` — hook scripts that connect Claude Code to the eval service
- `firmware/rubber_duck/` — Teensy 4.0 firmware for servo/LED/piezo
- `service/dashboard.html` — browser dashboard at localhost:3333
- `service/viewer.html` — Three.js 3D viewer at localhost:3333/viewer

## Style notes

- The duck has personality. It's opinionated, occasionally snarky, but ultimately helpful.
- Eval reactions are short (max 10 words) gut reactions like "Now THAT'S what I'm talking about" or "Did a toddler write this?"
- The duck uses a voice called "Boing" for TTS. It's intentionally goofy.

## Dev workflow

- Widget: `cd widget && make run` (builds and launches the app, which auto-starts the eval service)
- Service only: `python3 service/server.py`
- Full session: `./scripts/duck-session` (tmux with Claude Code + service)
- The widget's right-click menu has "Start Claude Session" to launch a terminal Claude Code in tmux.
