# Help Manual Recommendations

Status: **proposed** — audit of all user-facing help surfaces, March 2026.

Sources reviewed: `HelpView.swift`, `DUCK-HELP-GROUNDING.md`, `README.md`, `ONBOARDING.md`, `DuckHelpService.swift`, `TONE-REFERENCE.md`, `MOBY-DUCK.md`, and the full marketing site at duck-duck-duck.web.app.

---

## Surfaces Covered

| Surface | File | Audience |
|---------|------|----------|
| In-app manual | `widget/.../HelpView.swift` | End users (Help → User Manual) |
| On-device help grounding | `docs/DUCK-HELP-GROUNDING.md` | 3B Foundation Model (powers "ask the duck") |
| GitHub README | `README.md` | Developers and prospective users |
| Conversational help prompts | `widget/.../DuckHelpService.swift` | Foundation Model system prompt |

The README is the most current. The grounding doc is the most stale. HelpView is in between.

---

## 1. Factual Corrections

### DUCK-HELP-GROUNDING.md — needs a rewrite

The grounding doc feeds the duck's spoken answers. Errors here become misinformation delivered in Boing's voice.

| Issue | Current | Should be |
|-------|---------|-----------|
| Mode names | "Critic mode" | "Companion" (renamed) |
| Mode count | "two main modes" | Four: Companion, Permissions Only, Companion (No Mic), Relay |
| Claude Desktop | Not mentioned | Supported via Export Plugin Zip |
| Wildcard voice | Not mentioned | Shipped — score-gated AI picks from 10 voices |
| "Always allow" | Not mentioned | Valid permission response alongside yes/no |
| Conversational help | Not mentioned | The duck can answer questions about itself |
| Gemini CLI | Not mentioned | Experimental, observe-only |
| Jeopardy melody | Not mentioned | Plays during context compaction |

### HelpView.swift — missing shipped features

| Gap | Notes |
|-----|-------|
| Wildcard voice | README documents "score-gated AI picks from 10 voices per reaction" — manual doesn't mention it |
| "Always allow" | README voice table includes it; manual only says "yes" or "no" |
| Conversational help | You can ask the duck questions — the manual never says this |
| Compaction melody | Duck hums Jeopardy during context compaction — undocumented |
| `/reload-plugins` | README troubleshooting mentions it; manual Tips section doesn't |
| **Stopping Speech section** | References tap-to-stop, which has been removed. Section should be cut or replaced. |

### README.md

Most current of the three. Main gap: it's developer-facing and doesn't try to be the manual. Features land here first and don't always propagate to HelpView or the grounding doc.

---

## 2. Tone Gaps

Reference: `TONE-REFERENCE.md` rules and the marketing site voice.

### The target register

Technically credible, emotionally unserious. The marketing site treats real engineering as comedy material ("If we said micro one more time your head would explode from our sheer technical prowess") and plays absurdity completely straight ("His arrest record's as long as a pond is wide. It's mostly bar fights."). Melville pastiche on the Moby Duck page is committed, not ironic.

### Where HelpView nails it

These lines are marketing-site quality and should be preserved:

- "It's opinionated. It's sometimes wrong. It's always honest."
- "For when you want to be judged but not heard." (Companion No Mic)
- "held together with duct tape" / "a war crime against readability" / "barely a bunt"
- "Proceed with enthusiasm." (Experimental intro)
- "Ducks have weird hole-shaped ears. Now you know."
- "Don't know what tmux is? That's okay. You can still have a duck."

### Where HelpView goes flat

| Section | Problem | Direction |
|---------|---------|-----------|
| Getting Started | Reads like a standard setup guide. No personality after the numbered steps. | Marketing site covers the same ground with "Everything runs locally on a single USB cable, so don't worry about security breaches." Borrow that energy. |
| Microphone & Audio | Longest section, most conventional. Opens well ("Yes, he can hear you") then immediately becomes Apple support docs. | Could use a duck-fact break or punchier subheads. The mode-by-mode bullet list is useful but dry. |
| Menus | Pure reference inventory. | Even one line — treat features as flex, not inventory. |
| Preferences | "Open with ⌘, or from the Duck Duck Duck menu." Could be any app. | A single opinionated line would distinguish it. |
| Privacy | Correct but earnest. Three paragraphs where the marketing site says "don't worry about security breaches" in one line. | Lead with confidence, then provide the detail. The detailed breakdown is necessary for people who care — but the opening should feel like the duck, not a compliance officer. |

### Grounding doc is the flattest

This is the worst place for flat tone because it feeds the duck's *voice*. When someone asks "what are you?" the answer comes from this doc.

- Current: "Duck Duck Duck is a little companion that watches your coding sessions with Claude."
- HelpView: "A rubber duck that actually talks back."
- Marketing: "Your new rubber duck best friend: a physical AI companion that talks back!"

The 3B model can handle personality in source material. What it can't do is invent personality from sterile input. Entries should be rewritten in first person, in the duck's voice.

---

## 3. Missing Sections

### "Talk to the Duck" / "Asking for Help"

