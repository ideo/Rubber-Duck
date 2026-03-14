// Speech Service — Facade orchestrating STT, TTS, wake word, and permission voice gate.
//
// Delegates to focused components:
//   STTEngine — speech recognition via Apple Speech framework
//   TTSEngine — text-to-speech via macOS `say` command
//   WakeWordProcessor — "ducky" detection and command extraction
//   PermissionVoiceGate — yes/no/ordinal word matching
//   AudioDeviceDiscovery — CoreAudio device enumeration
//
// Logs to ~/Library/Logs/DuckDuckDuck.log for debugging.

import Foundation
import Speech
import AVFoundation

/// Mic listening level — Off → Permissions Only → Active (wake word).
enum ListenMode: Int, CaseIterable {
    case off = 0            // Mic off
    case permissionsOnly    // Mic on, only responds to yes/no permission gate
    case active             // Mic on, wake word + permissions

    var label: String {
        switch self {
        case .off: return "Off"
        case .permissionsOnly: return "Permissions Only"
        case .active: return "Active"
        }
    }

    /// Cycle to the next mode.
    var next: ListenMode {
        ListenMode(rawValue: (rawValue + 1) % ListenMode.allCases.count) ?? .off
    }
}

@MainActor
class SpeechService: ObservableObject {
    // Published state
    @Published var isListening: Bool = false
    @Published var lastHeard: String = ""
    @Published var micPermissionGranted: Bool = false
    @Published var speechPermissionGranted: Bool = false
    @Published var selectedMicName: String = ""
    @Published var lastError: String = ""

    // Listen mode (persisted)
    @Published var listenMode: ListenMode = {
        let raw = UserDefaults.standard.integer(forKey: "duck_listen_mode")
        return ListenMode(rawValue: raw) ?? .active
    }() {
        didSet {
            UserDefaults.standard.set(listenMode.rawValue, forKey: "duck_listen_mode")
            applyListenMode()
        }
    }

    // Config
    var wakeWord: String = "ducky" { didSet { wakeWordProcessor.wakeWord = wakeWord } }
    var ttsVoice: String = UserDefaults.standard.string(forKey: "duck_tts_voice") ?? DuckConfig.ttsVoice {
        didSet {
            tts.voice = ttsVoice
            serialTTS?.voice = ttsVoice
            UserDefaults.standard.set(ttsVoice, forKey: "duck_tts_voice")
        }
    }

    /// Whether Wildcard mode is active (AI picks voice per utterance).
    var isWildcardMode: Bool { ttsVoice == DuckVoices.wildcardSayName }

    /// Set voice on the active TTS engine for one utterance, without persisting to UserDefaults.
    /// Used by Wildcard mode to swap voices per-eval.
    func setVoiceTransient(_ sayName: String) {
        tts.voice = sayName
        serialTTS?.voice = sayName
    }

    // Callbacks
    var onVoiceInput: ((String) -> Void)?
    var onWakeWord: (() -> Void)?
    var onPermissionResponse: ((Int) -> Void)?  // 0=allow once, 1+=suggestion index, -1=deny

    /// Which audio device path is active.
    enum AudioPath {
        case local          // Mac system mic + speakers (default fallback)
        case teensy         // Teensy UAC — STTEngine + TTSEngine via CoreAudio
        case esp32Serial    // ESP32 — SerialMicEngine + SerialTTSEngine via binary frames
    }

    // Components — Teensy/local path (always available)
    private let stt: STTEngine
    private let tts: TTSEngine
    private var wakeWordProcessor = WakeWordProcessor()
    private var permissionGate = PermissionVoiceGate()
    private let deviceListener = AudioDeviceDiscovery.DeviceChangeListener()

    // Components — ESP32 serial path (created when transport is set)
    private var serialMic: SerialMicEngine?
    private var serialTTS: SerialTTSEngine?
    private weak var serialTransport: SerialTransport?

    // Track which path is active
    private var audioPath: AudioPath = .local

    // Timers
    private var voiceInputTimer: Task<Void, Never>?
    private var deviceCheckTask: Task<Void, Never>?

    // Log file — in Application Support (sandbox-safe)
    private let logURL: URL = {
        return DuckConfig.storageDir.appendingPathComponent("speech.log")
    }()

    init() {
        stt = STTEngine()
        tts = TTSEngine()

        // Sync persisted voice to TTSEngine (didSet doesn't fire on init)
        tts.voice = ttsVoice

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

        // Watch for USB audio device plug/unplug.
        // CoreAudio fires multiple callbacks per plug event (one per endpoint),
        // so we debounce to let enumeration settle before checking state.
        deviceListener.onChange = { [weak self] in
            Task { @MainActor in
                self?.scheduleDeviceCheck()
            }
        }
        deviceListener.start()
    }

