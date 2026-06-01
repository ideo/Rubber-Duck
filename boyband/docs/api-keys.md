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
read -rsp "Anthropic API key: " KEY; echo
security add-generic-password \
  -s com.duckduckduck.boyband.anthropic \
  -a "$USER" \
  -w "$KEY" \
  -U
unset KEY
```

Repeat for `elevenlabs` and (optionally) `openai`.

ElevenLabs example:

```sh
read -rsp "ElevenLabs API key: " KEY; echo
security add-generic-password \
  -s com.duckduckduck.boyband.elevenlabs \
  -a "$USER" \
  -w "$KEY" \
  -U
unset KEY
```

Verify without printing the key:

```sh
security find-generic-password \
  -s com.duckduckduck.boyband.elevenlabs \
  -a "$USER" \
  -w >/dev/null && echo "ElevenLabs key: ok"
```

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

Some older helper scripts still check `ELEVENLABS_API_KEY` in the shell
environment or `bambu/relay/.env`. Prefer a temporary shell export for those
scripts:

```sh
export ELEVENLABS_API_KEY="$(security find-generic-password \
  -s com.duckduckduck.boyband.elevenlabs \
  -a "$USER" \
  -w)"
```

Do not commit `.env.local` or `bambu/relay/.env`, and do not use either file
as the human handoff mechanism.

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
