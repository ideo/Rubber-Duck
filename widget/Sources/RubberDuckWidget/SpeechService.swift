// Speech Service — Facade orchestrating STT, TTS, wake word, and permission voice gate.
//
// Delegates to focused components:
//   STTEngine — speech recognition via Apple Speech framework
//   TTSEngine — text-to-speech via macOS `say` command
//   WakeWordProcessor — "ducky" detection and command extraction
//   PermissionVoiceGate — yes/no/ordinal word matching
//   AudioDeviceDiscovery — CoreAudio device enumeration
//
// Logs to ~/Library/Application Support/DuckDuckDuck/DuckDuckDuck.log for debugging.

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
        case .active: return "Wake Word"
        }
    }

    /// SF Symbol name for this listen mode.
    var iconName: String {
        switch self {
        case .off: return "microphone.slash.fill"
        case .permissionsOnly: return "microphone.badge.xmark"
        case .active: return "microphone.fill"
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
    @Published var isWakeActive: Bool = false
    @Published var micPermissionGranted: Bool = false
    @Published var speechPermissionGranted: Bool = false
    @Published var selectedMicName: String = ""
    @Published var lastError: String = ""
    @Published var currentUtterance: String = ""
    @Published var isSpeaking: Bool = false

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
    @Published var ttsVoice: String = UserDefaults.standard.string(forKey: "duck_tts_voice") ?? DuckVoices.wildcardSayName {
        didSet {
            let engineVoice = DuckVoices.resolvedSayName(for: ttsVoice)
            tts.voice = engineVoice
            serialTTS?.voice = engineVoice
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
        // case duckUAC     // TBD: ESP32-S3 UAC — not yet working, shelved for now
        case esp32Serial    // ESP32-C3 — SerialMicEngine + SerialTTSEngine via binary frames
    }

    // Concrete engines (kept for device-specific operations like setTeensyDevice)
    private let stt: STTEngine
    private let tts: TTSEngine
    private var serialMic: SerialMicEngine?
    private var serialTTS: SerialTTSEngine?
    private weak var serialTransport: SerialTransport?

    // Active backend — protocol dispatch replaces per-method switch statements
    private var activeSTT: any STTBackend
    private var activeTTS: any TTSBackend

    private var wakeWordProcessor = WakeWordProcessor()
    private var hasAcknowledgedWake = false

    /// Conversation mode — after help answer, duck stays hot for follow-ups.
    /// No wake word needed while this is true. Resets after timeout.
    @Published var isInConversation = false
    private var conversationTimer: Task<Void, Never>?
    private var permissionGate = PermissionVoiceGate()
    private let permissionClassifier = PermissionClassifier()
    private let deviceListener = AudioDeviceDiscovery.DeviceChangeListener()

    // Track which path is active
    private(set) var audioPath: AudioPath = .local

    // Timers
    private var voiceInputTimer: Task<Void, Never>?
    private var deviceCheckTask: Task<Void, Never>?
    private var utteranceClearTimer: Task<Void, Never>?


    init() {
        stt = STTEngine()
        tts = TTSEngine()
        activeSTT = stt
        activeTTS = tts

        // Sync persisted voice to TTSEngine (didSet doesn't fire on init).
        tts.voice = DuckVoices.resolvedSayName(for: ttsVoice)

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

        // Create serial TTS engine — resolve wildcard sentinel to real voice name
        let sTTS = SerialTTSEngine(transport: transport)
        sTTS.voice = DuckVoices.resolvedSayName(for: ttsVoice)
        self.serialTTS = sTTS

        // Create serial mic engine — wire transcripts to same pipeline
        let sMic = SerialMicEngine(transport: transport)
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
    /// Switches audio path based on what's actually available:
    ///   - If a duck UAC device exists in CoreAudio → use CoreAudio path
    ///   - If ESP32 connected but no UAC device → use serial streaming
    ///   - Teensy: uses CoreAudio path (detected via CoreAudio device change)
    ///
    /// Note: We check for the actual UAC device in CoreAudio rather than
    /// inferring from chip identity, because an S3 might be running
    /// C3-style streaming firmware without UAC enabled.
    func handleSerialDeviceChange() {
        guard let transport = serialTransport else { return }

        if transport.isESP32 && transport.isConnected {
            // ESP32 connected — always use serial streaming.
            // UAC support is experimental and shelved for now.
            log("[speech] ESP32 connected (\(transport.connectedBoard ?? "?")) — using serial streaming")
            switchAudioPath(.esp32Serial)
        } else if transport.isConnected {
            // Teensy or unknown — let CoreAudio handle it
            log("[speech] Serial device connected: \(transport.connectedBoard ?? "unknown") — using CoreAudio path")
        } else {
            // Serial disconnected — fall back if on a serial-dependent path
            if audioPath == .esp32Serial {
                switchAudioPath(.local)
            }
        }
    }

    // TBD: scheduleESP32AudioCheck() — shelved until UAC firmware works.
    // Was: wait 1s after serial handshake, check CoreAudio for duck UAC device,
    // switch to duckUAC path if found, else fall back to serial streaming.

    /// Switch to a new audio path, swapping active backends and restarting listening.
    private func switchAudioPath(_ newPath: AudioPath) {
        guard newPath != audioPath else { return }
        let wasListening = isListening

        log("[speech] Switching audio path: \(audioPath) → \(newPath)")

        // Stop the current path
        stopListening()

        audioPath = newPath

        // Swap active backends
        switch newPath {
        case .esp32Serial:
            if let mic = serialMic { activeSTT = mic }
            if let ttsEngine = serialTTS { activeTTS = ttsEngine }
        case .teensy, .local:
            activeSTT = stt
            activeTTS = tts
        }

        // Restart on the new path if we were listening
        if wasListening {
            startListening()
        }
    }

    // MARK: - Public API

    func requestPermissions() {
        log("[speech] Requesting permissions (mic first, then speech)...")

        // Request mic FIRST — it's the critical one. macOS won't show two dialogs at once,
        // so we chain them: mic → speech. Mic prompt must appear.
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.micPermissionGranted = granted
                self.log("[speech] Mic permission: \(granted ? "granted" : "denied")")
                if granted {
                    self.selectMicrophone()
                } else {
                    self.lastError = "Microphone access denied"
                }

                // Now request speech recognition (after mic dialog is dismissed)
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    Task { @MainActor in
                        guard let self else { return }
                        self.speechPermissionGranted = (status == .authorized)
                        self.log("[speech] Speech auth status: \(status.rawValue) (\(status == .authorized ? "granted" : "denied"))")
                        if status != .authorized {
                            self.lastError = "Speech recognition not authorized"
                        }
                        self.startListeningIfReady()
                    }
                }
            }
        }
    }

    /// Start listening once both permissions are granted.
    private func startListeningIfReady() {
        guard micPermissionGranted && speechPermissionGranted else { return }
        if listenMode != .off && !isListening {
            applyListenMode()
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

        activeSTT.start()
        isListening = activeSTT.isListening

        if isListening {
            log("[speech] Listening via \(audioPath) for \"\(wakeWord)\"...")
        }
    }

    func stopListening() {
        activeSTT.stop()
        isListening = false
    }

    /// Whether the current voice is Silent (speech bubble only, no TTS).
    var isSilent: Bool { ttsVoice == DuckVoices.silentSayName }

    private var speakingPollTimer: Task<Void, Never>?

    func speak(_ text: String, skipChirpWait: Bool = false) {
        currentUtterance = text
        utteranceClearTimer?.cancel()
        utteranceClearTimer = Task {
            // Reading time: 2s base notice time + ~50ms per character (~200 WPM).
            // Matches comfortable reading pace with time to notice the bubble.
            let duration = 2.0 + Double(text.count) * 0.05
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run { self.currentUtterance = "" }
            }
        }
        // Skip TTS when Silent, or when Mac is muted with no hardware duck
        let systemMuted = audioPath == .local && AudioDeviceDiscovery.isSystemOutputMuted()
        if !isSilent && !systemMuted {
            isSpeaking = true
            activeTTS.speak(text, skipChirpWait: skipChirpWait)
            // Poll gate.muted to detect when say finishes
            speakingPollTimer?.cancel()
            speakingPollTimer = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    if !self.activeTTS.isMuted {
                        await MainActor.run { self.isSpeaking = false }
                        break
                    }
                }
            }
        } else if isSilent || systemMuted {
            // Mouth should still animate when showing speech bubble
            isSpeaking = true
            speakingPollTimer?.cancel()
            speakingPollTimer = Task {
                // Simulate speaking duration based on text length
                let duration = 2.0 + Double(text.count) * 0.05
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run { self.isSpeaking = false }
                }
            }
        }
    }

    func stopSpeaking() {
        activeTTS.stop()
        speakingPollTimer?.cancel()
        isSpeaking = false
        utteranceClearTimer?.cancel()
        currentUtterance = ""
    }

    /// Set master volume (0.0–1.0). Propagates to both TTS engines.
    func setVolume(_ volume: Float) {
        tts.volume = volume
        serialTTS?.volume = volume
    }

    func askPermission(toolName: String, summary: String = "", options: [String] = []) {
        let label = summary.isEmpty ? toolName : summary

        // One-sentence prompt: "Edit DuckView. Allow, always allow, or deny?"
        let shortPrompt: String
        let fullPrompt: String

        if options.count == 1 {
            // Single option → "Allow, always allow, or deny?"
            shortPrompt = "\(label). Allow, always allow, or deny?"
            fullPrompt = "\(label). Allow, always allow to \(options[0]), or deny?"
        } else if options.count == 2 {
            shortPrompt = "\(label). Allow, always allow, or deny?"
            fullPrompt = "\(label). Allow, always allow to \(options[0]), or say second to \(options[1]), or deny?"
        } else if options.count > 2 {
            shortPrompt = "\(label). Allow or deny? Say repeat for options."
            let numbered = options.enumerated().map { "\($0.offset + 1): \($0.element)" }.joined(separator: ". ")
            fullPrompt = "\(label). Your options are: \(numbered). Or just allow or deny."
        } else {
            // No options
            shortPrompt = "\(label). Allow or deny?"
            fullPrompt = shortPrompt
        }

        permissionGate.startWaiting(
            optionCount: options.count,
            optionLabels: options,
            prompt: shortPrompt,
            fullPrompt: fullPrompt
        )
        speak(shortPrompt)
        restartAfterTTS()  // Ensure STT is fresh after the prompt finishes
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
        // ESP32-C3 serial path doesn't use CoreAudio — skip mic selection
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

        if mic.isDuckDevice {
            // Found a duck UAC device — could be Teensy or ESP32-S3
            if let device = AudioDeviceDiscovery.findDuckDevice() {
                stt.setTeensyDevice(device.deviceID)
                tts.outputDeviceName = device.name
                tts.volume = DuckConfig.volume  // Apply persisted volume to device
                audioPath = .teensy  // TBD: distinguish Teensy vs S3 UAC when UAC works
                log("[speech] Selected duck UAC mic: \(device.name)")
                log("[tts] Will route TTS to \(device.name) via `say -a`")
            }
        } else {
            audioPath = .local
            // Ensure STT/TTS use system defaults
            stt.clearTeensyDevice()
            tts.outputDeviceName = nil
            log("[speech] Selected default mic: \(mic.name)")
        }
    }

    // MARK: - Device Hot-Plug

    /// Debounce CoreAudio device-change callbacks.
    /// USB enumeration fires multiple notifications (one per endpoint);
    /// waiting 500ms lets the system settle so `findDuckDevice()` returns
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
    /// Detects any duck UAC device (Teensy or ESP32-S3).
    /// Note: ESP32-C3 doesn't appear in CoreAudio — its changes come via handleSerialDeviceChange().
    private func handleDeviceChange() {
        // Don't let CoreAudio changes override the ESP32-C3 serial path
        if audioPath == .esp32Serial { return }

        let wasDuckUAC = (audioPath == .teensy)
        let duckNow = AudioDeviceDiscovery.findDuckDevice()

        if wasDuckUAC && duckNow == nil {
            // Duck UAC device unplugged — switch to local audio
            log("[speech] Duck UAC device unplugged — switching to local mic + speakers")
            stt.clearTeensyDevice()
            tts.outputDeviceName = nil
            selectMicrophone()

            if isListening {
                stopListening()
                stt.resetRestartAttempts()
                startListening()
            }
        } else if !wasDuckUAC && duckNow != nil {
            // Duck UAC device plugged in — switch to it
            let label = duckNow!.isTeensy ? "Teensy" : "duck UAC (\(duckNow!.name))"
            log("[speech] \(label) plugged in — switching audio")
            selectMicrophone()

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
            if case .noMatch = decision {
                // Final transcript with no keyword match → try Foundation Models classifier
                if isFinal && PermissionClassifier.isAvailable {
                    let labels = permissionGate.optionLabels
                    Task { [weak self] in
                        guard let self else { return }
                        let classified = await self.permissionClassifier.classify(
                            transcript: transcript,
                            optionLabels: labels
                        )
                        await MainActor.run {
                            guard self.permissionGate.isWaiting else { return }
                            guard let decision = classified else {
                                self.speak("Sorry, I didn't catch that. Say yes or no.")
                                self.restartAfterTTS()
                                return
                            }
                            self.handlePermissionDecision(decision)
                        }
                    }
                }
            } else {
                handlePermissionDecision(decision)
            }
            return
        }

        // Wake word + command processing (only in active mode)
        guard listenMode == .active else { return }

        // Conversation mode — hot mic, no wake word needed
        if isInConversation {
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            lastHeard = trimmed
            // Reset conversation timeout — they're still talking
            conversationTimer?.cancel()

            if isFinal {
                voiceInputTimer?.cancel()
                sendVoiceCommand(trimmed)
            } else {
                // Debounce: 2s of silence → treat partial as final
                voiceInputTimer?.cancel()
                voiceInputTimer = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !Task.isCancelled && self.isInConversation {
                        self.sendVoiceCommand(trimmed)
                    }
                }
            }
            return
        }

        let result = wakeWordProcessor.process(transcript, isFinal: isFinal)
        switch result {
        case .nothing:
            break

        case .wakeWordOnly:
            lastHeard = ""
            isWakeActive = true
            onWakeWord?()
            log("[speech] Wake word detected!")

            // Immediate acknowledgment — duck perks up (skip chirp for speed)
            speak(["Yeah?", "Hmm?", "Yep?", "What's up?"].randomElement()!, skipChirpWait: true)

            // Tell hardware to perk up (servo tilt)
            serialTransport?.sendCommand("W,1")

            // 5s timeout — if no command text, reset (longer now that we acknowledged)
            voiceInputTimer?.cancel()
            voiceInputTimer = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled && self.wakeWordProcessor.isAwake && self.wakeWordProcessor.pendingText.isEmpty {
                    self.log("[speech] No command after wake word, restarting...")
                    self.speak("Never mind.")
                    self.isWakeActive = false
                    self.hasAcknowledgedWake = false
                    self.serialTransport?.sendCommand("W,0")
                    self.wakeWordProcessor.reset()
                    self.lastHeard = ""
                    self.activeSTT.resetRestartAttempts()
                    self.restartListening()
                }
            }

        case .command(let text):
            lastHeard = text
            voiceInputTimer?.cancel()

            // First command after wake — visual acknowledge
            if !hasAcknowledgedWake {
                hasAcknowledgedWake = true
                isWakeActive = true
                serialTransport?.sendCommand("W,1")
            }

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

    /// Handle a resolved permission decision (from word matching or LLM classifier).
    private func handlePermissionDecision(_ decision: PermissionVoiceGate.Decision) {
        switch decision {
        case .allow:
            speak(["Got it.", "Done.", "Approved.", "Yep.", "Go for it."].randomElement()!)
            onPermissionResponse?(0)
            restartAfterTTS()
        case .deny:
            speak(["Blocked it.", "Nope.", "Denied.", "Not happening."].randomElement()!)
            onPermissionResponse?(-1)
            restartAfterTTS()
        case .selectOption(let index):
            if index > 0 && index <= permissionGate.optionLabels.count {
                let label = permissionGate.optionLabels[index - 1]
                speak("Got it. \(label.capitalized(with: nil)).")
            } else {
                speak(["Got it.", "Done."].randomElement()!)
            }
            onPermissionResponse?(index)
            restartAfterTTS()
        case .repeatPrompt:
            speak(permissionGate.fullPrompt)
            restartAfterTTS()
        case .noMatch:
            break  // Should not reach here
        }
    }

    private func sendVoiceCommand(_ text: String) {
        // Kill current recognition FIRST to prevent double-send
        wakeWordProcessor.reset()
        hasAcknowledgedWake = false
        isWakeActive = false
        voiceInputTimer?.cancel()
        stopListening()

        // Reset hardware attention state
        serialTransport?.sendCommand("W,0")

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

    // MARK: - Conversation Mode

    /// Enter conversation mode — hot mic, no wake word needed for follow-ups.
    func enterConversation() {
        isInConversation = true
        lastHeard = ""
        conversationTimer?.cancel()
        conversationTimer = Task {
            // Stay in conversation for 8s after TTS finishes
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if !Task.isCancelled {
                self.exitConversation()
            }
        }
        log("[speech] Entered conversation mode (8s timeout)")
    }

    /// Exit conversation mode — back to wake word listening.
    func exitConversation() {
        guard isInConversation else { return }
        isInConversation = false
        isWakeActive = false
        lastHeard = ""
        conversationTimer?.cancel()
        conversationTimer = nil
        wakeWordProcessor.reset()
        log("[speech] Exited conversation mode")
    }

    func restartAfterTTS(thenEnterConversation: Bool = false) {
        Task {
            // Wait for the active TTS engine to finish
            while activeTTS.isMuted {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            activeSTT.resetRestartAttempts()
            self.startListening()
            if thenEnterConversation {
                self.enterConversation()
            }
        }
    }

    private func restartListening() {
        stopListening()
        activeSTT.restart()
        isListening = activeSTT.isListening
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        DuckLog.log(msg)
    }
}