    // MARK: - Serial Transport (ESP32 audio path)

    /// Set the serial transport for ESP32 binary audio I/O.
    /// Creates SerialTTSEngine and SerialMicEngine instances.
    func setSerialTransport(_ transport: SerialTransport) {
        self.serialTransport = transport

        let logFn: (String) -> Void = { [weak self] msg in self?.log(msg) }

        // Create serial TTS engine
        let sTTS = SerialTTSEngine(transport: transport)
        sTTS.voice = ttsVoice
        sTTS.log = logFn
        self.serialTTS = sTTS

        // Create serial mic engine — wire transcripts to same pipeline
        let sMic = SerialMicEngine(transport: transport)
        sMic.log = logFn
        sMic.onTranscript = { [weak self] transcript, isFinal in
            Task { @MainActor in
                self?.processTranscript(transcript, isFinal: isFinal)
            }
        }
        // Share the serial TTS gate with serial mic so mic mutes during playback
        sMic.setTTSGate(sTTS.gate)
        self.serialMic = sMic

        log("[speech] Serial audio engines created for ESP32")
    }

    /// Called when the serial device connects, disconnects, or identifies itself.
    /// Switches audio path based on what's connected.
    func handleSerialDeviceChange() {
        guard let transport = serialTransport else { return }

        if transport.isESP32 {
            switchAudioPath(.esp32Serial)
        } else if transport.isConnected {
            // Serial device connected but not ESP32 (e.g. Teensy) — let CoreAudio handle it
            // Teensy audio is detected via CoreAudio device change, not serial identity
            log("[speech] Serial device connected: \(transport.connectedBoard ?? "unknown") — using CoreAudio path")
        } else {
            // Serial disconnected — if we were on ESP32, fall back
            if audioPath == .esp32Serial {
                switchAudioPath(.local)
            }
        }
    }

    /// Switch to a new audio path, restarting listening if needed.
    private func switchAudioPath(_ newPath: AudioPath) {
        guard newPath != audioPath else { return }
        let wasListening = isListening

        log("[speech] Switching audio path: \(audioPath) → \(newPath)")

        // Stop the current path
        stopListening()

        audioPath = newPath

        // Restart on the new path if we were listening
        if wasListening {
            startListening()
        }
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

    /// Apply the current listen mode — start or stop the mic as needed.
    func applyListenMode() {
        switch listenMode {
        case .off:
            if isListening { stopListening() }
            log("[speech] Listen mode: Off")
        case .permissionsOnly:
            if !isListening { startListening() }
            log("[speech] Listen mode: Permissions Only")
        case .active:
            if !isListening { startListening() }
            log("[speech] Listen mode: Active (wake word)")
        }
    }

    func startListening() {
        guard micPermissionGranted && speechPermissionGranted else {
            log("[speech] Missing permissions (mic=\(micPermissionGranted), speech=\(speechPermissionGranted))")
            lastError = "Missing permissions"
            return
        }

        switch audioPath {
        case .esp32Serial:
            guard let mic = serialMic else {
                log("[speech] Serial mic engine not available")
                return
            }
            mic.start()
            isListening = mic.isListening
        case .teensy, .local:
            stt.start()
            isListening = stt.isListening
        }

        if isListening {
            log("[speech] Listening via \(audioPath) for \"\(wakeWord)\"...")
        }
    }

    func stopListening() {
        switch audioPath {
        case .esp32Serial:
            serialMic?.stop()
        case .teensy, .local:
            stt.stop()
        }
        isListening = false
    }

    func speak(_ text: String, skipChirpWait: Bool = false) {
        switch audioPath {
        case .esp32Serial:
            serialTTS?.speak(text, skipChirpWait: skipChirpWait)
        case .teensy, .local:
            tts.speak(text)
        }
    }

    func stopSpeaking() {
        switch audioPath {
        case .esp32Serial:
            serialTTS?.stop()
        case .teensy, .local:
            tts.stop()
        }
    }

    func askPermission(toolName: String, summary: String = "", options: [String] = []) {
        let label = summary.isEmpty ? toolName : summary
        let prompt = "\(label). Allow?"
        permissionGate.startWaiting(optionCount: options.count, prompt: prompt)
        speak(prompt)
    }

    /// Clear the voice permission gate (permission resolved externally — CLI, timeout, etc.)
    func clearPermissionGate() {
        permissionGate.reset()
    }

    static func listMicrophones() -> [(index: Int, name: String)] {
        AudioDeviceDiscovery.listMicrophones()
    }

    // MARK: - Mic Selection

    private func selectMicrophone() {
        // ESP32 serial path doesn't use CoreAudio — skip mic selection
        if audioPath == .esp32Serial {
            selectedMicName = "ESP32 Serial Mic"
            log("[speech] Using ESP32 serial mic — no CoreAudio mic needed")
            return
        }

        guard let mic = AudioDeviceDiscovery.selectMicrophone() else {
            log("[speech] No microphone found!")
            lastError = "No microphone found"
            return
        }

        selectedMicName = mic.name
        log("[speech] Selected \(mic.isTeensy ? "Teensy" : "default") mic: \(mic.name)")

        if mic.isTeensy {
            audioPath = .teensy
            // Find Teensy in CoreAudio and configure both STT input and TTS output
            if let teensy = AudioDeviceDiscovery.findTeensy() {
                stt.setTeensyDevice(teensy.deviceID)
                tts.outputDeviceName = teensy.name
                log("[tts] Will route TTS to Teensy via `say -a \"\(teensy.name)\"`")
            }
        } else {
            audioPath = .local
            // Ensure STT/TTS use system defaults
            stt.clearTeensyDevice()
            tts.outputDeviceName = nil
        }
    }

    // MARK: - Device Hot-Plug

    /// Debounce CoreAudio device-change callbacks.
    /// USB enumeration fires multiple notifications (one per endpoint);
    /// waiting 500ms lets the system settle so `findTeensy()` returns
    /// a stable result instead of a momentary nil mid-enumeration.
    private func scheduleDeviceCheck() {
        deviceCheckTask?.cancel()
        deviceCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            if !Task.isCancelled {
                self.handleDeviceChange()
            }
        }
    }

