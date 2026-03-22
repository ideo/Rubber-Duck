# Onboarding Test Report — Phase 1 (GitHub Release Path)

**Date:** 2026-03-22
**Tester:** Daniel
**Build:** DMG from GitHub Releases (v8.1)
**Method:** Fresh install simulation — deleted app data, reset TCC permissions, installed from DMG

---

## Test Flow

### 1. DMG Download & Launch
- **Result:** ✅ Works
- Apple checked for malicious software, said none found. No Gatekeeper block.
- Duck appears in menu bar immediately.

### 2. First Launch Experience
- **Result:** ❌ No greeting. Silent.
- Duck appears but says nothing. "Now what?" moment.
- Right-click menu appears normal. Voices work, device auto-detected.
- **Gap:** No guidance on what to do next. No mention of Claude or plugin.

### 3. Plugin Install
- **Result:** ✅ Works (via menu, not right-click)
- Right-click has no "Install Plugin" — only "Launch CLI". Not discoverable from duck face.
- Used main status bar menu to install. Launched Claude, hooks loaded, session greeting fired.
- Modal alert confirmed install, but duck said nothing. Missed voice feedback moment.
- **Gap:** Install Plugin not in right-click menu. No voice confirmation of install.

### 4. Plugin Works in Desktop App Too
- **Result:** ✅
- Plugin loaded into already-active Claude Desktop session without restart.
- No `/reload-plugins` needed — picked up automatically.

### 5. Mic Permissions
- **Result:** ❌ → ✅ (after fix)
- Initial DMG install: no mic permission dialog appeared. Speech recognition dialog showed but not microphone.
- Root cause: DMG release build was missing `NSMicrophoneUsageDescription` in Info.plist.
- Fix: Added mic usage description to Info.plist, rebuilt DMG.
- After fix: both dialogs appear in correct order (mic first, then speech recognition).
- **Blocker until fixed.** Without mic, voice permissions don't work.

### 6. Voice Permissions
- **Result:** ✅
- Permission requests come through, duck speaks the prompt.
- "Yes" approves correctly.
- "Always allow" works correctly.
- Format: "Edit SpeechService. Allow or deny?" — concise, clear.

### 7. Wildcard Voice Mode
- **Result:** ✅ Working
- Score-gated V2 voice selection active and picking appropriate voices.

---

## Key Findings

### Blockers (must fix before sharing)
1. **No first-launch greeting or guidance** — user has no idea what to do after opening the app
2. **Mic permission missing from DMG** — fixed in code, needs new release

### UX Gaps
3. **"Install Plugin" not in right-click menu** — only in status bar menu, hard to discover
4. **No voice feedback on plugin install** — modal alert only, duck stays silent
5. **No eval history / log reliability** — can't review what the duck said. Dashboard shows live state only, log file stops capturing eval reactions intermittently.
6. **Foundation eval tone** — model is oddly mean about user messages, obsessed with "typos", meaner than Haiku. Needs prompt tuning.

### Working Well
- DMG install is smooth, no Gatekeeper issues
- Plugin works in both CLI and Desktop without restart
- Voice permissions flow is solid
- Always allow works
- Wildcard voice selection (V2 score-gated) picks well
- Device auto-detection works
- **All voice previews work as expected** — each voice plays its character line correctly from the right-click menu

---

## Additional Findings

### Relay Mode
- If no Claude CLI session is open, does nothing. No feedback or error.
- **Launch CLI is broken** — command `cd`s to root `/` via path traversal, tmux fails with "no server running". Non-functional for new users.

### Microphone / Mode Matrix
- Mic settings are confusing. Too many combinations.
- **Mic off** → only useful in Companion mode without voice permissions. Still helpful (visual reactions, eval scores).
- **Permissions Only** → strong standalone mode. Voice permissions work well.
- **Wake Word** → adds help/voice commands to Companion or even Permissions Only mode.
- Key insight: modes and mic settings overlap in confusing ways. Needs simplification or better explanation of what each combination does.

### Mode Observations
- Relay mode requires Claude CLI + tmux — power user only, not onboarding-friendly.
- Companion mode + permissions is the sweet spot for most users.
- Wake word for "help" features is useful across modes.

