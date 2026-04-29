# ElevenAgents config — source of truth

The runtime lives in the **ElevenAgents** dashboard at
[elevenlabs.io/app/agents](https://elevenlabs.io/app/agents). (Product was
renamed from "Conversational AI" / "Convai"; older docs and our older commits
use those names interchangeably.)

The dashboard rots and isn't reviewable, so the canonical version of the
agent's behavior is checked in here:

| File | What |
|---|---|
| [`system_prompt.md`](system_prompt.md) | Persona, tone, how to use tools, failure handling |
| [`tools.json`](tools.json) | Server Tool definitions — names, descriptions, URLs, parameters |
| [`voice.md`](voice.md) | Voice ID, model, settings, why we picked it |

## Applying this config to an ElevenAgents agent

Manual at v0 — ElevenAgents doesn't expose a config API.

1. Sidebar → **ElevenAgents** → **Agents** → **+ New Agent** → **Blank template**
2. **System prompt** — paste contents of [`system_prompt.md`](system_prompt.md)
3. **First message** — `Yeah?` (from the bottom of system_prompt.md)
4. **LLM** — Claude Sonnet 4 nails the dry tone. GPT-4o-mini is the cheap fallback.
5. **Voice** tab — audition against criteria in [`voice.md`](voice.md), commit the choice
6. **Tools** section → **Add tool** → **Webhook**. Three of them, matching [`tools.json`](tools.json):
   - URLs point at your relay (ngrok URL during dev, deployed URL in prod)
   - **Important:** add an `X-Relay-Secret` header to each, value matching `RELAY_SHARED_SECRET` in the relay's `.env`. The header is auth — without it the relay returns 401 and the duck says "I'm not seeing it right now." (We hit this. Don't skip it.)
   - For `get_print_history`, the `n` param is type **Integer** with **Value Type = LLM Prompt** so the model fills it from context

When you change agent behavior, change the file *and* the dashboard, and commit
a message that names the dashboard agent ID. That's the only audit trail we get.

## Iterating

The Test Agent panel inside an agent's page is the fastest feedback loop. Tweak
system prompt in the dashboard, talk to it, when it feels right copy back into
[`system_prompt.md`](system_prompt.md) and commit.

## Connecting clients (firmware)

Custom clients (our [bambu/firmware/](../firmware/) on ESP32-S3, web SDK,
phone over Twilio, etc.) connect via WebSocket. Get a signed URL first:

```
GET https://api.elevenlabs.io/v1/convai/conversation/get-signed-url?agent_id=<id>
Header: xi-api-key: <your key>
→ { "signed_url": "wss://api.elevenlabs.io/v1/convai/conversation?conversation_signature=..." }
```

(URL path still uses `/convai/` for back-compat.) Signed URL is good for ~15
minutes. Public agents skip the signing step.

Audio is base64-encoded **PCM 16-bit LE, 16 kHz, mono**, both directions.
Message protocol implemented in [bambu/firmware/main/agent.c](../firmware/main/agent.c).