    /// Called after debounce when CoreAudio devices change (USB plug/unplug).
    /// Re-selects mic/TTS and restarts listening if the device changed.
    /// Note: ESP32 doesn't appear in CoreAudio — its changes come via handleSerialDeviceChange().
    private func handleDeviceChange() {
        // Don't let CoreAudio changes override the ESP32 serial path
        if audioPath == .esp32Serial { return }

        let wasTeensy = audioPath == .teensy
        let teensyNow = AudioDeviceDiscovery.findTeensy() != nil

        if wasTeensy && !teensyNow {
            // Teensy unplugged — switch to local audio
            log("[speech] Teensy unplugged — switching to local mic + speakers")
            stt.clearTeensyDevice()
            tts.outputDeviceName = nil
            selectMicrophone()

            // Restart listening on the new device
            if isListening {
                stopListening()
                stt.resetRestartAttempts()
                startListening()
            }
        } else if !wasTeensy && teensyNow {
            // Teensy plugged in — switch to Teensy audio
            log("[speech] Teensy plugged in — switching to Teensy mic + speaker")
            selectMicrophone()

            // Restart listening on Teensy
            if isListening {
                stopListening()
                stt.resetRestartAttempts()
                startListening()
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
                speak(["Got it.", "Done.", "Approved.", "Yep.", "Go for it."].randomElement()!)
                onPermissionResponse?(0)
            case .deny:
                speak(["Blocked it.", "Nope.", "Denied.", "Not happening."].randomElement()!)
                onPermissionResponse?(-1)
            case .selectOption(let index):
                speak(["Got it, option \(index).", "Going with \(index).", "Option \(index) it is."].randomElement()!)
                onPermissionResponse?(index)
            case .repeatPrompt:
                speak(permissionGate.lastPrompt)
            case .noMatch:
                break
            }
            return
        }

        // Wake word + command processing (only in active mode)
        guard listenMode == .active else { return }
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
                    self.speak(["Hmm?", "Yeah?", "What's up?", "I'm here."].randomElement()!)
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
        speak(["On it.", "Sure thing.", "You got it.", "Working on it."].randomElement()!)
        onVoiceInput?(text)

        // Clear the displayed text after a beat so user sees it was sent
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.lastHeard = ""
        }

        restartAfterTTS()
    }

    private func restartAfterTTS() {
        Task {
            // Wait for whichever TTS engine is active to finish
            switch audioPath {
            case .esp32Serial:
                while serialTTS?.isMuted == true {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                serialMic?.resetRestartAttempts()
            case .teensy, .local:
                while tts.isMuted {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                stt.resetRestartAttempts()
            }
            self.startListening()
        }
    }

    private func restartListening() {
        stopListening()
        switch audioPath {
        case .esp32Serial:
            serialMic?.restart()
            isListening = serialMic?.isListening ?? false
        case .teensy, .local:
            stt.restart()
            isListening = stt.isListening
        }
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
