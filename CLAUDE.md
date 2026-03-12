# Rubber Duck — Claude Code Context

You are running inside the **Rubber Duck** project. A physical rubber duck companion is watching this session, evaluating your work, and reacting with opinions via voice, animations, and hardware actuators.

## What's happening

- Every prompt you receive and every response you generate is scored on creativity, soundness, ambition, elegance, and risk. By default this uses Apple Foundation Models on-device (~3B, free, sub-second). Optionally switches to Anthropic API (Claude Haiku) for higher-quality scoring.
- The duck widget (a liquid glass SwiftUI duck floating on the desktop) animates based on those scores and speaks gut reactions out loud.
- If you are running in a tmux session named "duck", the user can speak voice commands to you by saying "ducky [command]".

## Hooks active in this project

These fire automatically for your session:

- **UserPromptSubmit** (`scripts/on-user-prompt.sh`) — sends the user's prompt to the eval service
- **Stop** (`scripts/on-claude-stop.sh`) — sends your response to the eval service
- **PermissionRequest** (`scripts/on-permission-request.sh`) — blocks and asks the user via voice whether to allow the action. The duck will speak the question and listen for "yes" or "no". You don't need to do anything special — just proceed normally and the hook handles approval.

## Architecture overview

```
Widget (SwiftUI, macOS 26) — owns everything: eval server, speech, serial, duck UI
    |
    HTTP+WebSocket (localhost:3333, MiniServer — zero-dep Network.framework)
    |
    hooks (shell scripts POST to /evaluate, /permission)
    |
You (Claude Code) — this session
```

## Key files

- `widget/Sources/RubberDuckWidget/` — SwiftUI app (DuckServer, MiniServer, LocalEvaluator, ClaudeEvaluator, SpeechService, SerialManager, DuckView)
- `widget/Sources/RubberDuckWidget/MiniServer.swift` — zero-dependency HTTP+WebSocket server (Network.framework + CryptoKit)
- `widget/Sources/RubberDuckWidget/DuckView.swift` — liquid glass duck face with `.glassEffect()`, exclamation mark permission eyes
- `widget/Sources/RubberDuckWidget/ExpressionEngine.swift` — maps eval scores to visual state (eye shape, hue shift, glow)
- `widget/Sources/RubberDuckWidget/DuckTheme.swift` — design tokens (colors, sizes, animation constants)
- `widget/assets/duckIcon.icon` — Apple Icon Composer icon bundle (compiled via actool in Makefile)
- `scripts/` — hook scripts that connect Claude Code to the eval service
- `firmware/rubber_duck/` — Teensy 4.0 firmware for servo/LED/piezo
- `widget/Sources/RubberDuckWidget/Resources/dashboard.html` — browser dashboard at localhost:3333
- `widget/Sources/RubberDuckWidget/Resources/viewer.html` — Three.js 3D viewer at localhost:3333/viewer

## Style notes

- The duck has personality. It's opinionated, occasionally snarky, but ultimately helpful.
- Eval reactions are short (max 10 words) gut reactions like "Now THAT'S what I'm talking about" or "Did a toddler write this?"
- The duck uses a voice called "Boing" for TTS. It's intentionally goofy.

## Safety rules

- **NEVER use `pkill -f`**. The `-f` flag matches the full command line of all processes and can kill system processes like WindowServer, crashing the entire GUI. Use `killall <name>` or `pkill <name>` (without `-f`) instead.
- **Mac App Store sandbox**: The widget must work under App Sandbox. It may ONLY read/write files inside `~/Library/Application Support/DuckDuckDuck/` (via FileManager container APIs). It must NEVER access `~/.claude/`, `~/Documents/`, `~/Library/Preferences/`, or any path outside its sandbox container. All state (API key, PID, logs, session timestamps) belongs in Application Support. The only way to detect the plugin is via the `/health` HTTP ping — never read Claude's settings files. Network: `localhost:3333` (own server) and `api.anthropic.com` (eval scoring) only.

## Dev workflow

- Widget: `cd widget && make run` (builds release + compiles icon via actool + bundles app + launches)
- Debug: `cd widget && make debug` (swift build debug + runs in terminal)
- Full session: `./scripts/duck-session` (tmux with Claude Code; widget must be running)
- The widget's right-click menu has "Start Claude Session" to launch a terminal Claude Code in tmux.
- Build stack: swift-tools-version 6.2, macOS 26, Swift 5 language mode (for concurrency compat)
- Zero external dependencies — Network.framework for HTTP/WS, CryptoKit for WebSocket handshake

## Serial protocol (widget → Teensy / ESP32)

Score messages (on every eval):
```
{U|C},creativity,soundness,ambition,elegance,risk\n
```
- `U` = user prompt evaluated, `C` = Claude response evaluated
- All floats from -1.0 to 1.0
- Example: `C,0.72,0.85,0.40,0.61,-0.20\n`

Permission commands:
```
P,1\n   — permission requested (alert!)
P,0\n   — permission resolved (calm down)
```

Sentiment formula: `soundness*0.3 + elegance*0.25 + creativity*0.2 + ambition*0.15 - risk*0.1`

## Hot-unplug Teensy → fallback to local audio

Implemented. When the Teensy USB device is unplugged mid-session, the widget detects the change and switches to local Mac mic + speakers. Plugging back in switches back to Teensy.

**How it works:**
- `AudioDeviceDiscovery.DeviceChangeListener` — CoreAudio `kAudioHardwarePropertyDevices` property listener fires on any device add/remove
- `SpeechService.handleDeviceChange()` — detects Teensy appearing/disappearing, re-runs `selectMicrophone()`, restarts STT on the new device
- `TTSEngine` — if `say -a "Teensy MIDI_Audio"` fails (non-zero exit), clears `outputDeviceName` and retries on system default
- `STTEngine.clearTeensyDevice()` — lets SpeechService force STT back to default mic
