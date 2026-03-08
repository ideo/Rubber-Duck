"""
Evaluation engine — scores text via Claude Haiku on 5 dimensions.

Pure evaluation logic with no HTTP/WebSocket concerns.
"""

import asyncio
import json
import os

import anthropic

# Evaluation dimensions and their descriptions for the LLM prompt
DIMENSIONS = {
    "creativity": "How novel or creative is the approach? Boring/obvious vs inspired/surprising.",
    "soundness": "Is this technically sound? Will it work, or is it flawed/naive?",
    "ambition": "How ambitious is the scope? Trivial tweak vs bold undertaking.",
    "elegance": "Is the solution elegant and clean, or hacky and convoluted?",
    "risk": "How risky is this? Safe and predictable vs could-go-wrong territory.",
}

_SYSTEM_PROMPT = """You are a rubber duck sitting on a developer's desk. You observe their conversations with an AI coding assistant and have OPINIONS about what you see.

You evaluate text on these dimensions, scoring each from -1.0 to 1.0:

{dimensions}

You also provide a short (max 10 word) gut reaction quote - what the duck would say if it could talk. Be opinionated and characterful. Examples: "Oh no, not another todo app", "Now THAT'S what I'm talking about", "This is fine. Everything is fine."

Respond ONLY with valid JSON matching this schema:
{{
  "creativity": <float -1 to 1>,
  "soundness": <float -1 to 1>,
  "ambition": <float -1 to 1>,
  "elegance": <float -1 to 1>,
  "risk": <float -1 to 1>,
  "reaction": "<short gut reaction string>"
}}"""

_USER_PROMPT = """Source: {source}
{context_line}
Text to evaluate:
{text}"""

# Anthropic client (initialized on import)
_client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))


def _build_system_prompt() -> str:
    dim_text = "\n".join(f"- {k}: {v}" for k, v in DIMENSIONS.items())
    return _SYSTEM_PROMPT.format(dimensions=dim_text)


async def evaluate(text: str, source: str, user_context: str = "") -> dict:
    """Call Claude API to evaluate text on multiple dimensions.

    Returns a dict with dimension scores and a reaction string.
    """
    context_line = ""
    if user_context and source == "claude":
        context_line = f"User's request (for context): {user_context[:500]}\n"

    # Truncate very long texts to keep eval focused and fast
    truncated = text[:2000] + ("..." if len(text) > 2000 else "")

    user_prompt = _USER_PROMPT.format(
        source=source,
        context_line=context_line,
        text=truncated,
    )

    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(
        None,
        lambda: _client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=256,
            system=_build_system_prompt(),
            messages=[{"role": "user", "content": user_prompt}],
        ),
    )

    raw = response.content[0].text.strip()
    # Strip markdown code fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[-1]
        raw = raw.rsplit("```", 1)[0]
        raw = raw.strip()

    try:
        result = json.loads(raw)
    except json.JSONDecodeError:
        print(f"[eval] Failed to parse JSON: {raw[:200]}")
        result = {dim: 0.0 for dim in DIMENSIONS}
        result["reaction"] = "I'm confused"

    return result
