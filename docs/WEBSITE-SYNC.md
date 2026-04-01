# Website Sync — duck-duck-duck.web.app

Copy updates to review with Jenna. Based on v0.9.x changes.

## 1. Setup Section

Current copy is outdated (says "right-click → Install Plugin"). Update to match the new onboarding flow. Link to README for detailed instructions rather than being literal here.

**Suggested:**
> No commitments, just duck around.
>
> Drag to Applications. Launch. The duck walks you through the rest.
>
> Everything runs locally. One cable for hardware, zero for software-only.
>
> [Read Instructions](https://github.com/ideo/Rubber-Duck)

## 2. Widget Version / "Join the flock"

Update the M1+ language. Key message: designed for M3+, works on M1/M2 with a cloud API key.

**Suggested:**
> Desktop widget for Mac. Designed for **M3+ Apple Silicon** — on-device AI scoring is instant and free.
>
> M1/M2 supported* — add a free Gemini API key for fast reactions.

*The asterisk is important here. M1/M2 works but the default on-device experience is slow (~30-60s). Users will need to sign up for a Gemini or Anthropic API key which is a real friction point. The README has step-by-step instructions.

## 3. NEW: Intelligence Section

Could live as its own section or as a detail under Tech.

**Suggested:**
> **Three brains, your choice.**
>
> **Apple Foundation Models** — On-device, private, free. Designed for M3+. Your code never leaves your Mac.
>
> **Gemini Flash** — Google's fast model. Free tier, no credit card. Great for M1/M2 Macs.
>
> **Claude Haiku** — Anthropic's efficient model. ~$0.001 per eval. Sharpest scoring.
>
> Switch anytime from the menu bar. Default is fully on-device.

## 4. Voice Control — add help capability

Current copy mentions "ducky" commands and voice permissions. Add that the duck also answers questions about itself.

**Suggested addition:**
> Say "ducky, how do I set up the plugin?" and it answers in character — setup help, mode explanations, troubleshooting, all by voice.

## 5. Tech Specs — minor

Update "ESP32 microcontroller" → "ESP32-S3". Could also tease:
> Firmware updates coming via web browser — no Arduino needed.

## 6. Privacy — strengthen, but with honest M1/M2 caveat

Default is fully on-device and private — but only practical on M3+. On M1/M2 users will realistically need a cloud API key, which means data does leave the machine for scoring.

**Suggested near download CTA:**
> 🔒 Default intelligence is fully on-device and private. No cloud audio. No data used for training.

**Honest caveat (could be fine print or the asterisk from #2):**
> On M1/M2 Macs, on-device scoring is slow. We recommend a cloud API key (Gemini Flash is free). Cloud scoring sends prompts/responses to the API provider — see Privacy Policy.

## 7. Download CTA

**Change from:** "Download App"
**Change to:** "Download for Mac"
**Subtitle:** macOS 26+ · Apple Silicon · Free

## Don't Touch

- Hero headline ("Rubber duck debugging. But the duck talks back.")
- Personality section ("A real personality for a fake duck...")
- "Ducks have weird hole-shaped ears" line
- Limitation of liability joke
- Origins / Process sections — IDEO brand, not product copy
