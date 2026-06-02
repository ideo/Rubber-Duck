# Updating Script and Q&A Content

This is the practical path for replacing the scripted play and refreshing the
live Q&A agent with new material.

## Prerequisites

ElevenLabs is required for both scripted line rendering and Q&A. The preferred
place for the key is macOS Keychain:

```sh
security find-generic-password \
  -s com.duckduckduck.boyband.elevenlabs \
  -a "$USER" \
  -w >/dev/null && echo "ElevenLabs key: ok"
```

The current Python helper environment is:

```sh
cd /Users/jfizel/Rubber-Duck/boyband
.venv/bin/python -m py_compile scripts/qa-eleven.py
```

If the venv is missing, recreate it and install the helper dependencies:

```sh
cd /Users/jfizel/Rubber-Duck/boyband
python3 -m venv .venv
.venv/bin/python -m pip install httpx websockets
```

## Updating the Scripted Play

### 1. Prepare speaker-tagged Markdown

`boyband/scripts/gen-play-stems.py` expects lines in this format:

```md
**CLASSIC:** Five minutes. Deep breaths. Big smiles.
**MALLARD:** Nobody knows who we are.
**PEKIN:** We should explain it simply.
**PINTAIL:** Impossible. We are an interface, not a brochure.
```

Rules:

- Speaker names must be uppercase: `CLASSIC`, `MALLARD`, `PINTAIL`, `PEKIN`.
- The speaker label must be bold and followed by a colon.
- Non-dialogue lines are ignored.
- The script maps speakers to ducks as:
  - `CLASSIC` -> `D1`
  - `MALLARD` -> `D2`
  - `PINTAIL` -> `D3`
  - `PEKIN` -> `D4`

If the source is a Google Doc, export or copy it into a local Markdown file
that preserves those labels. Put generated or working drafts outside git if
they are still messy, for example under `/Users/jfizel/Duck Tales/`.

### 2. Dry-run the parser

```sh
cd /Users/jfizel/Rubber-Duck
boyband/.venv/bin/python boyband/scripts/gen-play-stems.py \
  '/Users/jfizel/Duck Tales/scripts/new-play.md' \
  --out-dir '/Users/jfizel/Duck Tales/outputs/new-play' \
  --dry-run
```

Confirm that it finds the expected number of lines and that each character has
a plausible line count.

### 3. Generate ElevenLabs line clips and manifest

```sh
cd /Users/jfizel/Rubber-Duck
boyband/.venv/bin/python boyband/scripts/gen-play-stems.py \
  '/Users/jfizel/Duck Tales/scripts/new-play.md' \
  --out-dir '/Users/jfizel/Duck Tales/outputs/new-play' \
  --prefix new-play
```

The output directory will contain:

- `line-clips/`: one WAV per spoken line.
- `new-play_manifest.json`: the file Stage uses for turn-by-turn playback.
- `new-play_D1_classic.wav`, etc.: aligned full stems, useful for inspection
  or alternate playback modes.

The manifest is the important file for the current `/show` flow.

### 4. Start Stage with the new manifest

For the current two-duck setup:

```sh
cd /Users/jfizel/Rubber-Duck/boyband/stage
swift run BoyBandStage --port 3334 \
  --usb-map ../duck-usb-map.local.json \
  --transport usb \
  --turn-manifest '/Users/jfizel/Duck Tales/outputs/new-play/new-play_manifest.json' \
  --duck-alias D3=D1 --duck-alias D4=D2
```

For four physical ducks, remove the aliases:

```sh
cd /Users/jfizel/Rubber-Duck/boyband/stage
swift run BoyBandStage --port 3334 \
  --usb-map ../duck-usb-map.local.json \
  --transport usb \
  --turn-manifest '/Users/jfizel/Duck Tales/outputs/new-play/new-play_manifest.json'
```

### 5. Inspect before making noise

Open:

- `http://localhost:3334/visualizer`
- `http://localhost:3334/subtitles`
- `http://localhost:3334/show`

Check state without triggering playback:

```sh
curl -sS http://localhost:3334/state | python3 -m json.tool | sed -n '1,80p'
curl -sS http://localhost:3334/status
```

Only click Play/Start when the room is ready for the ducks to speak.

## Tuning Duck Volume

Stage applies a global volume multiplier and per-duck balance multipliers to
each outgoing PCM chunk. The current startup balance defaults compensate for
the June 2 ElevenLabs voices:

```text
D1 Classic  0.56x
D2 Mallard  1.24x
D3 Pintail  0.78x
D4 Pekin    2.47x
```

To override the startup balance defaults, restart Stage with repeatable
`--duck-gain` flags:

```sh
swift run BoyBandStage --port 3334 \
  --usb-map ../duck-usb-map.local.json \
  --transport usb \
  --turn-manifest '/Users/jfizel/Duck Tales/outputs/new-play/new-play_manifest.json' \
  --duck-gain D2=1.6 \
  --duck-gain D4=3.0
```

You can tune both layers live in `http://localhost:3334/visualizer`:

- Global volume calls `/gain?global=1.25`.
- Duck balance calls `/gain?duck=D3&value=0.82`.

Both affect outgoing audio chunks immediately. They do not rewrite source clips
or change firmware volume. `--duck-gain` sets only the per-duck startup balance
defaults for the next Stage launch; live global volume starts at `1.00x`.

`--duck-gain ALL=1.1` is also supported. Use it carefully: Classic's current
script clips already peak near full scale, so large effective gains can sound
crunchy. These defaults assume ducks are flashed with USB boy-band firmware at
`VOL_STEP=0` (Loud); if they are flashed quieter, raise the multipliers.

