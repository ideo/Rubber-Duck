# Bambu Duck — firmware build scripts

Self-contained tooling for generating the chip's embedded audio
phrases from text. Designed to be runnable by anyone who clones the
repo (including future Claude Code sessions).

## What's here

### `gen_phrases.py`

Generates the spoken onboarding phrases that the chip plays during
the wizard flow (issue #34). Reads phrase texts from the script's
`PHRASES` dict, calls ElevenLabs' standalone TTS endpoint to
synthesize each, transcodes to chip-friendly Ogg-Opus via ffmpeg,
and writes the binary blobs to `bambu/firmware/main/phrases/<name>.opus`.

The chip embeds those blobs at build time (see
`bambu/firmware/main/CMakeLists.txt`'s `EMBED_FILES` block) and
decodes them at runtime via `phrases.c`.

Texts also get written as plain-text `<name>.txt` sidecars for
grep-friendly review without binary diffs in PRs.

#### When to run

- After editing the `PHRASES` dict to change wording
- After changing `VOICE_ID` to swap voices
- After deleting a `.opus` (re-generation is otherwise idempotent —
  re-runs skip phrases whose blob already exists)

#### Prerequisites

1. **ElevenLabs API key** with `text_to_speech` permission:
   - Generate at https://elevenlabs.io/app → Profile → API Keys
   - Make sure `text_to_speech` is enabled (the conversational AI
     scope alone won't work for the standalone TTS endpoint)
   - Either export as `ELEVENLABS_API_KEY` in your shell, or drop
     into `bambu/relay/.env` (the script auto-loads that file)
2. **ffmpeg with libopus**:
   ```
   brew install ffmpeg     # macOS
   apt install ffmpeg      # Debian/Ubuntu
   ```
   Verify: `ffmpeg -codecs | grep libopus` should list it.

#### How to run

```
cd bambu/firmware
python3 scripts/gen_phrases.py
```

Output:
```
  gen   tap_to_start   -> OK (14640 bytes)
  gen   wifi_up        -> OK (11741 bytes)

Generated: 2  Skipped: 0  Total: 26,381 bytes (25.8 KB)
```

#### How to add a new phrase

1. Pick a stable identifier (lowercase, snake_case): e.g. `whisper_hint`.
2. Add the text to the `PHRASES` dict in `gen_phrases.py`.
3. Run `python3 scripts/gen_phrases.py` to generate the .opus.
4. In `bambu/firmware/main/CMakeLists.txt`, add `phrases/whisper_hint.opus`
   to the `PHRASE_FILES` list.
5. In `bambu/firmware/main/phrases.h`, add `PHRASE_WHISPER_HINT` to the
   enum (before `PHRASE_COUNT`).
6. In `bambu/firmware/main/phrases.c`:
   - Add the `extern const uint8_t _binary_whisper_hint_opus_start[]`
     and `_end[]` decls.
   - Add an entry in the `s_blobs[]` table.
7. Trigger it from wherever in the firmware logic with
   `phrase_play(PHRASE_WHISPER_HINT)`.

The CMake build's `HAS_PHRASES` check is automatic — if any of the
listed `.opus` files is missing, the phrases module is skipped from
the build entirely (the `phrase_play` function becomes a no-op stub
via `phrases.h`'s `#else` block). So a fresh checkout that hasn't
generated the .opus yet still builds cleanly; phrases just don't
play until you run the script.

#### How to swap voices

Edit `VOICE_ID` in the script. Voice IDs come from ElevenLabs'
voice library — browse at https://elevenlabs.io/app/voices.

For consistency, the spoken-onboarding voice should match the
voice configured in `bambu/elevenlabs/agent-template.json` (the
conversational agent's voice). Otherwise the duck sounds like one
character during onboarding and a different character during
conversation. The default in this repo matches.

To change the voice across the project:
1. Pick a new voice ID.
2. Update `gen_phrases.py`'s `VOICE_ID`.
3. Update `bambu/elevenlabs/agent-template.json`'s
   `conversation_config.tts.voice_id`.
4. Re-run `gen_phrases.py` to regenerate phrases with the new voice.
5. If you've already created an ElevenLabs agent from the template,
   either recreate it or PATCH it via the API to use the new voice.

#### Voice settings

Match the conversational agent's `stability` and `similarity_boost`
so the offline TTS sounds like the live agent. The script uses the
same values that ship in `agent-template.json`. If you tweak one,
update both.

#### TTS model choice

The script uses `eleven_turbo_v2_5` for the standalone TTS endpoint.
Don't use `eleven_v3_conversational` here — that model is only
valid via the agent's WebSocket session path, the standalone
endpoint will reject it.

`turbo_v2_5` is fast (low TTFB), high quality, and produces audio
that round-trips through Opus 24 kbps voip cleanly.

#### Idempotency / re-running

By default the script skips phrases whose `.opus` already exists.
To regenerate one phrase:
```
rm bambu/firmware/main/phrases/<name>.opus
python3 scripts/gen_phrases.py
```

To regenerate all:
```
rm bambu/firmware/main/phrases/*.opus
python3 scripts/gen_phrases.py
```

The `.txt` sidecars are always rewritten on each run so they stay
in sync with the `PHRASES` dict regardless of the .opus state.
