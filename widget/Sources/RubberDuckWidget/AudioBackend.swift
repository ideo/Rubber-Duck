// Audio Backend — Protocol-based STT/TTS dispatch for SpeechService.
//
// Wraps the concrete STT + TTS engines into a uniform interface so
// SpeechService can switch between local/Teensy and ESP32 serial
// paths without `switch audioPath` in every method.

import Foundation

/// Uniform interface for the active STT engine (CoreAudio or serial).
@MainActor
protocol STTBackend: AnyObject {
    var isListening: Bool { get }
    func start()
    func stop()
    func restart()
    func resetRestartAttempts()
}

/// Uniform interface for the active TTS engine (`say` command or serial PCM).
@MainActor
protocol TTSBackend: AnyObject {
    var isMuted: Bool { get }
    func speak(_ text: String, skipChirpWait: Bool)
    func stop()
}

// MARK: - Conformances

extension STTEngine: STTBackend {}

extension SerialMicEngine: STTBackend {}

extension TTSEngine: TTSBackend {
    func speak(_ text: String, skipChirpWait: Bool) {
        // Local TTS via `say` doesn't use chirp wait — ignore the flag.
        speak(text)
    }
}

extension SerialTTSEngine: TTSBackend {}
