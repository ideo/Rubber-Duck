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

enum SpeechLane: Int {
    case critical = 0
    case script = 1
    case turn = 2
    case manual = 3
    case ambient = 4
}

enum SpeechKind {
    case permission
    case answer
    case filler
    case acknowledgement
    case reaction
    case greeting
    case preview
    case scriptStep
    case system
}

enum SpeechPolicy {
    case fifo
    case latestWins
    case replaceScope
    case dropIfBusy
    case exclusiveSession
}

enum SpeechInterruptibility {
    case byCriticalOnly
    case byUserAction
    case freelyInterruptible
}

private struct ScheduledSpeech {
    let id: UUID
    let text: String
    let lane: SpeechLane
    let kind: SpeechKind
    let scopeID: String?
    let policy: SpeechPolicy
    let interruptibility: SpeechInterruptibility
    let skipChirpWait: Bool
    let onFinish: (@MainActor () -> Void)?
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
    @Published private(set) var audioPath: AudioPath = .local

    // Timers
    private var voiceInputTimer: Task<Void, Never>?
    private var deviceCheckTask: Task<Void, Never>?
    private var utteranceClearTimer: Task<Void, Never>?
    private var simulatedSpeechTask: Task<Void, Never>?

    // Speech scheduling
    private var activeSpeech: ScheduledSpeech?
    private var activePlaybackBackend: (any TTSBackend)?
    private var criticalQueue: [ScheduledSpeech] = []
    private var scriptQueue: [ScheduledSpeech] = []
    private var pendingTurnSpeech: ScheduledSpeech?
    private var pendingManualSpeech: ScheduledSpeech?
    private var pendingAmbientSpeech: ScheduledSpeech?
    private var turnCounter: Int = 0
    private var scriptCounter: Int = 0
    private(set) var currentTurnScopeID: String?

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

        // Swap active backends + update displayed mic name
        switch newPath {
        case .esp32Serial:
            if let mic = serialMic { activeSTT = mic }
            if let ttsEngine = serialTTS { activeTTS = ttsEngine }
            selectedMicName = serialTransport?.displayName ?? "Duck, Duck, Duck"
        case .teensy:
            activeSTT = stt
            activeTTS = tts
            if let device = AudioDeviceDiscovery.findDuckDevice() {
                selectedMicName = device.name
            }
        case .local:
            activeSTT = stt
            activeTTS = tts
            selectMicrophone()
        }

