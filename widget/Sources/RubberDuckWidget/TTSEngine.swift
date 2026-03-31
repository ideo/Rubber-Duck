// TTS Engine — Text-to-speech via macOS `say` command.
//
// Routes audio to Teensy USB Audio device via `say -a <name>` when available,
// falls back to system default output. Manages mic muting during playback
// to prevent speaker → mic feedback.

import Foundation

/// Thread-safe mute flag — accessed from both MainActor and the audio render thread.
/// Separate class (not actor-isolated) so the STTEngine's audio tap can read it directly.
/// Uses os_unfair_lock for atomic read/write across threads.
class TTSGate: @unchecked Sendable {
    private var _muted = false
    private var _lock = os_unfair_lock()

    var muted: Bool {
        get {
            os_unfair_lock_lock(&_lock)
            defer { os_unfair_lock_unlock(&_lock) }
            return _muted
        }
        set {
            os_unfair_lock_lock(&_lock)
            _muted = newValue
            os_unfair_lock_unlock(&_lock)
        }
    }
}

@MainActor
class TTSEngine {
    private struct PlaybackSession {
        let id: UUID
        let completion: TTSPlaybackCompletion
        var processes: [Process]
        var stopReason: TTSStopReason?
    }

    /// Shared gate for muting mic input during TTS playback.
    let gate = TTSGate()

    /// Voice to use for `say` command.
    var voice: String = DuckConfig.ttsVoice

    /// CoreAudio device name for output routing (e.g. "Teensy MIDI_Audio").
    /// When set, TTS routes to this device via `say -a <name>`.
    var outputDeviceName: String?

    /// Master volume (0.0–1.0). Applied via CoreAudio device volume when
    /// routing to a duck device. No effect on system default output.
    var volume: Float = DuckConfig.volume {
        didSet { applyDeviceVolume() }
    }

    private var activeSessionID: UUID?
    private var sessions: [UUID: PlaybackSession] = [:]
    private func log(_ msg: String) { DuckLog.log(msg) }

