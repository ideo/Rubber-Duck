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

    private var ttsProcess: Process?
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

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        log("[tts] \(text)")

        // Stop any current speech to prevent pileup
        stop()

        let cleaned = stripMarkdown(text)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")

        // Route to Teensy speaker via `-a <name>` if available.
        // Note: `say -a` uses its OWN device IDs (not CoreAudio AudioDeviceID),
        // but it also accepts device names — use the name for reliability.
        if let name = outputDeviceName {
            task.arguments = ["-v", voice, "-a", name, cleaned]
        } else {
            task.arguments = ["-v", voice, cleaned]
        }

        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        // Mute mic input while speaking to prevent feedback
        // (speaker is right next to electret mic on the duck)
        gate.muted = true
        ttsProcess = task

        let g = gate
        let voiceName = voice              // capture for Sendable closure
        let deviceName = outputDeviceName  // capture for retry
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()

                // If stop() killed this process (SIGTERM), a new speak() has
                // already taken over — exit silently without retrying or
                // touching the gate/device state.
                if task.terminationReason == .uncaughtSignal {
                    DuckLog.log("[tts] say was cancelled (superseded)")
                    return
                }

                // If say -a failed (device gone, not killed), retry on system default
                if task.terminationStatus != 0, deviceName != nil {
                    DuckLog.log("[tts] say -a failed (exit \(task.terminationStatus)) — retrying on system audio")
                    Task { @MainActor in
                        self?.outputDeviceName = nil
                    }
                    let retry = Process()
                    retry.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                    retry.arguments = ["-v", voiceName, text]
                    retry.standardOutput = FileHandle.nullDevice
                    retry.standardError = FileHandle.nullDevice
                    try retry.run()
                    retry.waitUntilExit()
                }
            } catch {
                DuckLog.log("[tts] say failed: \(error)")
            }
            // Unmute after say exits + brief delay for USB audio buffer drain
            Thread.sleep(forTimeInterval: 0.3)
            g.muted = false
            Task { @MainActor in
                if self?.ttsProcess === task {
                    self?.ttsProcess = nil
                }
            }
        }
    }

    /// Stop any currently speaking process.
    func stop() {
        if let process = ttsProcess, process.isRunning {
            process.terminate()
            ttsProcess = nil
        }
        gate.muted = false
    }

    /// Whether TTS is currently muting the mic.
    var isMuted: Bool { gate.muted }

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
