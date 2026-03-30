// Audio Backend — Protocol-based STT/TTS dispatch for SpeechService.
//
// Wraps the concrete STT + TTS engines into a uniform interface so
// SpeechService can switch between local/Teensy and ESP32 serial
// paths without `switch audioPath` in every method.

import Foundation

enum TTSStopReason: Sendable {
    case replaced
    case userCancelled
    case shutdown
}

enum TTSPlaybackResult: Sendable {
    case finished
    case cancelled(TTSStopReason)
    case failed
}

typealias TTSPlaybackCompletion = @MainActor @Sendable (UUID, TTSPlaybackResult) -> Void

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
    func play(_ text: String, utteranceID: UUID, skipChirpWait: Bool, completion: @escaping TTSPlaybackCompletion)
    func stopPlayback(reason: TTSStopReason)
}

// MARK: - Conformances

extension STTEngine: STTBackend {}

extension SerialMicEngine: STTBackend {}

extension TTSEngine: TTSBackend {}

extension SerialTTSEngine: TTSBackend {}
