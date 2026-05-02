# User Feedback Log

Rolling capture of external-user feedback with structured analysis and proposed actions. Append new rounds at the top; older rounds stay below for context.

---

## 2026-05-01 — Round 1 (test user A)

Source: direct chat. Onboarding feedback expected in a future round (user said so explicitly).

### Verbatim feedback

> I wish there were a control for the duck motion/motor. Right now it moves maybe several times a minute. The motor is a little loud in my home office, so I would want like maybe 3 settings:
>
> **Active**, which is the current mode;
> **Chill**, which moves pretty infrequently—like 2 times an hour so that the mouth is in a different state throughout the day, but it's NOT distracting;
> **Zen** (or whatever), which would just be off.

> It also seems like some of the sounds don't respect the volume control. It'll quack or something pretty loudly and then proceed to speak to me in an indoor voice.

> One more note: I want one more setting here which would basically alert me to only when Claude code requires some input from me and/or when it's finished with its current work. I imagine the duck being the little guy who's watching Claude for me and being like, "Hey! Hey dude! The computer thing needs you!" (But more subtle, obvs.)

> Maybe the descriptions of the settings could be clearer then. I didn't want the mic on, so I guess I gravitated towards the one with "No Mic" listed. Does that setting use the mic? Or maybe "Mic Off" could be a separate setting?

> "Permissions" implies I can give permission via voice. I can see why you'd want that, but I do probably want to go and read the output and use the keyboard to make a choice for the most part. (Otherwise I'll just turn on auto-mode).
>
> One thing that's confusing in the settings is that it says, like, "Opinions, permissions, voice." Opinions and voice are outputs from the duck, but permissions is vocal confirmation from me? Those are referring to two different "actors," so it wasn't that clear to me who the settings referred to.

User's own suggested mode descriptions:

> **Companion:** Ducky speaks opinions & alerts you to permission requests. You approve via voice.
> **Permissions Only:** Ducky alerts you to permission requests. You approve via voice.
> **Companion (No-Mic):** Ducky speaks opinions & alerts you to permission requests. You approve with clicks.

### Themes & proposed action

#### 1. Motor / motion noise control

**The ask:** three motion-frequency presets — Active (now), Chill (~2/hr movements), Zen (off). Servo is audible in a quiet room and too active by default.

**Action:** add a "Motion" setting with three options. Maps to a movement-rate envelope:
- Active: current behavior (multiple per minute, full ROM)
- Chill: ~2/hr, scheduled or randomized so the mouth pose changes through the day
- Zen: servo never moves; audio + visual reactions still fire

Independent of mode — orthogonal axis. Probably belongs in the right-click menu and Preferences alongside volume.

**Priority:** medium-high. This is the single concrete UX complaint that's blocking quiet-room use.

---

#### 2. Volume scope — some sounds bypass the slider

**The ask:** all sounds respect the volume control, including the quack/permission alert.

**Action:** audit every TTS / SFX path. Suspect culprits:
- Permission-arrival quack / chirp (may be hardware-direct via serial, bypassing CoreAudio volume)
- ESP32 stored-audio playback (may use its own gain stage)
- macOS `say` baseline (does respect volume — likely fine)

Need to confirm where the leak is, then route through the same gain control. Worth grepping for any direct `say` invocation or serial audio command that doesn't multiply by `coordinator.volume`.

**Priority:** medium-high. Explicit user complaint, easy class of bug.

---

#### 3. New mode: "Watcher" (alert-only)

**The ask:** a mode where the duck only speaks up when Claude needs input OR has finished its turn. Vibe: "Hey! The computer thing needs you!" — low chatter, just nudges.

Distinct from existing `permissionsOnly` (which is voice-approval focused, still chatty about permissions).

**Action options:**
- **A) Add a 5th DuckMode** — `watcher` (or `notifier`, `alerter`). Pros: clean, discoverable. Cons: another mode to label and explain, same actor-confusion problem as the others.
- **B) Add a "quietness" axis** orthogonal to mode — the user could set Companion + Quiet, or Permissions Only + Quiet, etc. Pros: composable. Cons: combinatoric labels, fiddly UI.
- **C) Reframe as a "what the duck reacts to" preference** — checkboxes for "user prompts," "Claude responses," "permissions," "Claude turn finished." Pros: maximum control. Cons: overwhelming for a setting nobody asked to fine-tune.

**Recommendation:** A. Single mode, easy to reason about. Wording could be:
> **Watcher:** Ducky stays quiet until Claude needs you or finishes a task. Then a brief nudge. You approve permissions with clicks.

**Priority:** medium. Real product surface, but bigger than a tweak — needs a design pass and probably ties into theme #4 (mode labels).

---

#### 4. Mode label & description clarity

**The ask:** rewrite mode descriptions so they don't conflate duck-output with user-input. Adopt the user's "Ducky [verb] / You [verb]" pattern.

**Current** (in [DuckProtocol.swift:38–46](widget/Sources/RubberDuckWidget/DuckProtocol.swift)):

| Mode | Subtitle |
|---|---|
| Companion | Opinions, permissions, voice |
| Permissions Only | Permissions, voice, no opinions |
| Companion (No Mic) | Opinions, click-only permissions |
| Relay | Talk to Claude CLI |

**User's actor-separated rewrite (drop-in fix):**

| Mode | Subtitle |
|---|---|
| Companion | Ducky speaks opinions & alerts on permissions. You approve via voice. |
| Permissions Only | Ducky alerts on permissions. You approve via voice. |
| Companion (No Mic) | Ducky speaks opinions & alerts on permissions. You approve with clicks. |
| Relay | (needs same pattern — TBD) |

Also worth: change the **mode name** "Companion (No Mic)" — user gravitated to it specifically because "No Mic" was the only mention of mic state, but the parenthetical hides it. Possible names:
- "Click-Only" (mirrors what the user *does* in that mode)
- "Silent Companion" (ambiguous — could mean duck is silent)
- "Companion — Mic Off" (most literal)

**Priority:** high. Two-sentence textual change; fixes a confusion the user explicitly called out.

---

#### 5. Mic on/off as a separate concept

**The ask:** mic state is currently coupled to mode (only `companionNoMic` disables it). User suggests a global "mic on/off" toggle independent of mode.

**Trade-off:** the user themselves notes this complicates things — mic-off is a hard requirement on macOS for some users (privacy, meeting overlap), and they'd want it remembered. But adding a global toggle on top of mode also creates "is this state actually active?" confusion.

**Option:** add `permissionsOnly (No Mic)` as a 5th mode (parallel to `companionNoMic`). Doesn't introduce a global toggle, but covers the matrix the user implied. Combined with #4's renaming, the 5–6 mode list stays scannable:

- Companion (mic on)
- Companion — Mic Off
- Permissions Only (mic on)
- Permissions Only — Mic Off (NEW)
- Watcher (NEW from #3, mic off implicit)
- Relay

Or — simpler — punt and make Watcher mic-off-only. Then there are 5 modes max.

**Priority:** medium. Worth considering but #3 + #4 might cover this without a separate fix.

---

### Open questions for next round

- Confirm which sounds bypass the volume slider (need to repro with logging)
- Decide #3 implementation shape (5th mode vs orthogonal axis vs checklist)
- Which name lands for "Companion (No Mic)" — prefer one that doesn't lead with the mic state
- Onboarding feedback from same user (promised separately)
- Does anyone use Relay? If usage is near-zero, removing it would simplify the menu before we add Watcher
