# Onboarding Feedback — 2026-03-23 (Jenna's session)

First external install. Plugin worked on CLI immediately but Desktop hooks didn't fire until Claude was updated twice. Here's everything we learned.

---

## 1. Minimum Claude version

**Finding:** Hooks didn't fire on Claude Desktop until updated to **1.1.7714 (3bd6f6)** or newer. The plugin was visible in Desktop's "manage plugins" UI — hooks listed — but they simply didn't execute. Two updates fixed it.

**Action:** Document minimum version in install flow + helpdesk prompt. If we can detect version, warn the user.

---

## 2. Desktop-only users (no CLI)

Jenna had Claude Desktop but **no CLI**. Our install flow assumes CLI (`claude plugin marketplace add ...`).

**Problem:** The plugin system shares the same storage location for both Desktop and CLI. In theory we could install without CLI, but our current path requires it.

**Ideas:**
- **Zip upload for Desktop**: The Desktop UI has "Upload local plugin" (drag & drop zip). We need a pre-built `.zip` ready at all times (in GitHub releases or the app itself).
- **Detect which app is installed**: Check for Desktop vs CLI presence and branch the install instructions accordingly.
- **Can we detect version?** If so, warn about minimum version.
- **Alternative install button**: "Install via Desktop (drag this zip)" alongside "Install via CLI".
- A folder with instructions + screenshots showing how to navigate Desktop to the upload button.
- Ideally the widget's "Install Claude Plugin" can handle both paths — detect what's available and do the right thing.

---

## 3. CLI install is gnarly for non-developers

The CLI install requires two steps:
```bash
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

**Problems:**
- Normal humans don't know what this means
- The PATH export is a second step that's easy to miss
- Finding the installer URL is hard

**Ideas:**
- Widget could run both commands together (or pre-add PATH before triggering the install)
- Open Terminal.app for the user so they can watch the install
- Sandbox-friendly version: alert with a "Launch Terminal" button + copy/paste instructions
- A general-purpose "Terminal Helper" feature in the duck — show an alert with copyable terminal commands. Useful for CLI install, plugin install, debugging, etc.

---

## 4. Wildcard voice — slow voices on long text

**Problem:** Voices like "Good News", "Jester" are dramatically slow. When the summary text is long, they take forever.

**Fix:** If character count exceeds a threshold, fall back to a fast voice (e.g., Superstar). Define a `maxCharactersForSlowVoice` constant. Slow voices = Good News, Jester, Bahh, Wobble, Bubbles. Fast voices = Superstar, Trinoids, Zarvox, Cellos.

---

## 5. Reactions too long — paragraph when it should be a sentence

**Problem:** The duck sometimes speaks an entire paragraph. The summary is often shorter than the reaction comment. Should ALWAYS be one sentence.

**Fix:** Tighten the eval prompt — enforce "max 1 sentence" for reactions, "max 1 sentence" for summaries. The summary should be the longer one (it's the relay to the user), but even that should cap at ~15 words spoken.

---

## 6. Wake word head tilt too subtle (FIRMWARE) ✅ FIXED

**Problem:** S3 firmware only tilted 15° on wake word — barely noticeable. Teensy didn't handle `W,1` at all.

**Fix applied:**
- S3: `SERVO_CENTER + 15` → `SERVO_CENTER + 45` (big dramatic head cock)
- Teensy: Added `W,1`/`W,0` handler with same 45° tilt (was completely missing)
- No chirp on wake — just the physical tilt while it says "Yeah?" etc.

---

## 7. LLM helpdesk prompt — add team info

**Current state:** `DuckHelpService.swift` has a solid system prompt covering modes, install, troubleshooting. But NO team info. "Built at IDEO" only appears in `HelpView.swift` UI.

**Add to prompt:**
```
Duck Duck Duck was built at IDEO by some mighty ducks:
- Andy Deakin
- Andy Reischling
- Danny DeRuntz
- Dave Vondle
- Jack Boland
- James Smalls
- Jason Robinson
- Jenna Fizel — makes stuff with robots
- Shelby Guergis
- Tomoya Mori
```

Also add: minimum Claude version note, Desktop zip upload path, the gnarly CLI install steps (so the duck can walk people through it).

---

## Priority

1. **Version warning** — helpdesk prompt + install flow (prevents the #1 support issue)
2. **Desktop zip install path** — unblocks non-CLI users
3. **Reaction length cap** — quick prompt tweak, big UX improvement
4. **Slow voice fallback** — quick code fix
5. **Wake word visual tilt** — needs design exploration (glass constraint)
6. **CLI install helper** — nice to have, sandbox-tricky
7. **Team info in prompt** — nice to have
