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

    /// Called from the serial frame handler with RMS level (0.0–1.0). Fires off MainActor.
    nonisolated(unsafe) var onAudioLevel: ((Float) -> Void)?

    private weak var transport: SerialTransport?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    // Nonisolated reference to the active request for the binary frame callback.
    private nonisolated(unsafe) var _activeRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Restart logic
    private lazy var restartController: RecognitionRestartController = {
        let rc = RecognitionRestartController(label: "serial-mic")
        rc.onRestart = { [weak self] in self?.start() }
        return rc
    }()

    // Mic mute gate — owned by SerialTTSEngine, shared here.
    // Also stored nonisolated for the binary frame callback.
    private var ttsGate: TTSGate?
    private nonisolated(unsafe) var _gate: TTSGate?

    // Nonisolated flag for the binary frame callback (avoids MainActor hop per frame).
    // Written on start/stop from MainActor; read from the serial read thread.
    private nonisolated(unsafe) var _feedingAudio = false

    // Audio format for the 16kHz Int16 mono PCM from ESP32
    private let audioFormat: AVAudioFormat

    private func log(_ msg: String) { DuckLog.log(msg) }

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
        self._gate = gate
    }

    // MARK: - Listening

    func start() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            log("[serial-mic] Speech recognizer unavailable")
            lastError = "Speech recognizer unavailable"
            return
        }

        stop()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        _activeRequest = recognitionRequest
        guard let request = recognitionRequest else {
            log("[serial-mic] Failed to create recognition request")
            return
        }
        request.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self, self.isListening else { return }
                self.restartController.resetWatchdog(isListening: self.isListening)

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.onTranscript?(transcript, result.isFinal)

                    if result.isFinal {
                        self.log("[serial-mic] Final, restarting...")
                        self.restartController.resetAttempts()
                        self.restart()
                    }
                }

                if let error = error {
                    let msg = error.localizedDescription
                    if !msg.contains("canceled") {
                        self.log("[serial-mic] Recognition error: \(msg)")
                    }
                    self.lastError = msg
                    self.restart()
                }
            }
        }

        // Tell ESP32 to start streaming mic frames
        transport?.sendCommand("M,1")

        // Register for binary frames from transport — called on the serial read thread.
        // Uses nonisolated handleBinaryFrame to avoid 31 MainActor hops/sec.
        transport?.onBinaryFrame = { [weak self] tag, data in
            self?.handleBinaryFrame(tag: tag, data: data)
        }

        isListening = true
        _feedingAudio = true
        // Don't reset attempts here — let the backoff accumulate across restarts.
        // Only reset on successful recognition (line 93) or explicit resetRestartAttempts().
        log("[serial-mic] Listening via ESP32 mic...")
    }

    func stop() {
        restartController.cancelWatchdog()

        // Stop ESP32 mic streaming
        transport?.sendCommand("M,0")

        // Don't clear onBinaryFrame — other code might need it.
        // The gate check in handleBinaryFrame prevents feeding during TTS.

        _feedingAudio = false
        _activeRequest = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    func restart() {
        stop()
        restartController.scheduleRestart()
    }

    func resetRestartAttempts() {
        restartController.resetAttempts()
    }

    // MARK: - Binary Frame Handling

    /// Called on the serial read thread when a binary frame arrives.
    /// Nonisolated to avoid ~31 MainActor hops/sec. Uses `_feedingAudio` flag
    /// (set on start/stop) and `ttsGate.muted` (thread-safe by design) for checks.
    /// `recognitionRequest?.append()` is documented as thread-safe.
    private nonisolated func handleBinaryFrame(tag: UInt8, data: Data) {
        guard tag == 0x04 else { return } // Only handle mic frames
        guard _feedingAudio else { return }

        // Drop frames while TTS is playing (prevent feedback)
        if let gate = _gate, gate.muted { return }

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

        _activeRequest?.append(pcmBuffer)

        // Compute RMS for the dashboard level meter
        if let cb = onAudioLevel {
            data.withUnsafeBytes { rawPtr in
                guard let srcPtr = rawPtr.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
                var sum: Float = 0
                for i in 0..<sampleCount {
                    let s = Float(srcPtr[i]) / 32768.0
                    sum += s * s
                }
                let rms = min(sqrt(sum / max(Float(sampleCount), 1)), 1.0)
                cb(rms)
            }
        }
    }

}
