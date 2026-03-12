# Rubber Duck — Demo Script

## Before the demo

### Setup (do this 10 min before)
1. **Plug in Teensy** via USB — verify it shows up as a serial device
2. **Start the eval service**: `./scripts/start-service.sh`
3. **Start the widget**: `cd widget && make run`
4. **Verify connections**:
   - Widget should show green dot (listening) and blue dot (Teensy connected)
   - No red dot (means WebSocket is connected to service)
   - `curl http://localhost:3333/health` should return `{"status": "ok", "connected_clients": ...}`
5. **Open browser tabs** (optional, for screen share):
   - Dashboard: `http://localhost:3333/`
   - 3D Viewer: `http://localhost:3333/viewer`
6. **Position the duck widget** on screen where it's visible
7. **Test audio**: say "ducky hello" — duck should respond

### If something goes wrong
- Widget not connecting? Right-click → check "Service: Running" and "WebSocket: Connected"
- No sound? Check System Preferences → Sound → Output
- Teensy not responding? Unplug and replug USB, widget auto-reconnects
- Service crashed? `./scripts/start-service.sh` again

---

## Demo Flow (~10 minutes)

### Act 1: "Meet the Duck" (2 min)

> "We built a rubber duck for Claude Code. It watches your coding session, has opinions, and you can talk to it."

**Show**: Widget floating on desktop — yellow cube, breathing animation, little eyes.

> "It connects to a local eval service that scores every interaction on five dimensions: creativity, soundness, ambition, elegance, and risk."

**Show**: Point to dashboard in browser (optional) — the five dimension bars.

> "And there's a physical duck."

**Show**: Teensy on desk — LEDs, servo.

---

### Act 2: "Voice Interaction" (3 min)

> "The duck listens for a wake word — 'ducky'."

**Do**: Say **"ducky, let's build a simple todo app"**

- Widget shows the transcribed text in a speech bubble
- Duck says "On it."
- Text gets injected into a Claude Code terminal session via tmux

> "That voice input just became a Claude Code prompt. The duck is the intermediary."

**Wait** for Claude Code to start working. As Claude responds, hooks fire:

- **User prompt hook** fires → eval service scores the request
- Duck speaks the reaction: "Oh no, not another todo app" (or similar)
- Widget face changes — expression updates based on scores
- Teensy servo tilts, LEDs change color, piezo chirps
- Dashboard bars animate

> "Every interaction gets scored in real-time. The duck reacts with voice, animation, and hardware."

---

### Act 3: "Voice Permission Gate" (3 min)

> "Here's the key feature — voice-controlled permissions. When Claude wants to do something that needs approval, the duck asks."

**Wait** for Claude to trigger a permission request (e.g., writing a file, running a command).

When the duck speaks: "Claude wants to use Bash. Yes to allow, first to always allow Bash for this session, or no to deny."

- Widget face goes nervous — wobble animation, wide eyes
- Teensy shakes

> "I can approve by voice."

**Do**: Say **"yes"**

- Duck says "Got it."
- Widget relaxes
- Claude Code continues — the hook returned the approval programmatically
- No clicking required

> "The entire permission flow happened via voice. The hook script blocks, the service waits for my voice response, and returns the decision to Claude Code."

**Optional**: Trigger another permission, say **"first"** to pick the "always allow" option.

> "I can also say 'first' to pick a specific permission option — like always allowing Bash for this session. That gets applied as a permanent rule."

---

### Act 4: "Architecture & Roadmap" (2 min)

> "Here's how it works."

**Show**: Architecture diagram from the meeting doc (current state).

> "Hook scripts fire on user prompts and Claude responses. They POST to an eval service that calls Haiku to score the interaction. Results broadcast over WebSocket to the widget, dashboard, and Teensy."

> "The permission flow is a blocking HTTP round-trip. Hook fires, service broadcasts to widget, duck asks via voice, user responds, service unblocks, hook returns the decision to Claude Code."

> "Where this is going — this becomes a Claude Code plugin."

**Show**: Target MCP architecture diagram.

> "The eval service becomes an MCP server. Claude can directly call duck tools — speak, get mood, ask the user questions. The plugin bundles hooks, skills, and the MCP server. Install from the marketplace, plug in the hardware, go."

> "Long-term, the Teensy becomes an ESP32 with WiFi and a mic. The desktop widget becomes optional — the physical duck IS the interface."

---

## Key talking points if asked

- **Why a duck?** Rubber duck debugging is a real practice. We made the duck opinionated and voice-interactive.
- **Why voice?** Hands-free approval. You're coding, Claude needs permission, you just say yes. No context switch.
- **Why hardware?** Ambient awareness. You see the duck's mood change on your desk without looking at a screen. Physical presence.
- **What about latency?** Voice permission round-trip is ~6 seconds (STT + TTS + network). Eval scoring is sub-second with Foundation Models (on-device), ~2 seconds with Anthropic API.
- **Works with any project?** Currently hooks are per-project. Plugin packaging solves this — install once at user scope, works everywhere.
- **Desktop vs Terminal?** Terminal works cleaner (permission prompts clear properly). Desktop has a stale modal bug — that's one of our asks.
