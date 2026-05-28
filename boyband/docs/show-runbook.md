# Show runbook

To be filled in during Week 4. Right now this is the skeleton so we
know what we'll need.

## Kit (pack list)

- [ ] Operator MacBook (Stage app installed, keys in Keychain,
      stems on local disk)
- [ ] Backup MacBook with same state
- [ ] 4 × Bambu Ducks (plus 1 spare)
- [ ] USB-C power for all 5 ducks + extension strip
- [ ] Travel WiFi router (we provide our own SSID, don't rely on
      venue WiFi)
- [ ] Wired XLR or USB mic for audience questions
- [ ] PTT switch (USB foot pedal preferred)
- [ ] Audio interface if PA needs line out from Mac (ducks are
      self-powered speakers, so this is for any musical bed in
      Mode 1)
- [ ] 4 × name cards / signage under each duck
- [ ] Printed cheat-sheet of hotkeys, taped to laptop
- [ ] Spare USB-C cables (×3)
- [ ] Gaff tape, sharpie, extension cord

## Hotkeys

| Key | Action |
|---|---|
| `Space` | DAW play/pause (Mode 1) |
| `Cmd+Shift+1` | Force Stage → Mode 1 (filler stems) |
| `Cmd+Shift+2` | Force Stage → Mode 2 (FAQ) |
| `Esc` or foot pedal | Interrupt all ducks |
| `1`–`4` | Mute/unmute D1–D4 |
| `M` | Master mute |

## T-minus checklist

### T-2 hours
- [ ] Set up travel router, SSID `BoyBandWifi`, password from
      `~/.boyband/wifi.local` (NOT committed)
- [ ] Power on all ducks, confirm they join the SSID and connect
      to Stage (`/health` endpoint shows 4 connected)
- [ ] Sound check: trigger sine on each duck individually, confirm
      audible and visible head wobble
- [ ] Mode 1 dry run: play 30 seconds of show stems through all
      four ducks
- [ ] Mode 2 dry run: ask one test question via PTT mic, listen
      to full panel response

### T-1 hour
- [ ] Verify Anthropic + ElevenLabs keys resolve from Keychain
      (Stage has a `Check keys` menu item that pings each
      provider with a 1-token request)
- [ ] Verify backup MacBook is ready and on the same WiFi
- [ ] Charge foot pedal (if wireless)
- [ ] Operator runs hotkeys drill: interrupt, mode flip, mute

### T-15 minutes
- [ ] All ducks silent, Stage in Mode 1 with filler queued
- [ ] PTT mic muted at the board
- [ ] Operator confirms cheat sheet visible

## In-show failure response

| Symptom | First action | If that fails |
|---|---|---|
| One duck silent | Press its number key to confirm not muted; check duck's WiFi LED | Mute that duck, continue on three |
| All ducks silent | Check Stage app is foreground; check `/health` | Flip to Mode 1 filler |
| Audience question gets weird answer | Interrupt, smile, "Next question?" | Move to Mode 1 |
| Mac WiFi drops | Stage attempts auto-reconnect; if >5s, flip to Mode 1 stems | Restart Stage from backup Mac |
| Audio feedback / squeal | Master mute, fix mic position, unmute | End the FAQ portion early |

## After the show

- [ ] Save logs from Stage app (`~/Library/Logs/BoyBand/`)
- [ ] Save any STT transcripts (for later cringe)
- [ ] Power down ducks
- [ ] Rotate WiFi password and all API keys used during the show
      (good hygiene, especially if the laptop was on a stage where
      a screen might have shown anything)
- [ ] Post-mortem in this doc — what broke, what surprised us, what
      we'd change