## Updating the Handoff Video

`/show` currently serves a hardcoded local file from
`StageServer.swift`:

```swift
private static let handoffVideoPath = "/Users/jfizel/Downloads/ok_now_let_s_try_the_video_on.mp4"
```

To use a new video:

1. Put the video somewhere stable on the operator Mac.
2. Update `handoffVideoPath`.
3. Build and restart Stage.
4. Verify the route:

```sh
curl -I http://localhost:3334/handoff-video.mp4
```

Expected: `200 OK` and `Content-Type: video/mp4`.

## Updating Q&A Grounding and Personas

The Q&A helper is:

```text
boyband/scripts/qa-eleven.py
```

The main sections to edit are:

- `DUCKS`: character names, voice IDs, and routing/persona descriptions.
- `GROUNDING`: project facts, theory, references, and the routing guide.
- `agent_prompt()`: global behavior rules for the live answer writer.
- `sanitize_spoken_text()`: cleanup for things the ducks must not say out loud.
- `PROMPT_VERSION`: cache-busting version string for the ElevenLabs agent.

Important: when the prompt, grounding, personas, or routing change, bump
`PROMPT_VERSION`. Otherwise `load_agent_id()` may reuse the old cached agent in
`boyband/qa-agent.local.json`.

Example:

```python
PROMPT_VERSION = "2026-06-03-new-grounding-v1"
```

Then either let the helper create a new agent automatically, or delete the old
cache explicitly:

```sh
rm /Users/jfizel/Rubber-Duck/boyband/qa-agent.local.json
```

`qa-agent.local.json` is gitignored and should stay local.

## Testing the Q&A Agent Without the Web UI

Run the helper directly:

```sh
cd /Users/jfizel/Rubber-Duck
boyband/.venv/bin/python boyband/scripts/qa-eleven.py \
  "Why are these ducks a boy band?"
```

The output is JSON like:

```json
{
  "question": "Why are these ducks a boy band?",
  "agent_id": "...",
  "lines": [
    {
      "duck": "D1",
      "speaker": "Classic",
      "text": "The boy-band frame makes our archetypes instantly legible.",
      "path": "/Users/jfizel/Rubber-Duck/boyband/qa-cache/...",
      "duration_sec": 3.2
    }
  ]
}
```

Check for:

- One or two response lines total.
- Relevant duck choice.
- No spoken `D1`, `D2`, `D3`, `D4`, "dee one", etc.
- No markdown, stage directions, or speaker labels in `text`.
- Reasonable duration for live Q&A.

The direct helper test renders audio files into `boyband/qa-cache/`, but it
does not play them through the ducks.

## Testing Q&A Through Stage

Start Stage with the current manifest and USB map, then open:

```text
http://localhost:3334/qa
```

Or trigger via HTTP:

```sh
curl -sS --get http://localhost:3334/qa/ask \
  --data-urlencode 'question=Why are the ducks physical?'
```

That route does generate and play duck audio when Stage is running with real
ducks connected, so use it only when speaking is acceptable.

## Updating Voice IDs

Both scripts currently share the same voice IDs:

| Duck | Character | Voice ID |
|---|---|---|
| `D1` | Classic | `ygoBNrnmTEdu5NtDTmAY` |
| `D2` | Mallard | `U5UjeJMsOvyhYhXfZdvZ` |
| `D3` | Pintail | `TX3LPaxmHKxFdv7VOQHJ` |
| `D4` | Pekin | `Xb3zeLrTi6F4ziIcXdwk` |

For scripted play, edit `DEFAULT_VOICES` in `gen-play-stems.py` or pass
overrides:

```sh
--voice D1=<voice_id> --voice D2=<voice_id>
```

For live Q&A, edit the `voice` field inside `DUCKS` in `qa-eleven.py`, bump
`PROMPT_VERSION`, and regenerate the cached agent.

List available voices:

```sh
cd /Users/jfizel/Rubber-Duck
boyband/.venv/bin/python boyband/scripts/gen-play-stems.py --list-voices
```

## Content Checklist

Before rehearsal:

- [ ] Script Markdown parses with the expected line count.
- [ ] Generated manifest path is passed to `--turn-manifest`.
- [ ] `/state` shows the first new line and the right total cue count.
- [ ] `/visualizer` jump-to-line previews look sane.
- [ ] `/subtitles` speaker colors match expected speakers.
- [ ] `/show` starts on the arrow screen, not the Q&A screen.
- [ ] New Q&A prompt has a bumped `PROMPT_VERSION`.
- [ ] Direct Q&A helper test returns one or two relevant duck lines.
- [ ] No real API keys are written to files.
- [ ] Four-duck runs do not use `--duck-alias`; two-duck rehearsal runs do.

## Common Failure Modes

| Symptom | Likely cause | Fix |
|---|---|---|
| Q&A uses old facts | `PROMPT_VERSION` was not bumped | Bump it and delete `qa-agent.local.json` |
| Agent says `D3` out loud | Prompt/sanitizer missed a case | Add a sanitizer case and retest directly |
| `/show` still plays old script | Stage was started with old manifest | Restart with the new `--turn-manifest` path |
| One physical duck speaks two characters | Expected in two-duck mode | Remove aliases only when four ducks are connected |
| `curl /status` shows one duck | USB device missing or Stage started before it appeared | Replug/wake duck, then restart Stage |
| TTS fails with missing key | ElevenLabs key not available | Add/verify Keychain item |
