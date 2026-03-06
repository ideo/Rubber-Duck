"""
Rubber Duck — Unified Speech Engine

Single-service STT + TTS with swappable backend.
Voice is the primary input to Claude Code via tmux bridge.

Current backend: Google STT + macOS `say`
Future: Realtime API, ElevenLabs

Usage:
    engine = SpeechEngine(voice="Boing", wake_word="ducky")
    engine.start(on_wake=my_callback)  # starts background listener
    engine.speak("What are we up to?")
"""

import asyncio
import os
import subprocess
import threading
import time

import speech_recognition as sr


class SpeechEngine:
    """Unified STT + TTS with wake word detection and tmux bridge."""

    def __init__(self, mic_index=None, voice="Boing", wake_word="ducky"):
        self.recognizer = sr.Recognizer()
        self.mic_index = mic_index
        self.voice = voice
        self.wake_word = wake_word

        # State
        self._listener_thread = None
        self._running = False
        self._on_voice_input = None       # callback(text) when user speaks after wake word
        self._on_wake = None              # callback() when wake word detected
        self._permission_pending = False  # when True, next speech = yes/no decision
        self._permission_result = None
        self._permission_event = threading.Event()
        self._tmux_session = None         # tmux session name for Claude Code bridge
        self._tmux_pane = None            # tmux pane target for Claude Code

    # ==========================================================
    # Setup
    # ==========================================================

    def calibrate(self):
        """Calibrate for ambient noise. Call once at startup."""
        mic_kwargs = self._mic_kwargs()
        with sr.Microphone(**mic_kwargs) as source:
            print("[speech] Calibrating for ambient noise...")
            self.recognizer.adjust_for_ambient_noise(source, duration=2)
            self.recognizer.dynamic_energy_threshold = True
            self.recognizer.pause_threshold = 0.8
        print("[speech] Calibration done.")

    def set_tmux_target(self, session="duck", pane="claude.0"):
        """Configure tmux target for injecting voice into Claude Code."""
        self._tmux_session = session
        self._tmux_pane = pane

    # ==========================================================
    # STT — Listening
    # ==========================================================

    def listen_short(self, timeout=5, phrase_limit=5) -> str:
        """Quick listen for wake word detection."""
        mic_kwargs = self._mic_kwargs()
        with sr.Microphone(**mic_kwargs) as source:
            try:
                audio = self.recognizer.listen(
                    source, timeout=timeout, phrase_time_limit=phrase_limit
                )
            except sr.WaitTimeoutError:
                return ""
        try:
            return self.recognizer.recognize_google(audio)
        except (sr.UnknownValueError, sr.RequestError):
            return ""

    def listen_full(self, timeout=10, phrase_limit=30) -> str:
        """Full listen for extended speech after wake word."""
        mic_kwargs = self._mic_kwargs()
        with sr.Microphone(**mic_kwargs) as source:
            try:
                audio = self.recognizer.listen(
                    source, timeout=timeout, phrase_time_limit=phrase_limit
                )
            except sr.WaitTimeoutError:
                return ""
        try:
            return self.recognizer.recognize_google(audio)
        except (sr.UnknownValueError, sr.RequestError):
            return ""

    def listen_yes_no(self, timeout=15) -> bool:
        """Listen for yes/no response. Returns True for affirmative."""
        text = self.listen_full(timeout=timeout, phrase_limit=10)
        if not text:
            return False
        lower = text.lower().strip()
        affirmatives = [
            "yes", "yeah", "yep", "yup", "sure", "allow", "do it",
            "go ahead", "approve", "ok", "okay", "proceed", "go for it",
            "let it", "fine", "absolutely",
        ]
        return any(w in lower for w in affirmatives)

    # ==========================================================
    # TTS — Speaking
    # ==========================================================

    def speak(self, text: str):
        """Non-blocking TTS."""
        if not text:
            return
        safe = text.replace('"', '\\"').replace("'", "\\'")
        subprocess.Popen(["say", "-v", self.voice, safe])

    def speak_sync(self, text: str):
        """Blocking TTS — waits until speech finishes."""
        if not text:
            return
        safe = text.replace('"', '\\"').replace("'", "\\'")
        subprocess.run(["say", "-v", self.voice, safe])

    def beep(self):
        """Short acknowledgment sound when wake word detected."""
        subprocess.Popen(["say", "-v", "Trinoids", "hmm"])

    # ==========================================================
    # Wake Word Detection
    # ==========================================================

    def contains_wake_word(self, text: str) -> str:
        """Check if text contains wake word.
        Returns text AFTER the wake word, or empty string if not found.
        Returns '__WAKE_ONLY__' if only the wake word was said.
        """
        text_lower = text.lower()
        wake_lower = self.wake_word.lower()
        if wake_lower in text_lower:
            idx = text_lower.index(wake_lower) + len(wake_lower)
            remainder = text[idx:].strip().strip(",").strip()
            return remainder if remainder else "__WAKE_ONLY__"
        return ""

    # ==========================================================
    # tmux Bridge — Voice → Claude Code
    # ==========================================================

    def send_to_claude_code(self, text: str) -> bool:
        """Inject transcribed text into Claude Code via tmux send-keys."""
        if not self._tmux_session:
            print("[speech] No tmux session configured")
            return False

        target = f"{self._tmux_session}:{self._tmux_pane}"
        try:
            # Use literal flag -l to avoid tmux key interpretation
            subprocess.run(
                ["tmux", "send-keys", "-t", target, "-l", text],
                timeout=5,
                capture_output=True,
            )
            # Send Enter separately
            subprocess.run(
                ["tmux", "send-keys", "-t", target, "Enter"],
                timeout=5,
                capture_output=True,
            )
            print(f"[speech→claude] {text}")
            return True
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"[speech] tmux send-keys failed: {e}")
            return False

    # ==========================================================
    # Permission Voice Gate
    # ==========================================================

    def request_permission(self, tool_name: str, timeout: float = 30.0) -> bool:
        """Ask user for voice permission. Blocks until response or timeout.

        Called from the /permission endpoint when Claude wants to do something.
        Interrupts the normal wake word loop to listen for yes/no.
        """
        self._permission_event.clear()
        self._permission_result = None
        self._permission_pending = True

        # Ask the question
        question = f"Claude wants to use {tool_name}. Should I allow it?"
        print(f"[permission] {question}")
        self.speak_sync(question)

        # Listen for yes/no
        print("[permission] Listening for response...")
        approved = self.listen_yes_no(timeout=timeout)

        self._permission_pending = False
        self._permission_result = approved
        self._permission_event.set()

        if approved:
            self.speak("Got it, proceeding.")
            print("[permission] ✅ Approved")
        else:
            self.speak("Blocked it.")
            print("[permission] ❌ Denied")

        return approved

    # ==========================================================
    # Background Listener Loop
    # ==========================================================

    def start(self, on_voice_input=None, on_wake=None):
        """Start the background wake word listener.

        Args:
            on_voice_input: callback(text) when user speaks after wake word.
                           If None, text is sent to Claude Code via tmux.
            on_wake: callback() when wake word is detected (for UI feedback).
        """
        self._on_voice_input = on_voice_input
        self._on_wake = on_wake
        self._running = True
        self._listener_thread = threading.Thread(
            target=self._listener_loop, daemon=True
        )
        self._listener_thread.start()
        print(f'[speech] Listening for "{self.wake_word}"...')

    def stop(self):
        """Stop the background listener."""
        self._running = False
        if self._listener_thread:
            self._listener_thread.join(timeout=5)
        print("[speech] Listener stopped.")

    def _listener_loop(self):
        """Main listening loop — runs in background thread."""
        while self._running:
            # If permission is pending, skip normal listening
            # (request_permission handles its own listening)
            if self._permission_pending:
                time.sleep(0.1)
                continue

            # Phase 1: Listen for wake word (short phrases)
            heard = self.listen_short(timeout=None, phrase_limit=5)

            if not heard:
                continue

            result = self.contains_wake_word(heard)

            if not result:
                continue

            # Wake word detected!
            if self._on_wake:
                self._on_wake()

            if result == "__WAKE_ONLY__":
                # Just wake word — prompt for more
                print("🦆 (wake!)")
                self.beep()
                print("🎤 Listening...")
                user_text = self.listen_full()
                if not user_text:
                    print("  (nothing heard)")
                    continue
            else:
                # Wake word + command: "ducky refactor the auth module"
                print("🦆 (wake!)")
                user_text = result

            print(f"👤 {user_text}")

            # Check for quit
            if user_text.lower().strip() in ("quit", "exit", "stop", "bye"):
                self.speak("Quack! See you later.")
                self._running = False
                break

            # Dispatch the voice input
            if self._on_voice_input:
                self._on_voice_input(user_text)
            else:
                # Default: send to Claude Code via tmux
                self.send_to_claude_code(user_text)

    # ==========================================================
    # Utility
    # ==========================================================

    def _mic_kwargs(self) -> dict:
        if self.mic_index is not None:
            return {"device_index": self.mic_index}
        return {}

    @staticmethod
    def find_teensy_mic():
        """Find Teensy audio device index for use as microphone."""
        for i, name in enumerate(sr.Microphone.list_microphone_names()):
            if "teensy" in name.lower():
                return i
        return None

    @staticmethod
    def list_mics():
        """List available microphone devices."""
        mics = sr.Microphone.list_microphone_names()
        for i, m in enumerate(mics):
            print(f"  {i}: {m}")
        return mics
