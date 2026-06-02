# 2026-06-02 Tonight's Changes

This captures the late-night state after moving the boy-band rig from
"two ducks sometimes fail over WiFi" to "two plugged-in ducks can run the full
show, then video, then live Q&A."

## Current Working Rig

Stage runs locally on the operator Mac at `http://localhost:3334`.

Current two-duck command:

```sh
cd /Users/jfizel/Rubber-Duck/boyband/stage
swift run BoyBandStage --port 3334 \
  --usb-map ../duck-usb-map.local.json \
  --transport usb \
  --turn-manifest '/Users/jfizel/Duck Tales/outputs/eleven-20260601-five-minutes-to-curtain/five-minutes-to-curtain_manifest.json' \
  --duck-alias D3=D1 --duck-alias D4=D2
```

Current two-duck physical mapping:

| Logical slot | Character | Physical duck | USB device seen tonight | USB serial |
|---|---|---|---|---|
| `D1` | Classic | Mallard | `/dev/cu.usbmodem1101` | `DC:B4:D9:29:61:E8` |
| `D2` | Mallard | Pekin | `/dev/cu.usbmodem101` | `DC:B4:D9:29:61:24` |
| `D3` | Pintail | Aliased to `D1` | Same as `D1` | Same as `D1` |
| `D4` | Pekin | Aliased to `D2` | Same as `D2` | Same as `D2` |

The stable assignment lives in `boyband/duck-usb-map.local.json`, which is
gitignored. The macOS `/dev/cu.usbmodem*` path can move around; the USB serial
is the identity to trust.

## Reliability Change: USB Audio Transport

We stopped relying on WiFi/WebSocket audio for show playback and moved the
real ducks to USB Serial/JTAG transport.

Why:

- Over WiFi, the ducks repeatedly developed delayed, garbled, or stuttering
  audio during longer playthroughs.
- `/status` pointed at transport backlog and late delivery rather than an
  isolated bad audio file or one bad duck.
- Both Mallard and Pekin failed at different times, so the problem was
  systemic.
- Since the show ducks will be plugged in anyway, USB is a better primary
  stage path.

What changed:

- `boyband/stage/Sources/BoyBandStage/USBSerialDuck.swift` implements the
  wired duck transport.
- `boyband/stage/Sources/BoyBandStage/main.swift` accepts `--usb-map`,
  `--transport usb`, and `--duck-alias`.
- `boyband/docs/duck-id-mapping.md` documents the USB assignment format.

Validated result:

- Both plugged-in ducks completed a full scripted run over USB.
- Recovery/reconnect behavior is still useful, but the main goal is now to
  avoid the WiFi failure mode entirely during show playback.

## Turn-By-Turn Script Playback

The current show script is generated as line clips plus a manifest rather than
one giant continuous stream.

Stage now supports:

- `--turn-manifest FILE`: load the generated manifest from
  `gen-play-stems.py`.
- `/play`: play the script one utterance at a time.
- `/state`: expose current line, speaker, cue index, elapsed time, and turn
  list.
- `/visualizer`: operator view with playback progress and jump-to-line.
- `/subtitles`: clean projected subtitles for the scripted play.

The two-duck setup uses aliases so all four character lines can still run:

```sh
--duck-alias D3=D1 --duck-alias D4=D2
```

When four physical ducks are available, remove those aliases.

## Visualizer Updates

`/visualizer` became the operator test surface.

Useful changes:

- Displays cue progress and duck health while playback runs.
- Resets correctly between files/runs.
- Has a jump-to-line dropdown with a short preview of each line.
- Can trigger `/play`, but remember this sends real audio to the ducks.

## Subtitles

`/subtitles` shows the current scripted line as large centered text.

Speaker colors:

| Speaker | Background | Text |
|---|---|---|
| Pintail | `#2A2824` | white |
| Classic | `#ECEA6E` | black |
| Mallard | `#527F16` | white |
| Pekin | `#EFEFEF` | black |

Subtitles are paced by estimated chunk timing from the current cue duration.
They hold the last spoken text through gaps instead of flashing `Ready`.

## Live Q&A

`/qa` is a minimal audience-question interface.

Input mode:

- Orange background `#E69F24`.
- Large auto-growing question field.
- Icon-only mic and send buttons below the input.
- Designed so the operator can mostly use voice input.

Keyboard bindings:

| Key | Action |
|---|---|
| `Space` | Start listening when the page is in input mode and the text field is not active |
| `Enter` | Send question from the text field |
| `Shift+Enter` | Newline in the text field |
| `Cmd+Enter` / `Ctrl+Enter` | Send question |
| `Esc` | Clear input or return from answer mode |
| `/` | Focus the question field |

Answer mode:

- Shows subtitles using the same speaker color system.
- Uses estimated text pacing from the generated answer line duration.
- Returns to ask mode about `300 ms` after the final responding duck finishes.
- Clears the previous question after the response.

Q&A generation lives in `boyband/scripts/qa-eleven.py`.

The helper does two things:

1. Uses an ElevenLabs ConvAI agent to write a short response script.
2. Uses ElevenLabs TTS to render each response line as 16 kHz PCM WAV.

The agent chooses the most relevant one or two ducks; it is not forced to make
everyone answer. The prompt also tells it not to speak routing IDs like `D1` or
`D3`, and the script sanitizes accidental spoken ID leakage before TTS.

## Show Mode

`/show` ties the whole public flow together:

1. Start screen with one arrow button.
2. Click starts the scripted duck play via `/play`.
3. The page displays subtitles during the scripted play.
4. After the final script line, it plays the handoff video full screen.
5. After the video ends, it switches to the Q&A input interface.

Current video path in code:

```text
/Users/jfizel/Downloads/ok_now_let_s_try_the_video_on.mp4
```

Served route:

```text
/handoff-video.mp4
```

Late polish fixes:

- Removed the `Ready` flash between show subtitles.
- Hid the lower-corner `Ask` button while `/show` subtitles are visible.
- Gated the video transition so it only starts after the final script line has
  actually been observed playing.

## Files Changed Tonight

Important code paths:

- `boyband/stage/Sources/BoyBandStage/main.swift`
- `boyband/stage/Sources/BoyBandStage/StageServer.swift`
- `boyband/stage/Sources/BoyBandStage/USBSerialDuck.swift`
- `boyband/scripts/qa-eleven.py`
- `.gitignore`

Important gitignored local state:

- `boyband/duck-usb-map.local.json`
- `boyband/qa-agent.local.json`
- `boyband/qa-cache/`
- `boyband/.venv/`

## Quick Health Checks

Check that the server is up and both ducks are connected:

```sh
curl -sS http://localhost:3334/status
```

Expected top line for the current two-duck setup:

```text
connected: D1,D2
```

Check current playback state:

```sh
curl -sS http://localhost:3334/state | python3 -m json.tool | sed -n '1,40p'
```

Check USB devices are present:

```sh
ls /dev/cu.usbmodem* 2>/dev/null || true
```

Build Stage:

```sh
cd /Users/jfizel/Rubber-Duck/boyband/stage
swift build
```

Known current caveat: `swift build` passes but prints Swift sendability
warnings in `main.swift`.
