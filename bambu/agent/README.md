# Convai Agent — source of truth

The runtime lives in the [ElevenLabs Convai dashboard](https://elevenlabs.io/app/conversational-ai).
The dashboard rots and isn't reviewable, so the canonical version of the
agent's behavior is checked in here:

| File | What |
|---|---|
| [`system_prompt.md`](system_prompt.md) | Persona, tone, how to use tools, failure handling |
| [`tools.json`](tools.json) | Webhook tool definitions — names, descriptions, URLs, parameters |
| [`voice.md`](voice.md) | Voice ID, model, settings, why we picked it |

## Applying this config to a Convai agent

Manual for now. Convai doesn't expose a config API at v0.

1. Create a new agent in the Convai dashboard
2. **System prompt** — paste contents of `system_prompt.md`
3. **First message** — copy from `system_prompt.md` (the "First message" section at the bottom)
4. **LLM** — pick from `system_prompt.md` (Claude or GPT-4o-mini class)
5. **Voice** — pick the voice ID from `voice.md`
6. **Tools** — add three Webhook tools matching `tools.json`. URLs point at your relay (ngrok URL during dev). Add `X-Relay-Secret` header on each, matching `RELAY_SHARED_SECRET` in the relay's env.

When you change agent behavior, change the file *and* the dashboard, and commit
a message that names the dashboard agent ID. That's the only audit trail we get.

## Iterating

Convai's web playground is the fastest feedback loop. Tweak system prompt in
the dashboard, talk to it, when it feels right copy back into `system_prompt.md`
and commit.
