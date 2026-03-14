// Serial Mic Engine — Receives mic audio from ESP32 over serial, feeds to SFSpeechRecognizer.
//
// For ESP32 boards that stream mic PCM via binary frames (tag 0x04).
// Converts incoming Int16 PCM at 16kHz to AVAudioPCMBuffer and appends
// to a SFSpeechAudioBufferRecognitionRequest — no AVAudioEngine needed.

import Foundation
import Speech
import AVFoundation

@MainActor
class SerialMicEngine: ObservableObject {
    @Published var isListening = false
    @Published var lastError = ""

    /// Called when a transcript is produced (text, isFinal).
    var onTranscript: ((String, Bool) -> Void)?

    private weak var transport: SerialTransport?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Restart logic
    private var restartAttempts = 0
    private let maxRestartAttempts = 5
    private var recognitionWatchdog: Task<Void, Never>?

    // Mic mute gate — owned by SerialTTSEngine, shared here
    private var ttsGate: TTSGate?

    // Audio format for the 16kHz Int16 mono PCM from ESP32
    private let audioFormat: AVAudioFormat

    var log: ((String) -> Void)?

    init(transport: SerialTransport) {
        self.transport = transport
        self.audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!
    }

    /// Set the TTSGate so mic frames are dropped during TTS playback.
    func setTTSGate(_ gate: TTSGate) {
        self.ttsGate = gate
    }

    // MARK: - Listening

    func start() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            log?("[serial-mic] Speech recognizer unavailable")
            lastError = "Speech recognizer unavailable"
            return
        }

        stop()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            log?("[serial-mic] Failed to create recognition request")
            return
        }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self, self.isListening else { return }
                self.resetWatchdog()

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.onTranscript?(transcript, result.isFinal)

                    if result.isFinal {
                        self.log?("[serial-mic] Final, restarting...")
                        self.restartAttempts = 0
                        self.restart()
                    }
                }

                if let error = error {
                    let msg = error.localizedDescription
                    if !msg.contains("canceled") {
                        self.log?("[serial-mic] Recognition error: \(msg)")
                    }
                    self.lastError = msg
                    self.restart()
                }
            }
        }

        // Tell ESP32 to start streaming mic frames
        transport?.sendCommand("M,1")

        // Register for binary frames from transport
        transport?.onBinaryFrame = { [weak self] tag, data in
            Task { @MainActor in
                self?.handleBinaryFrame(tag: tag, data: data)
            }
        }

        isListening = true
        restartAttempts = 0
        log?("[serial-mic] Listening via ESP32 mic...")
    }

    func stop() {
        recognitionWatchdog?.cancel()
        recognitionWatchdog = nil

        // Stop ESP32 mic streaming
        transport?.sendCommand("M,0")

        // Don't clear onBinaryFrame — other code might need it.
        // The gate check in handleBinaryFrame prevents feeding during TTS.

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    func restart() {
        stop()

        restartAttempts += 1
        if restartAttempts > maxRestartAttempts {
            log?("[serial-mic] Too many restart attempts (\(restartAttempts)). Giving up.")
            lastError = "Recognition keeps failing."
            return
        }

        let delay = UInt64(pow(2.0, Double(restartAttempts - 1))) * 1_000_000_000
        log?("[serial-mic] Restarting in \(restartAttempts)s...")

        Task {
            try? await Task.sleep(nanoseconds: delay)
            if !self.isListening {
                self.start()
            }
        }
    }

    func resetRestartAttempts() {
        restartAttempts = 0
    }

    // MARK: - Binary Frame Handling

    /// Called when a binary frame arrives from the serial transport.
    private func handleBinaryFrame(tag: UInt8, data: Data) {
        guard tag == 0x04 else { return } // Only handle mic frames
        guard isListening else { return }

        // Drop frames while TTS is playing (prevent feedback)
        if let gate = ttsGate, gate.muted { return }

        // Convert raw Int16 PCM bytes to AVAudioPCMBuffer
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { return }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(sampleCount)) else {
            return
        }
        pcmBuffer.frameLength = AVAudioFrameCount(sampleCount)

        // Copy Int16 samples into the buffer
        data.withUnsafeBytes { rawPtr in
            guard let srcPtr = rawPtr.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            guard let dstPtr = pcmBuffer.int16ChannelData?[0] else { return }
            dstPtr.update(from: srcPtr, count: sampleCount)
        }

        recognitionRequest?.append(pcmBuffer)
    }

    // MARK: - Watchdog

    private func resetWatchdog() {
        recognitionWatchdog?.cancel()
        recognitionWatchdog = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            if !Task.isCancelled && self.isListening {
                self.log?("[serial-mic] Watchdog: recognition silent for 10s, restarting...")
                self.restartAttempts = 0
                self.restart()
            }
        }
    }
}
