"""
Rubber Duck — Voice Bridge

Always-on wake word listener. Say "ducky" to activate, then speak.
The duck listens, responds via Claude, speaks the reply, and
triggers evaluation so hardware/dashboard react.

Usage:
  python3 voice.py                         # default settings
  python3 voice.py --mic 2                 # use Yeti (mic index 2)
  python3 voice.py --voice Boing           # set TTS voice
  python3 voice.py --wake-word duck        # custom wake word
  python3 voice.py --list-mics             # show available mics
"""

import argparse
import os
import pathlib
import subprocess
import time

import speech_recognition as sr
from dotenv import load_dotenv

load_dotenv(pathlib.Path(__file__).parent / ".env", override=True)

import anthropic
import requests

import duck_config

# --- Config ---
DEFAULT_VOICE = "Boing"
DEFAULT_WAKE_WORD = "ducky"
EVAL_URL = duck_config.service_url + "/evaluate"
CLAUDE_MODEL = "claude-haiku-4-5-20251001"
SYSTEM_PROMPT = """You are a rubber duck sitting on a developer's desk. You're having a voice conversation with the developer. Keep responses SHORT (1-3 sentences max) — you're chatty but concise. Be opinionated about code and tech. You have personality: sometimes snarky, sometimes encouraging, always honest. You occasionally say "quack" when surprised."""

# --- State ---
conversation_history = []
recognizer = sr.Recognizer()
client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))


def list_mics():
    mics = sr.Microphone.list_microphone_names()
    for i, m in enumerate(mics):
        print(f"  {i}: {m}")


def listen_short(mic_index=None, timeout=5, phrase_limit=4) -> str:
    """Quick listen for wake word detection."""
    mic_kwargs = {"device_index": mic_index} if mic_index is not None else {}
    with sr.Microphone(**mic_kwargs) as source:
        try:
            audio = recognizer.listen(source, timeout=timeout, phrase_time_limit=phrase_limit)
        except sr.WaitTimeoutError:
            return ""
    try:
        return recognizer.recognize_google(audio)
    except (sr.UnknownValueError, sr.RequestError):
        return ""


def listen_full(mic_index=None) -> str:
    """Full listen for actual speech after wake word."""
    mic_kwargs = {"device_index": mic_index} if mic_index is not None else {}
    with sr.Microphone(**mic_kwargs) as source:
        try:
            audio = recognizer.listen(source, timeout=10, phrase_time_limit=30)
        except sr.WaitTimeoutError:
            return ""
    try:
        return recognizer.recognize_google(audio)
    except (sr.UnknownValueError, sr.RequestError):
        return ""


def chat(user_text: str) -> str:
    conversation_history.append({"role": "user", "content": user_text})

    response = client.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=200,
        system=SYSTEM_PROMPT,
        messages=conversation_history,
    )

    reply = response.content[0].text
    conversation_history.append({"role": "assistant", "content": reply})

    if len(conversation_history) > 20:
        conversation_history.pop(0)
        conversation_history.pop(0)

    return reply


def speak(text: str, voice: str):
    safe_text = text.replace('"', '\\"').replace("'", "\\'")
    subprocess.run(["say", "-v", voice, safe_text])


def beep():
    """Short acknowledgment sound when wake word detected."""
    subprocess.Popen(["say", "-v", "Trinoids", "hmm"])


def send_eval(text: str, source: str):
    try:
        requests.post(EVAL_URL, json={
            "source": source,
            "text": text,
            "session_id": "voice",
        }, timeout=5)
    except requests.exceptions.ConnectionError:
        pass


def contains_wake_word(text: str, wake_word: str) -> str:
    """Check if text contains wake word. Returns the text AFTER the wake word, or empty string."""
    text_lower = text.lower()
    wake_lower = wake_word.lower()

    if wake_lower in text_lower:
        # Return everything after the wake word
        idx = text_lower.index(wake_lower) + len(wake_lower)
        remainder = text[idx:].strip().strip(",").strip()
        return remainder if remainder else "__WAKE_ONLY__"

    return ""


def main():
    parser = argparse.ArgumentParser(description="Rubber Duck Voice Bridge")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="macOS TTS voice")
    parser.add_argument("--wake-word", default=DEFAULT_WAKE_WORD, help="Wake word to activate")
    parser.add_argument("--mic", type=int, default=None, help="Microphone index")
    parser.add_argument("--list-mics", action="store_true", help="List mics and exit")
    args = parser.parse_args()

    if args.list_mics:
        print("Available microphones:")
        list_mics()
        return

    print("=" * 50)
    print("  RUBBER DUCK — Voice Bridge")
    print(f"  Wake word: \"{args.wake_word}\"")
    print(f"  Voice: {args.voice}")
    print(f"  Say \"{args.wake_word}\" to activate")
    print(f"  Say \"{args.wake_word} quit\" to exit")
    print("=" * 50)

    # Calibrate
    mic_kwargs = {"device_index": args.mic} if args.mic is not None else {}
    with sr.Microphone(**mic_kwargs) as source:
        print("\n  (calibrating for ambient noise...)")
        recognizer.adjust_for_ambient_noise(source, duration=2)
        recognizer.dynamic_energy_threshold = True
        recognizer.pause_threshold = 0.8

    print(f"  Listening for \"{args.wake_word}\"...\n")

    while True:
        # Phase 1: Listen for wake word (short phrases only)
        heard = listen_short(args.mic, timeout=None, phrase_limit=5)

        if not heard:
            continue

        result = contains_wake_word(heard, args.wake_word)

        if not result:
            # Not the wake word, ignore
            continue

        # Wake word detected!
        if result == "__WAKE_ONLY__":
            # Just the wake word, no command — prompt for more
            print("🦆 (wake!)")
            beep()
            print("🎤 Listening...")
            user_text = listen_full(args.mic)
            if not user_text:
                print("  (nothing heard)")
                continue
        else:
            # Wake word + command in one phrase: "ducky what do you think about React"
            print(f"🦆 (wake!)")
            user_text = result

        print(f"👤 {user_text}")

        # Exit
        if user_text.lower().strip() in ("quit", "exit", "stop", "bye"):
            speak("Quack! See you later.", args.voice)
            break

        # Evaluate what the user said
        send_eval(user_text, "user")

        # Get duck's response
        reply = chat(user_text)
        print(f"🦆 {reply}")

        # Evaluate duck's response
        send_eval(reply, "claude")

        # Speak it
        speak(reply, args.voice)

        print(f"\n  Listening for \"{args.wake_word}\"...")


if __name__ == "__main__":
    main()