    /// Speak text through the configured output device.
    /// Mutes the TTSGate while speaking to prevent mic feedback.
    /// Strip markdown and emoji that `say` reads literally.
    private func stripMarkdown(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "#", with: "")
        // Strip emoji — keep only characters that are letters, numbers, punctuation, or whitespace
        cleaned = String(cleaned.unicodeScalars.filter { scalar in
            scalar.properties.isEmoji == false || scalar.value < 0x80
        })
        return cleaned
    }

    // MARK: - Pronunciation fixes

    /// Words that macOS `say` mangles. Maps plain text to `say` phoneme markup.
    /// Add entries here whenever TTS mispronounces a word.
    private static let pronunciations: [(word: String, phoneme: String)] = [
        ("Ahab", "[[inpt PHON]]EY1hAEb[[inpt TEXT]]"),
        ("Claude", "[[inpt PHON]]klAOd[[inpt TEXT]]"),
    ]

    /// Replace known mispronounced words with phoneme markup before passing to `say`.
    private func applyPronunciations(_ text: String) -> String {
        var result = text
        for entry in Self.pronunciations {
            result = result.replacingOccurrences(of: entry.word, with: entry.phoneme, options: .caseInsensitive)
        }
        return result
    }

    func play(_ text: String, utteranceID: UUID, skipChirpWait: Bool = false, completion: @escaping TTSPlaybackCompletion) {
        guard !text.isEmpty else { return }
        log("[tts] \(text)")

        let cleaned = applyPronunciations(stripMarkdown(text))
        let primary = Process()
        primary.executableURL = URL(fileURLWithPath: "/usr/bin/say")

        // Route to Teensy speaker via `-a <name>` if available.
        // Note: `say -a` uses its OWN device IDs (not CoreAudio AudioDeviceID),
        // but it also accepts device names — use the name for reliability.
        if let name = outputDeviceName {
            primary.arguments = ["-v", voice, "-a", name, cleaned]
        } else {
            primary.arguments = ["-v", voice, cleaned]
        }

        primary.standardOutput = FileHandle.nullDevice
        primary.standardError = FileHandle.nullDevice

        // Mute mic input while speaking to prevent feedback
        // (speaker is right next to electret mic on the duck)
        gate.muted = true
        activeSessionID = utteranceID
        sessions[utteranceID] = PlaybackSession(
            id: utteranceID,
            completion: completion,
            processes: [primary],
            stopReason: nil
        )

        let voiceName = voice              // capture for Sendable closure
        let deviceName = outputDeviceName  // capture for retry
        let originalText = text
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                if await self.stopReason(for: utteranceID) != nil {
                    await self.finishSession(utteranceID, defaultResult: .cancelled(.replaced))
                    return
                }

                try primary.run()
                primary.waitUntilExit()

                // If say -a failed (device gone, not killed), retry on system default
                if primary.terminationStatus != 0,
                   primary.terminationReason != .uncaughtSignal,
                   deviceName != nil,
                   await self.stopReason(for: utteranceID) == nil {
                    DuckLog.log("[tts] say -a failed (exit \(primary.terminationStatus)) — retrying on system audio")
                    await MainActor.run {
                        self.outputDeviceName = nil
                    }
                    let retry = Process()
                    retry.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                    retry.arguments = ["-v", voiceName, originalText]
                    retry.standardOutput = FileHandle.nullDevice
                    retry.standardError = FileHandle.nullDevice
                    await self.registerProcess(retry, for: utteranceID)
                    if await self.stopReason(for: utteranceID) != nil {
                        await self.finishSession(utteranceID, defaultResult: .cancelled(.replaced))
                        return
                    }
                    try retry.run()
                    retry.waitUntilExit()
                }
            } catch {
                DuckLog.log("[tts] say failed: \(error)")
                await self.finishSession(utteranceID, defaultResult: .failed)
                return
            }

            if let stopReason = await self.stopReason(for: utteranceID) {
                DuckLog.log("[tts] say was cancelled (superseded)")
                await self.finishSession(utteranceID, defaultResult: .cancelled(stopReason))
                return
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            await self.finishSession(utteranceID, defaultResult: .finished)
        }
    }

    func stopPlayback(reason: TTSStopReason) {
        guard let activeSessionID, var session = sessions[activeSessionID] else { return }
        session.stopReason = reason
        sessions[activeSessionID] = session
        for process in session.processes where process.isRunning {
            process.terminate()
        }
    }

    /// Whether TTS is currently muting the mic.
    var isMuted: Bool { gate.muted }

    private func stopReason(for sessionID: UUID) -> TTSStopReason? {
        sessions[sessionID]?.stopReason
    }

    private func registerProcess(_ process: Process, for sessionID: UUID) {
        guard var session = sessions[sessionID] else { return }
        session.processes.append(process)
        sessions[sessionID] = session
    }

    private func finishSession(_ sessionID: UUID, defaultResult: TTSPlaybackResult) {
        guard let session = sessions.removeValue(forKey: sessionID) else { return }
        let result = session.stopReason.map(TTSPlaybackResult.cancelled) ?? defaultResult
        if activeSessionID == sessionID {
            activeSessionID = nil
            gate.muted = false
        }
        session.completion(sessionID, result)
    }

    // MARK: - CoreAudio Device Volume

    /// Apply the current volume to the duck output device via CoreAudio.
    /// Only affects duck UAC devices (Teensy, ESP32-S3) — not system default output.
    private func applyDeviceVolume() {
        guard outputDeviceName != nil else { return }
        guard let device = AudioDeviceDiscovery.findDuckDevice() else { return }
        AudioDeviceDiscovery.setDeviceVolume(device.deviceID, volume: volume)
        log("[tts] Set device volume to \(Int(volume * 100))%")
    }
}
