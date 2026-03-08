// Speech Service — STT via Apple Speech framework + TTS via macOS `say` command.
//
// Handles wake word detection ("ducky"), voice-to-text transcription,
// and text-to-speech output (Boing voice). Auto-detects Teensy mic
// if available, falls back to system default.
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
    var wakeWord: String = "ducky"
    var ttsVoice: String = "Boing"

    // Callbacks
    var onVoiceInput: ((String) -> Void)?
    var onWakeWord: (() -> Void)?
    var onPermissionResponse: ((Int) -> Void)?  // 0=allow once, 1+=suggestion index, -1=deny

    // Private
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isWaitingForPermissionResponse = false
    private var permissionOptionCount = 0
    private var lastPermissionPrompt = ""
    private var pendingTranscript = ""
    private var restartAttempts = 0
    private let maxRestartAttempts = 5
    private var wakeWordDetected = false
    private var voiceInputTimer: Task<Void, Never>?

    // Log file
    private let logURL: URL = {
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("RubberDuck.log")
    }()

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

    // MARK: - Setup

    func requestPermissions() {
        log("[speech] Requesting speech recognition permission...")

        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }
                self.speechPermissionGranted = (status == .authorized)
                self.log("[speech] Speech auth status: \(status.rawValue) (\(status == .authorized ? "granted" : "denied"))")

                if status != .authorized {
                    self.lastError = "Speech recognition not authorized"
                    return
                }

                // Also request mic permission via AVCaptureDevice
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

    private func selectMicrophone() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices

        log("[speech] Found \(devices.count) mic(s): \(devices.map { $0.localizedName })")

        // Prefer Teensy
        if let teensy = devices.first(where: { $0.localizedName.lowercased().contains("teensy") }) {
            selectedMicName = teensy.localizedName
            log("[speech] Selected Teensy mic: \(teensy.localizedName)")
            return
        }

        // Fall back to default
        if let defaultMic = AVCaptureDevice.default(for: .audio) {
            selectedMicName = defaultMic.localizedName
            log("[speech] Selected default mic: \(defaultMic.localizedName)")
        } else {
            log("[speech] No microphone found!")
            lastError = "No microphone found"
        }
    }

    // MARK: - Listening

    func startListening() {
        guard micPermissionGranted && speechPermissionGranted else {
            log("[speech] Missing permissions (mic=\(micPermissionGranted), speech=\(speechPermissionGranted))")
            lastError = "Missing permissions"
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            log("[speech] Speech recognizer unavailable")
            lastError = "Speech recognizer unavailable"
            return
        }

        // Cancel any existing task
        stopListening()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            log("[speech] Failed to create recognition request")
            return
        }

        request.shouldReportPartialResults = true
        // Don't require on-device — let the system decide
        // requiresOnDeviceRecognition can cause immediate failure if models aren't downloaded

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        log("[speech] Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch")

        guard recordingFormat.sampleRate > 0 else {
            log("[speech] Invalid audio format (0 sample rate). Check mic connection.")
            lastError = "Invalid audio format"
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.processTranscript(transcript, isFinal: result.isFinal)

                    if result.isFinal {
                        self.log("[speech] Final result, restarting...")
                        self.restartAttempts = 0
                        self.wakeWordDetected = false
                        self.restartListening()
                    }
                }

                if let error = error {
                    self.log("[speech] Recognition error: \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                    self.wakeWordDetected = false
                    self.restartListening()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            restartAttempts = 0
            log("[speech] Listening for \"\(wakeWord)\"...")
        } catch {
            log("[speech] Audio engine failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isListening = false
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    private func restartListening() {
        stopListening()

        restartAttempts += 1
        if restartAttempts > maxRestartAttempts {
            log("[speech] Too many restart attempts (\(restartAttempts)). Giving up.")
            lastError = "Recognition keeps failing. Try Start Listening from context menu."
            return
        }

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = UInt64(pow(2.0, Double(restartAttempts - 1))) * 1_000_000_000
        log("[speech] Restarting in \(restartAttempts)s (attempt \(restartAttempts)/\(maxRestartAttempts))...")

        Task {
            try? await Task.sleep(nanoseconds: delay)
            if !self.isListening {
                self.startListening()
            }
        }
    }

    // MARK: - Transcript Processing

    private func processTranscript(_ transcript: String, isFinal: Bool) {
        let lower = transcript.lowercased()

        // Permission response mode — match whole words only to avoid false positives
        if isWaitingForPermissionResponse {
            let words = Set(lower.components(separatedBy: .whitespacesAndNewlines)
                .flatMap { $0.components(separatedBy: CharacterSet.punctuationCharacters) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty })

            let affirmatives: Set<String> = ["yes", "yeah", "yep", "sure", "allow", "approve", "okay", "proceed"]
            let negatives: Set<String> = ["no", "nope", "deny", "block", "stop", "cancel"]
            let repeatWords: Set<String> = ["repeat", "what", "again", "options", "huh"]

            // "Repeat" / "what?" — re-speak the prompt
            if !words.isDisjoint(with: repeatWords) && words.isDisjoint(with: affirmatives) && words.isDisjoint(with: negatives) {
                speak(lastPermissionPrompt)
                return
            }

            // Ordinal words for picking a numbered suggestion
            let ordinalWords = ["first", "second", "third", "fourth"]
            let numberWords = ["one", "two", "three", "four"]

            for i in 0..<permissionOptionCount {
                if words.contains(ordinalWords[i]) || words.contains(numberWords[i]) {
                    isWaitingForPermissionResponse = false
                    speak("Got it, option \(i + 1).")
                    onPermissionResponse?(i + 1)
                    return
                }
            }

            // Yes / No — whole-word matching
            if !words.isDisjoint(with: affirmatives) {
                isWaitingForPermissionResponse = false
                speak("Got it.")
                onPermissionResponse?(0)
                return
            } else if !words.isDisjoint(with: negatives) {
                isWaitingForPermissionResponse = false
                speak("Blocked it.")
                onPermissionResponse?(-1)
                return
            }
            return
        }

        // Wake word detection
        guard let range = lower.range(of: wakeWord.lowercased()) else {
            return
        }

        let afterWake = String(transcript[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // First time we see the wake word in this recognition cycle
        if !wakeWordDetected {
            wakeWordDetected = true
            onWakeWord?()
            log("[speech] Wake word detected!")
        }

        // Update what we're showing
        lastHeard = afterWake

        if afterWake.isEmpty {
            return
        }

        // Debounce: wait for the user to stop talking before sending.
        // Cancel previous timer, start new one. On final result, send immediately.
        voiceInputTimer?.cancel()

        if isFinal {
            sendVoiceCommand(afterWake)
        } else {
            // Wait 1.5s of silence before treating partial as final
            voiceInputTimer = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !Task.isCancelled {
                    sendVoiceCommand(afterWake)
                }
            }
        }
    }

    private func sendVoiceCommand(_ text: String) {
        // Reset wake word state for next cycle
        wakeWordDetected = false
        pendingTranscript = ""

        let quitWords = ["quit", "exit", "stop", "bye"]
        if quitWords.contains(where: { text.lowercased() == $0 }) {
            speak("Quack! See you later.")
            return
        }

        log("[speech] Sending: \(text)")
        speak("On it.")
        onVoiceInput?(text)
    }

    // MARK: - TTS (macOS `say` command — reliable, supports Boing)

    private var currentSpeechProcess: Process?

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        log("[tts] \(text)")

        // Kill any currently speaking process to prevent pileup
        stopSpeaking()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        task.arguments = ["-v", ttsVoice, text]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        currentSpeechProcess = task

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()
                Task { @MainActor in
                    if self?.currentSpeechProcess === task {
                        self?.currentSpeechProcess = nil
                    }
                }
            } catch {
                Task { @MainActor in
                    self?.log("[tts] say command failed: \(error)")
                }
            }
        }
    }

    func stopSpeaking() {
        if let proc = currentSpeechProcess, proc.isRunning {
            proc.terminate()
            currentSpeechProcess = nil
        }
    }

    // MARK: - Permission Gate

    func askPermission(toolName: String, options: [String] = []) {
        permissionOptionCount = options.count

        // Keep it short — the duck asks, the human decides
        let prompt = "\(toolName). Allow?"

        lastPermissionPrompt = prompt
        isWaitingForPermissionResponse = true
        speak(prompt)
    }

    // MARK: - Mic Discovery

    static func listMicrophones() -> [(index: Int, name: String)] {
        var result: [(Int, String)] = []
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        for (i, device) in devices.enumerated() {
            result.append((i, device.localizedName))
        }
        return result
    }
}
