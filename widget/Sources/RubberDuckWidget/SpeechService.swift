// Speech Service — Facade orchestrating STT, TTS, wake word, and permission voice gate.
//
// Delegates to focused components:
//   STTEngine — speech recognition via Apple Speech framework
//   TTSEngine — text-to-speech via macOS `say` command
//   WakeWordProcessor — "ducky" detection and command extraction
//   PermissionVoiceGate — yes/no/ordinal word matching
//   AudioDeviceDiscovery — CoreAudio device enumeration
//
// Logs to ~/Library/Logs/RubberDuck.log for debugging.

import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechService: ObservableObject {
    // Published state
    @Published var isListening: Bool = false
    @Published var lastHeard: String = ""
    @Published var micPermissionGranted: Bool = false
    @Published var speechPermissionGranted: Bool = false
    @Published var selectedMicName: String = ""
    @Published var lastError: String = ""

    // Config
    var wakeWord: String = "ducky" { didSet { wakeWordProcessor.wakeWord = wakeWord } }
    var ttsVoice: String = "Boing" { didSet { tts.voice = ttsVoice } }

    // Callbacks
    var onVoiceInput: ((String) -> Void)?
    var onWakeWord: (() -> Void)?
    var onPermissionResponse: ((Int) -> Void)?  // 0=allow once, 1+=suggestion index, -1=deny

    // Components
    private let stt: STTEngine
    private let tts: TTSEngine
    private var wakeWordProcessor = WakeWordProcessor()
    private var permissionGate = PermissionVoiceGate()

    // Timers
    private var voiceInputTimer: Task<Void, Never>?

    // Log file
    private let logURL: URL = {
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("RubberDuck.log")
    }()

    init() {
        stt = STTEngine()
        tts = TTSEngine()

        // Now that self is fully initialized, wire log + callbacks
        let logFn: (String) -> Void = { [weak self] msg in self?.log(msg) }
        stt.log = logFn
        tts.log = logFn

        // Wire STT transcripts to our processing pipeline
        stt.onTranscript = { [weak self] transcript, isFinal in
            Task { @MainActor in
                self?.processTranscript(transcript, isFinal: isFinal)
            }
        }

        // Share the TTS mute gate with STT so mic mutes during playback
        stt.setTTSGate(tts.gate)
    }

    // MARK: - Public API

    func requestPermissions() {
        log("[speech] Requesting speech recognition permission...")

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }
                self.speechPermissionGranted = (status == .authorized)
                self.log("[speech] Speech auth status: \(status.rawValue) (\(status == .authorized ? "granted" : "denied"))")

                if status != .authorized {
                    self.lastError = "Speech recognition not authorized"
                    return
                }

                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        self.micPermissionGranted = granted
                        self.log("[speech] Mic permission: \(granted ? "granted" : "denied")")
                        if granted {
                            self.selectMicrophone()
                        } else {
                            self.lastError = "Microphone access denied"
                        }
                    }
                }
            }
        }
    }

    func startListening() {
        guard micPermissionGranted && speechPermissionGranted else {
            log("[speech] Missing permissions (mic=\(micPermissionGranted), speech=\(speechPermissionGranted))")
            lastError = "Missing permissions"
            return
        }
        stt.start()
        isListening = stt.isListening
        if isListening {
            log("[speech] Listening for \"\(wakeWord)\"...")
        }
    }

    func stopListening() {
        stt.stop()
        isListening = false
    }

    func speak(_ text: String) {
        tts.speak(text)
    }

    func stopSpeaking() {
        tts.stop()
    }

    func askPermission(toolName: String, options: [String] = []) {
        let prompt = "\(toolName). Allow?"
        permissionGate.startWaiting(optionCount: options.count, prompt: prompt)
        speak(prompt)
    }

    static func listMicrophones() -> [(index: Int, name: String)] {
        AudioDeviceDiscovery.listMicrophones()
    }

    // MARK: - Mic Selection

    private func selectMicrophone() {
        guard let mic = AudioDeviceDiscovery.selectMicrophone() else {
            log("[speech] No microphone found!")
            lastError = "No microphone found"
            return
        }

        selectedMicName = mic.name
        log("[speech] Selected \(mic.isTeensy ? "Teensy" : "default") mic: \(mic.name)")

        if mic.isTeensy {
            // Find Teensy in CoreAudio and configure both STT input and TTS output
            if let teensy = AudioDeviceDiscovery.findTeensy() {
                stt.setTeensyDevice(teensy.deviceID)
                tts.outputDeviceName = teensy.name
                log("[tts] Will route TTS to Teensy via `say -a \"\(teensy.name)\"`")
            }
        }
    }

    // MARK: - Transcript Processing

    private func processTranscript(_ transcript: String, isFinal: Bool) {
        // Permission mode takes priority
        if permissionGate.isWaiting {
            let decision = permissionGate.process(transcript)
            switch decision {
            case .allow:
                speak("Got it.")
                onPermissionResponse?(0)
            case .deny:
                speak("Blocked it.")
                onPermissionResponse?(-1)
            case .selectOption(let index):
                speak("Got it, option \(index).")
                onPermissionResponse?(index)
            case .repeatPrompt:
                speak(permissionGate.lastPrompt)
            case .noMatch:
                break
            }
            return
        }

        // Wake word + command processing
        let result = wakeWordProcessor.process(transcript, isFinal: isFinal)
        switch result {
        case .nothing:
            break

        case .wakeWordOnly:
            lastHeard = ""
            onWakeWord?()
            log("[speech] Wake word detected!")

            // 3s timeout — if no command text, reset
            voiceInputTimer?.cancel()
            voiceInputTimer = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled && self.wakeWordProcessor.isAwake && self.wakeWordProcessor.pendingText.isEmpty {
                    self.log("[speech] No command after wake word, restarting...")
                    self.speak("Hmm?")
                    self.wakeWordProcessor.reset()
                    self.lastHeard = ""
                    self.stt.resetRestartAttempts()
                    self.restartListening()
                }
            }

        case .command(let text):
            lastHeard = text
            voiceInputTimer?.cancel()

            if isFinal {
                sendVoiceCommand(text)
            } else {
                // Debounce: 2.5s of silence before treating partial as final
                voiceInputTimer = Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if !Task.isCancelled {
                        self.sendVoiceCommand(text)
                    }
                }
            }

        case .quit:
            lastHeard = ""
            voiceInputTimer?.cancel()
            wakeWordProcessor.reset()
            speak("Quack! See you later.")
            restartAfterTTS()
        }
    }

    private func sendVoiceCommand(_ text: String) {
        // Kill current recognition FIRST to prevent double-send
        wakeWordProcessor.reset()
        voiceInputTimer?.cancel()
        stopListening()

        log("[speech] Sending: \(text)")
        speak("On it.")
        onVoiceInput?(text)

        restartAfterTTS()
    }

    private func restartAfterTTS() {
        Task {
            while tts.isMuted {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            self.stt.resetRestartAttempts()
            self.startListening()
        }
    }

    private func restartListening() {
        stopListening()
        stt.restart()
        isListening = stt.isListening
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(msg)\n"
        print(line, terminator: "")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