        // Restart on the new path if we were listening
        if wasListening {
            startListening()
        }
    }

    // MARK: - Public API

    /// Re-check current permission state without triggering dialogs.
    /// Call this when the menu opens or app returns to foreground to catch
    /// permissions toggled in System Settings while the app was running.
    func refreshPermissionStatus() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        micPermissionGranted = (micStatus == .authorized)

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        speechPermissionGranted = (speechStatus == .authorized)
    }

    func requestPermissions() {
        log("[speech] Requesting permissions (mic first, then speech)...")

        // Check current status first — skip prompts for already-decided permissions.
        // This avoids redundant dialogs after System Settings toggles or dev rebuilds.
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        if micStatus == .authorized && speechStatus == .authorized {
            log("[speech] Both permissions already granted — skipping dialogs")
            micPermissionGranted = true
            speechPermissionGranted = true
            selectMicrophone()
            startListeningIfReady()
            return
        }

        // Request mic FIRST — it's the critical one. macOS won't show two dialogs at once,
        // so we chain them: mic → speech. Mic prompt must appear.
        if micStatus == .notDetermined {
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
                    self.requestSpeechPermission()
                }
            }
        } else {
            micPermissionGranted = (micStatus == .authorized)
            if micPermissionGranted { selectMicrophone() }
            else { lastError = "Microphone access denied" }
            requestSpeechPermission()
        }
    }

    /// Request speech recognition permission (or skip if already decided).
    private func requestSpeechPermission() {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
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
        } else {
            speechPermissionGranted = (status == .authorized)
            if status != .authorized { lastError = "Speech recognition not authorized" }
            startListeningIfReady()
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
        guard AppDelegate.isDuckActive else {
            log("[speech] Skipping startListening — duck is paused")
            return
        }
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

    func speak(_ text: String, skipChirpWait: Bool = false) {
        scheduleSpeech(
            text,
            kind: .system,
            lane: .manual,
            policy: .latestWins,
            interruptibility: .freelyInterruptible,
            skipChirpWait: skipChirpWait
        )
    }

    func scheduleSpeech(
        _ text: String,
        kind: SpeechKind,
        lane: SpeechLane,
        scopeID: String? = nil,
        policy: SpeechPolicy,
        interruptibility: SpeechInterruptibility,
        skipChirpWait: Bool = false,
        onFinish: (@MainActor () -> Void)? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let speech = ScheduledSpeech(
            id: UUID(),
            text: trimmed,
            lane: lane,
            kind: kind,
            scopeID: scopeID,
            policy: policy,
            interruptibility: interruptibility,
            skipChirpWait: skipChirpWait,
            onFinish: onFinish
        )
        enqueueSpeech(speech)
    }

    func nextTurnScopeID() -> String {
        turnCounter += 1
        return "turn-\(turnCounter)"
    }

    func nextScriptScopeID(prefix: String = "script") -> String {
        scriptCounter += 1
        return "\(prefix)-\(scriptCounter)"
    }

    func scheduleScript(
        texts: [String],
        scopeID: String? = nil,
        interruptibility: SpeechInterruptibility = .byUserAction
    ) {
        let cleaned = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }

        let scriptID = scopeID ?? nextScriptScopeID()
        scriptQueue.removeAll()
        pendingTurnSpeech = nil
        pendingManualSpeech = nil
        pendingAmbientSpeech = nil
        if let activeSpeech,
           activeSpeech.lane == .script
            || activeSpeech.lane == .ambient
            || activeSpeech.lane == .manual
            || activeSpeech.interruptibility == .byUserAction {
            replaceActiveSpeechIfNeeded()
        }

        for (index, text) in cleaned.enumerated() {
            let speech = ScheduledSpeech(
                id: UUID(),
                text: text,
                lane: .script,
                kind: .scriptStep,
                scopeID: scriptID,
                policy: index == 0 ? .exclusiveSession : .fifo,
                interruptibility: interruptibility,
                skipChirpWait: false,
                onFinish: nil
            )
            scriptQueue.append(speech)
        }
        scheduleNextSpeechIfNeeded()
    }

    func stopSpeaking(reason: TTSStopReason = .userCancelled, clearQueues: Bool = true) {
        simulatedSpeechTask?.cancel()
        simulatedSpeechTask = nil
        utteranceClearTimer?.cancel()
        utteranceClearTimer = nil

        if clearQueues {
            clearNonCriticalQueuedSpeech()
        }

        if let backend = activePlaybackBackend {
            backend.stopPlayback(reason: reason)
        }

        activeSpeech = nil
        activePlaybackBackend = nil
        isSpeaking = false
        currentUtterance = ""
        currentTurnScopeID = nil
        exitConversation()
    }

    private func enqueueSpeech(_ speech: ScheduledSpeech) {
        if speech.policy == .dropIfBusy,
           activeSpeech != nil || !criticalQueue.isEmpty || !scriptQueue.isEmpty || pendingTurnSpeech != nil || pendingManualSpeech != nil {
            return
        }

        if speech.lane != .ambient {
            pendingAmbientSpeech = nil
        }

        switch speech.lane {
        case .critical:
            criticalQueue.append(speech)
        case .script:
            if speech.policy == .exclusiveSession {
                scriptQueue.removeAll()
            }
            scriptQueue.append(speech)
        case .turn:
            pendingTurnSpeech = speech
        case .manual:
            pendingManualSpeech = speech
        case .ambient:
            pendingAmbientSpeech = speech
        }

        if shouldPreemptActiveSpeech(for: speech) {
            replaceActiveSpeechIfNeeded()
        }
        scheduleNextSpeechIfNeeded()
    }

    private func shouldPreemptActiveSpeech(for incoming: ScheduledSpeech) -> Bool {
        guard let activeSpeech else { return false }

        switch incoming.lane {
        case .critical:
            return activeSpeech.lane != .critical
        case .script:
            return activeSpeech.lane == .ambient
                || activeSpeech.lane == .manual
                || activeSpeech.interruptibility == .byUserAction
        case .turn:
            if activeSpeech.lane == .turn, activeSpeech.scopeID == incoming.scopeID {
                return true
            }
            return activeSpeech.lane == .ambient
        case .manual:
            if activeSpeech.lane == .manual || activeSpeech.lane == .ambient {
                return true
            }
            return activeSpeech.interruptibility == .byUserAction
        case .ambient:
            return false
        }
    }

    private func replaceActiveSpeechIfNeeded() {
        guard activeSpeech != nil else { return }
        simulatedSpeechTask?.cancel()
        simulatedSpeechTask = nil
        utteranceClearTimer?.cancel()
        utteranceClearTimer = nil
        activePlaybackBackend?.stopPlayback(reason: .replaced)
        activeSpeech = nil
        activePlaybackBackend = nil
        isSpeaking = false
    }

    private func scheduleNextSpeechIfNeeded() {
        guard activeSpeech == nil else { return }

        let next: ScheduledSpeech?
        if !criticalQueue.isEmpty {
            next = criticalQueue.removeFirst()
        } else if !scriptQueue.isEmpty {
            next = scriptQueue.removeFirst()
        } else if let pendingTurnSpeech {
            next = pendingTurnSpeech
            self.pendingTurnSpeech = nil
        } else if let pendingManualSpeech {
            next = pendingManualSpeech
            self.pendingManualSpeech = nil
        } else if let pendingAmbientSpeech {
            next = pendingAmbientSpeech
            self.pendingAmbientSpeech = nil
        } else {
            next = nil
        }

        guard let next else { return }
        startSpeech(next)
    }

    private func startSpeech(_ speech: ScheduledSpeech) {
        activeSpeech = speech
        currentUtterance = speech.text
        isSpeaking = true

        let systemMuted = audioPath == .local && AudioDeviceDiscovery.isSystemOutputMuted()
        if isSilent || systemMuted {
            let duration = estimatedSpeechDuration(for: speech.text)
            simulatedSpeechTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.handleSpeechCompletion(for: speech.id, result: .finished)
                    }
                }
            }
            return
        }

        let playbackBackend = activeTTS
        activePlaybackBackend = playbackBackend
        playbackBackend.play(
            speech.text,
            utteranceID: speech.id,
            skipChirpWait: speech.skipChirpWait
        ) { [weak self] utteranceID, result in
            self?.handleSpeechCompletion(for: utteranceID, result: result)
        }
    }

    private func handleSpeechCompletion(for utteranceID: UUID, result: TTSPlaybackResult) {
        guard activeSpeech?.id == utteranceID else { return }

        simulatedSpeechTask?.cancel()
        simulatedSpeechTask = nil
        utteranceClearTimer?.cancel()
        utteranceClearTimer = nil

        let completion = activeSpeech?.onFinish
        let finishedLane = activeSpeech?.lane
        activeSpeech = nil
        activePlaybackBackend = nil
        isSpeaking = false
        currentUtterance = ""
        if finishedLane == .turn && pendingTurnSpeech == nil {
            currentTurnScopeID = nil
        }

        if case .finished = result {
            completion?()
        }

        scheduleNextSpeechIfNeeded()
    }

    private func estimatedSpeechDuration(for text: String) -> Double {
        2.0 + Double(text.count) * 0.05
    }

    func makeListeningCompletionAction(enterConversation: Bool = false) -> (@MainActor () -> Void) {
        { [weak self] in
            guard let self else { return }
            self.activeSTT.resetRestartAttempts()
            self.startListening()
            if enterConversation {
                self.enterConversation()
            }
        }
    }

    private func clearNonCriticalQueuedSpeech() {
        scriptQueue.removeAll()
        pendingTurnSpeech = nil
        pendingManualSpeech = nil
        pendingAmbientSpeech = nil
        currentTurnScopeID = nil
    }

    /// Set master volume (0.0–1.0). Propagates to both TTS engines.
    func setVolume(_ volume: Float) {
        tts.volume = volume
        serialTTS?.volume = volume
    }

    func askPermission(toolName: String, summary: String = "", options: [String] = []) {
        let label = summary.isEmpty ? toolName : summary

        // Use STT-friendly words: "yes/no/always" instead of "allow/deny"
        // which Apple Speech frequently misrecognizes as "a lot", "aloud", etc.
        let shortPrompt: String
        let fullPrompt: String

        if options.count == 1 {
            shortPrompt = "\(label). Yes, always, or no?"
            fullPrompt = "\(label). Yes, always to \(options[0]), or no?"
        } else if options.count == 2 {
            shortPrompt = "\(label). Yes, always, or no?"
            fullPrompt = "\(label). Yes, always to \(options[0]), or say second to \(options[1]), or no?"
        } else if options.count > 2 {
            shortPrompt = "\(label). Yes or no? Say repeat for options."
            let numbered = options.enumerated().map { "\($0.offset + 1): \($0.element)" }.joined(separator: ". ")
            fullPrompt = "\(label). Your options are: \(numbered). Or just yes or no."
        } else {
            // No options
            shortPrompt = "\(label). Yes or no?"
            fullPrompt = shortPrompt
        }

        permissionGate.startWaiting(
            optionCount: options.count,
            optionLabels: options,
            prompt: shortPrompt,
            fullPrompt: fullPrompt
        )
        scheduleSpeech(
            shortPrompt,
            kind: .permission,
            lane: .critical,
            scopeID: "permission-active",
            policy: .fifo,
            interruptibility: .byCriticalOnly,
            onFinish: makeListeningCompletionAction()
        )
    }

    /// Clear the voice permission gate (permission resolved externally — CLI, timeout, etc.)
    func clearPermissionGate() {
        permissionGate.reset()
    }

    static func listMicrophones() -> [(index: Int, name: String)] {
        AudioDeviceDiscovery.listMicrophones()
    }

    // MARK: - Mic Selection

    /// Re-select the system default microphone (called from Preferences picker).
    func selectDefaultMicrophone() {
        selectMicrophone()
    }

    /// Select a specific microphone by name (called from Preferences picker).
    func selectMicrophone(byName name: String) {
        let mics = AudioDeviceDiscovery.listMicrophones()
        guard let mic = mics.first(where: { $0.name == name }) else {
            log("[speech] Mic '\(name)' not found — falling back to default")
            selectMicrophone()
            return
        }
        selectedMicName = mic.name
        audioPath = .local
        stt.clearTeensyDevice()
        tts.outputDeviceName = nil
        log("[speech] User selected mic: \(mic.name)")
    }

    private func selectMicrophone() {
        // ESP32-C3 serial path doesn't use CoreAudio — skip mic selection
        if audioPath == .esp32Serial {
            selectedMicName = serialTransport?.displayName ?? "Duck, Duck, Duck"
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
        // Permission mode takes priority — but ignore transcripts while TTS is
        // playing to prevent the mic from picking up the duck's own speech and
        // accidentally approving permissions.
        if permissionGate.isWaiting && !isSpeaking {
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
                                self.scheduleSpeech(
                                    "Didn't catch that. Yes or no?",
                                    kind: .permission,
                                    lane: .critical,
                                    scopeID: "permission-active",
                                    policy: .fifo,
                                    interruptibility: .byCriticalOnly,
                                    onFinish: self.makeListeningCompletionAction()
                                )
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
            scheduleSpeech(
                ["Yeah?", "Hmm?", "Yep?", "What's up?"].randomElement()!,
                kind: .acknowledgement,
                lane: .turn,
                scopeID: "wake",
                policy: .latestWins,
                interruptibility: .freelyInterruptible,
                skipChirpWait: true
            )

            // Tell hardware to perk up (servo tilt)
            serialTransport?.sendCommand("W,1")

            // 5s timeout — if no command text, reset (longer now that we acknowledged)
            voiceInputTimer?.cancel()
            voiceInputTimer = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled && self.wakeWordProcessor.isAwake && self.wakeWordProcessor.pendingText.isEmpty {
                    self.log("[speech] No command after wake word, restarting...")
                    self.scheduleSpeech(
                        "Never mind.",
                        kind: .acknowledgement,
                        lane: .turn,
                        scopeID: "wake",
                        policy: .latestWins,
                        interruptibility: .freelyInterruptible
                    )
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
            scheduleSpeech(
                "Quack! See you later.",
                kind: .acknowledgement,
                lane: .turn,
                scopeID: "wake",
                policy: .latestWins,
                interruptibility: .freelyInterruptible,
                onFinish: makeListeningCompletionAction()
            )
        }
    }

    /// Handle a resolved permission decision (from word matching or LLM classifier).
    private func handlePermissionDecision(_ decision: PermissionVoiceGate.Decision) {
        switch decision {
        case .allow:
            scheduleSpeech(
                ["Got it.", "Done.", "Approved.", "Yep.", "Go for it."].randomElement()!,
                kind: .permission,
                lane: .critical,
                scopeID: "permission-active",
                policy: .fifo,
                interruptibility: .byCriticalOnly,
                onFinish: makeListeningCompletionAction()
            )
            onPermissionResponse?(0)
        case .deny:
            scheduleSpeech(
                ["Blocked it.", "Nope.", "Denied.", "Not happening."].randomElement()!,
                kind: .permission,
                lane: .critical,
                scopeID: "permission-active",
                policy: .fifo,
                interruptibility: .byCriticalOnly,
                onFinish: makeListeningCompletionAction()
            )
            onPermissionResponse?(-1)
        case .selectOption(let index):
            if index > 0 && index <= permissionGate.optionLabels.count {
                let label = permissionGate.optionLabels[index - 1]
                scheduleSpeech(
                    "Got it. \(label.capitalized(with: nil)).",
                    kind: .permission,
                    lane: .critical,
                    scopeID: "permission-active",
                    policy: .fifo,
                    interruptibility: .byCriticalOnly,
                    onFinish: makeListeningCompletionAction()
                )
            } else {
                scheduleSpeech(
                    ["Got it.", "Done."].randomElement()!,
                    kind: .permission,
                    lane: .critical,
                    scopeID: "permission-active",
                    policy: .fifo,
                    interruptibility: .byCriticalOnly,
                    onFinish: makeListeningCompletionAction()
                )
            }
            onPermissionResponse?(index)
        case .repeatPrompt:
            scheduleSpeech(
                permissionGate.fullPrompt,
                kind: .permission,
                lane: .critical,
                scopeID: "permission-active",
                policy: .fifo,
                interruptibility: .byCriticalOnly,
                onFinish: makeListeningCompletionAction()
            )
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
        currentTurnScopeID = nextTurnScopeID()
        // Don't schedule an acknowledgement here — the onVoiceInput callback
        // schedules its own filler ("Hmm...", "Let me think..."). Scheduling
        // both causes overlapping speech (two fillers playing simultaneously).
        onVoiceInput?(text)

        // Clear the displayed text after a beat so user sees it was sent
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.lastHeard = ""
        }
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
            // Wait for the currently active speech request to drain.
            while activeSpeech != nil {
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
