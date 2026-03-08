// TTS Engine — Text-to-speech via macOS `say` command.
//
// Routes audio to Teensy USB Audio device via `say -a <name>` when available,
// falls back to system default output. Manages mic muting during playback
// to prevent speaker → mic feedback.

import Foundation

/// Thread-safe mute flag — accessed from both MainActor and the audio render thread.
/// Separate class (not actor-isolated) so the STTEngine's audio tap can read it directly.
class TTSGate: @unchecked Sendable {
    var muted = false
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

    private var ttsProcess: Process?
    var log: ((String) -> Void)?

    /// Speak text through the configured output device.
    /// Mutes the TTSGate while speaking to prevent mic feedback.
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        log?("[tts] \(text)")

        // Stop any current speech to prevent pileup
        stop()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")

        // Route to Teensy speaker via `-a <name>` if available.
        // Note: `say -a` uses its OWN device IDs (not CoreAudio AudioDeviceID),
        // but it also accepts device names — use the name for reliability.
        if let name = outputDeviceName {
            task.arguments = ["-v", voice, "-a", name, text]
        } else {
            task.arguments = ["-v", voice, text]
        }

        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        // Mute mic input while speaking to prevent feedback
        // (speaker is right next to electret mic on the duck)
        gate.muted = true
        ttsProcess = task

        let g = gate
        let logFn = log
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                logFn?("[tts] say failed: \(error)")
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
}
