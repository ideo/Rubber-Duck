# Boy Band — API keys

**Rule:** real keys never enter this repo. Not in code, not in
comments, not in example configs, not in `.env` files that are
"definitely gitignored." They live in the macOS Keychain on each
operator's Mac.

If you (AI assistant) are about to write a real key into a file —
stop. Ask the human to put it in Keychain instead.

## Keys we use

| Service | What for | Keychain item | Required by |
|---|---|---|---|
| Anthropic | Orchestrator LLM (Mode 2) | `com.duckduckduck.boyband.anthropic` | Stage app, Mode 2 |
| ElevenLabs | TTS for Modes 1+2, STT for Mode 2 | `com.duckduckduck.boyband.elevenlabs` | Stage app (Mode 2), pre-render scripts (Mode 1 authoring) |
| OpenAI *(optional fallback)* | Whisper STT if local Whisper.cpp underperforms | `com.duckduckduck.boyband.openai` | Mode 2 only, optional |

## Adding a key (one-time setup per Mac)

```sh
# Replace YOUR_KEY with the real value at the prompt
security add-generic-password \
  -s com.duckduckduck.boyband.anthropic \
  -a $USER \
  -w \
  -U
# (you'll be prompted for the secret; it won't echo)
```

Repeat for `elevenlabs` and (optionally) `openai`.

## How the Stage app reads them

Swift code uses the standard `SecItemCopyMatching` pattern with the
service name above. There's a tiny helper `KeychainKey.swift` to be
added in Week 1; treat it as the only place keys get read.

## Dev fallback

If you're iterating fast and Keychain access is annoying, the Stage
app also reads `boyband/.env.local` (gitignored — verify with
`git check-ignore boyband/.env.local` before you trust it):

```
ANTHROPIC_API_KEY=sk-ant-…
ELEVENLABS_API_KEY=…
```

Keychain wins if both are set.

## If a key is leaked

1. **Revoke immediately** in the provider's dashboard.
2. Rotate to a new key, update Keychain on both operators' Macs.
3. If the leak made it to git history, force-push is not sufficient
   — assume the key is compromised forever. Revocation is the only
   real fix.

## Pre-show key check

`docs/show-runbook.md` includes a "T-minus 1 hour" line item:
verify all three Keychain items resolve and have non-empty values.
Don't discover a missing key on stage.
