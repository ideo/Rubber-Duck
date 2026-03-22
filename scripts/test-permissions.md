# Permission System Test Script

Run this in a fresh Claude Code session with the widget running.
Paste the entire script as your first prompt.

---

## Instructions for Claude

You are running a permissions test. Follow each step exactly. After each step,
wait for the permission to resolve before moving to the next. Report what the
duck said (check `/tmp/rubber-duck-permission.log` after each step) and whether
the response matched expectations.

Do NOT batch steps. Do one at a time, report the result, then continue.

---

## Test 1: Bash with description field

Run this command. The duck should speak the description, not the raw command.

```
ls -la /tmp
```

**Expected duck prompt:** Something like "List files. Allow?" (uses the Bash
tool's `description` field from Claude Code, or falls back to "List files").

**Voice response to test:** Say "yes"

---

## Test 2: Edit tool summary

Edit any file — add a blank comment to the top of `scripts/on-permission-request.sh`,
then remove it.

**Expected duck prompt:** "Edit on-permission-request. Allow?" (extracts filename)

**Voice response to test:** Say "go ahead" (tests affirmative phrase matching)

---

## Test 3: Write tool summary

Create a temporary file: write "test" to `/tmp/duck-permission-test.txt`, then
delete it.

**Expected duck prompt:** "Write duck-permission-test. Allow?" (extracts filename
from Write tool)

**Voice response to test:** Say "sure"

---

## Test 4: Deny flow

Run `echo "this should be denied"`.

**Expected duck prompt:** "Run a command. Allow?"

**Voice response to test:** Say "no" — confirm the duck says something like
"Blocked it" or "Denied" and Claude reports the denial.

---

## Test 5: Always-allow suggestion

Run `cat /dev/null`. When prompted, the duck should offer an "always allow"
option.

**Expected duck prompt:** Something like "Read a file. Allow? Or say always
allow to allow Bash for this session."

**Voice response to test:** Say "always allow" — confirm the duck says
"Got it. Allow bash for this session." (or similar label confirmation)

---

## Test 6: Repeat flow

Edit `widget/Sources/RubberDuckWidget/DuckConfig.swift` — add then remove a
blank line.

**Voice response to test:** Say "what?" or "repeat" — confirm the duck
re-speaks the full prompt with option descriptions. Then say "yes" to proceed.

---

## Test 7: Ambiguous input (Foundation Models classifier)

Run `date`. When the duck asks permission:

**Voice response to test:** Say "uh, I guess so" or "yeah go for it buddy"
(something that isn't an exact keyword match).

**Expected behavior:** Word matcher returns `.noMatch` → Foundation Models
classifier kicks in → classifies as allow → duck says "Got it" or similar.

Check the log for `[classifier]` entries to confirm the LLM was invoked.

---

## Test 8: Internal tool (plan mode)

Enter plan mode by saying you want to plan something. The duck should get a
permission for EnterPlanMode.

**Expected duck prompt:** "Claude wants to enter plan mode. Allow?" (friendly
name, not raw "EnterPlanMode")

**Voice response to test:** Say "yes"

Then exit plan mode. Confirm the duck says "Claude wants to exit plan mode.
Allow?"

---

## Test 9: Multiple options

Trigger a permission that has 3+ suggestion options. Run something like
`swift build` in the widget directory (if not already always-allowed).

**Expected duck prompt:** Should end with "You have X options. Say repeat for
details." (not enumerate all options inline)

**Voice response to test:** Say "repeat" to hear all options, then say "second"
or "two" to pick the second option.

---

## Checklist

After all tests, report:

- [ ] Bash description field used when available
- [ ] Edit/Write/Read extract filename correctly
- [ ] Internal tools use friendly names
- [ ] "yes"/"no" and natural phrases work (go ahead, sure, nope)
- [ ] "always allow" selects the correct suggestion
- [ ] "repeat" re-speaks with full option descriptions
- [ ] Ambiguous input triggers Foundation Models classifier
- [ ] Classifier log entries visible in DuckDuckDuck.log
- [ ] Deny flow works end-to-end
- [ ] Option label spoken in confirmation (not "option 1")
