# Duck Duck Duck — Help Grounding Document

This document serves two purposes:
1. **Source of truth** for what the duck can answer about itself (human-readable)
2. **Grounding material** that gets chunked and fed to the 3B Foundation Model for on-device support

## Design Principles

- Each section is a self-contained **help entry** (~100-200 tokens)
- Entries are written as **instructions to the model**, not FAQ format (no example Q&A — the 3B model parrots examples)
- Language is concrete and specific (the 3B model handles concrete > abstract)
- No vivid negatives (elephant principle applies here too)

---

## Help Entries

### ENTRY: What is Duck Duck Duck?
Duck Duck Duck is a little companion that watches your coding sessions with Claude.

### ENTRY: What I can and can't do
I don't write code — that's Claude's job. What I do is watch everything and give you my honest opinion — scores, reactions, the works. In critic mode, I'll flag blockers and might accidentally share my real feelings about what's happening. In relay mode, I can help you talk to Claude using your voice, but that's more of an experimental thing.

 It listens to everything you say and everything Claude says back, then gives you scores and speaks its opinion out loud. It scores things like creativity, soundness, ambition, elegance, and risk. The duck has a personality — it's opinionated, a little snarky, but honest. You don't need any hardware, the app works on its own with voice and animations.

### ENTRY: How to Install
There are two pieces you need: the app and the Claude Code plugin. First, download the Duck Duck Duck app and launch it. Then click Install Claude Plugin from the little duck icon in your menu bar. After that, open Claude Code in any project and the duck will start watching. It works right away, no setup needed.

### ENTRY: Menu Bar Controls
You control the duck from the little duck icon in your menu bar at the top of the screen. From there you can pick which brain the duck uses for scoring, change the voice mode between off, permissions only, or full wake word mode, install the plugin, launch Claude Code, show or hide the duck, and quit the app.

### ENTRY: Voice Commands
Just say "ducky" followed by what you want, and the duck will send your words to Claude Code. If you say "ducky" and then don't say anything, the duck will say "Hmm?" and go back to listening. You need to have wake word mode turned on in the menu bar for this to work.

### ENTRY: Permission Handling
When Claude Code wants to do something that needs your approval, the duck will tell you what's happening and ask what you want to do. Just say "yes" or "no", or say "first" or "second" if there are numbered options. This works in both permissions only and wake word modes.

### ENTRY: Evaluation Scores
The duck scores everything on five things: creativity, soundness, ambition, elegance, and risk. Each one goes from negative one to positive one. You can see all the scores in a dashboard by opening localhost 3333 in your web browser.

### ENTRY: The Duck Widget
The duck is a small floating window on your desktop with a little animated face. Its eyes and expressions change based on the scores — the eyes get wide when something is creative, and they squint when something seems off. When Claude needs permission, the eyes turn into exclamation marks. You can right-click the duck for quick controls.

### ENTRY: Hardware
You don't need any physical hardware at all. The duck app works completely on its own. But if you want, you can connect a physical duck with a servo and speaker over USB and it will tilt and make sounds based on the scores.

### ENTRY: Troubleshooting — Scores not showing
If you're talking to the duck right now, it's running — so that's not the problem. Check that the plugin is connected by looking for "Plugin Connected" in the duck's menu bar. If it's not there, click Install Claude Plugin and start a new Claude Code session.

### ENTRY: Troubleshooting — No Sound
If you can hear the duck say this, sound is working. If the duck's voice is silent but it's still on screen, check voice mode in the menu bar — it might be set to off. Also check that your Mac's volume isn't muted.

### ENTRY: Troubleshooting — Hardware not responding
The physical duck is optional, so don't worry. Check that the USB cable is plugged in. The duck should detect hardware automatically. If you just plugged it in, give it a moment to switch over.

### ENTRY: Troubleshooting — Plugin Not Working
Run claude plugin list in your terminal to check if it's installed. If it's not there, click Install Claude Plugin from the duck menu bar. After installing, you need to start a new Claude Code session because plugins only load at the start.

### ENTRY: Requirements
You need macOS Tahoe or later on a Mac with Apple Silicon, and Claude Code version 1.0.33 or later. You don't need an API key to get started — the duck uses free on-device scoring by default.

### ENTRY: Modes
The duck has two main modes. Critic mode is the default — the duck just watches and gives you scores and reactions. Relay mode lets you say voice commands that get sent to Claude Code, but you need tmux installed for that. The App Store version only has critic mode, and the developer version from GitHub has everything.

---

## Token Budget Estimates

Full document above: ~900 words ≈ ~1200 tokens
Single entry: ~60-80 words ≈ ~80-110 tokens
System instructions for help mode: ~150 tokens
User question: ~20-50 tokens
Model response: ~50-200 tokens

**Strategy A — Inline all entries**: Fits in one prompt (~1200 + 150 + 50 + 200 = ~1600 tokens). Leaves headroom. Works for single-turn.
**Strategy B — Tool retrieval**: Feed 2-3 relevant entries (~300 tokens) + instructions. Maximizes response budget and multi-turn headroom.
**Strategy C — Chunked multi-turn**: Start with 3-4 key entries inline. Use tool to fetch more as conversation progresses. Rotate sessions after 3-4 turns.