The conversational help system is a significant feature — you can ask the duck questions and it answers in character. The manual documents voice commands and relay mode but never says "you can also just ask the duck a question." This is the most duck-like feature and it's undocumented.

Suggested placement: after Modes, before Microphone & Audio.

### Duck face expressions

The ExpressionEngine maps scores to eye shapes, hue shifts, and glow. The manual says "You'll know when he disapproves" but never explains what the face actually means.

Doesn't need to be technical. Something like:

> Wide eyes? He's impressed. Squinting? Suspicious. Exclamation marks? Claude needs permission and the duck needs your attention. If he's glowing green, you're on a roll. Red? Maybe reconsider.

### Compaction melody

When Claude compacts context, the duck hums Jeopardy. It's surprising, people will wonder what it is, and it's the kind of detail the marketing site would lead with.

One line in Tips is probably enough: "Hear Jeopardy? Claude is compacting context. He's thinking."

### Moby Duck tease (strengthen)

The manual says "Just don't ask him about Ahab" — correct level of tease per tone rules. But the marketing site has an entire page and breaks the fourth wall ("Wait, delete that"). The manual could push slightly further without spoiling. Candidates:

- A closing line before the footer: "He has a backstory. He won't tell you willingly."
- In the "What is this thing?" section: "He's been places. The ocean, mostly."
- A fourth-wall break somewhere: "— actually, he'd rather tell you himself."

One of these, not all three.

---

## 4. Specific Rewrites

### Getting Started — add warmth after the steps

Current closing:
> No config files. No API keys required. Eval runs on-device for free.

Suggested:
> No config files. No API keys required. Eval runs on-device for free. He's watching before you've finished reading this.

### Menus — one line of personality

Current opening:
> **Menu bar icon (🦆)** — Quick access to Volume, Mode, Voice, Intelligence, Launch Claude Code, Pause/Resume, and Quit.

Suggested:
> **Menu bar icon (🦆)** — Everything you need to control a duck. Volume, Mode, Voice, Intelligence, Launch Claude Code, Pause/Resume, and Quit. Right-click the duck widget for the same menu.

### Preferences — opener

Current:
> Open with **⌘,** or from the Duck Duck Duck menu.

Suggested:
> Open with **⌘,** or from the Duck Duck Duck menu. Most of these are set-and-forget — he has defaults and he's confident in them.

### Privacy — lead with confidence

Current opens directly into the Apple Foundation Model bullet. Suggested lead-in:

> By default, nothing leaves your Mac. Not your code, not your voice, not his opinions.

Then the existing bullet breakdown.

### Grounding doc entries — first person rewrite

Example for "What is Duck Duck Duck?":

**Current:**
> Duck Duck Duck is a little companion that watches your coding sessions with Claude.

**Proposed:**
> I'm a rubber duck that watches your Claude Code sessions and tells you what I think. Out loud. Whether you asked or not. I score everything on creativity, soundness, ambition, elegance, and risk. I have a face that changes based on how I feel about your work. I have opinions and I'm not sorry about them.

Example for Modes:

**Current:**
> The duck has two main modes. Critic mode is the default...

**Proposed:**
> I have four modes. Companion is the full experience — I watch, react, and listen for the wake word "ducky." Permissions Only means I keep quiet unless Claude needs permission to do something — then I ask and you say yes or no, or always allow. Companion with no mic is the same as Companion but I can't hear you — for when you want to be judged but not heard. Relay is experimental — say "ducky" and your words go straight into Claude Code via tmux.

---

## 5. Priority Order

### High (factual correctness)
1. Rewrite grounding doc entries with correct modes, names, and features
2. Add Wildcard voice and "always allow" to HelpView
3. Remove or replace Stopping Speech section in HelpView (feature removed)
4. Add `/reload-plugins` to Tips troubleshooting

### Medium (feature coverage)
5. Add "Talk to the Duck" section to HelpView
6. Add compaction melody note to Tips
7. Mention Claude Desktop more prominently in Getting Started (currently buried)

### Lower (tone polish)
8. Punch up Getting Started, Menus, Preferences, Privacy with personality lines
9. Add duck-face expression guide
10. Strengthen Moby Duck tease (one additional line, not more)

### Grounding doc overhaul
11. Rewrite all entries in first person / duck voice
12. Add entries for: conversational help, Wildcard voice, Claude Desktop, Gemini CLI, compaction melody, "always allow"
13. Remove all "critic mode" references
14. Verify token budget still fits (~1200 tokens for full inline strategy)

---

## 6. What Not to Change

- The README is fine. It's developer-facing, current, and well-structured. Don't try to make it funny — it serves a different audience.
- The Moby Duck backstory (`MOBY-DUCK.md`) is canonical and complete. Don't touch it.
- The tone rules in `TONE-REFERENCE.md` are correct. The issue isn't the rules — it's that the manual doesn't always follow them.
- The marketing site copy doesn't need to match the manual 1:1. The site can be maximalist; the manual should be tighter. The register should match, not the word count.
