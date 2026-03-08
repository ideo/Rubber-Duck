// Speech Service — STT via Apple Speech framework + TTS via macOS `say` command.
//
// Handles wake word detection ("ducky"), voice-to-text transcription,
// and text-to-speech output (Boing voice). Auto-detects Teensy mic
// if available, falls back to system default.
//
// TTS routing: uses `say -a <deviceID>` to target the Teensy USB Audio
// output device directly (Teensy → I2S DAC → speaker). Falls back to
// system default output if Teensy not available.
//
// Logs to ~/Library/Logs/RubberDuck.log for debugging.

import Foundation
import Speech
import AVFoundation
import CoreAudio

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
    private var recognitionWatchdog: Task<Void, Never>?
    private var teensyDeviceID: AudioDeviceID?
    private var teensyDeviceUID: String?
    private var teensyDeviceName: String?  // CoreAudio name, used for `say -a`
    private var ttsProcess: Process?

    // Thread-safe TTS state — accessed from both MainActor and audio render thread.
    // Separate class (not actor-isolated) so the audio tap can read it directly.
    private class TTSGate: @unchecked Sendable { var muted = false }
    private let ttsGate = TTSGate()

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

        // Prefer Teensy — set it as the audio engine's input device
        if let teensy = devices.first(where: { $0.localizedName.lowercased().contains("teensy") }) {
            selectedMicName = teensy.localizedName
            log("[speech] Selected Teensy mic: \(teensy.localizedName)")
            setAudioInputDevice(name: teensy.localizedName)
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

    /// Safe CoreAudio string property reader — avoids UnsafeMutableRawPointer
    /// warnings from passing CFString directly to AudioObjectGetPropertyData.
    private func coreAudioStringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return nil
        }
        let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<CFString>.alignment)
        defer { buf.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buf) == noErr else {
            return nil
        }
        return buf.load(as: CFString.self) as String
    }

    /// Find Teensy audio device by name and store its ID for later use.
    /// We DON'T touch the audio engine here — accessing inputNode too early
    /// causes it to cache the default device's format (48kHz), which then
    /// conflicts with Teensy's 44100Hz when the engine starts.
    private func setAudioInputDevice(name: String) {
        var propSize: UInt32 = 0
        var propAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Get all audio devices
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &propSize)
        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &propSize, &deviceIDs)

        for deviceID in deviceIDs {
            guard let devName = coreAudioStringProperty(deviceID, selector: kAudioObjectPropertyName) else {
                continue
            }

            if devName.lowercased().contains("teensy") {
                teensyDeviceID = deviceID
                teensyDeviceName = devName
                teensyDeviceUID = coreAudioStringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID)

                log("[speech] Found Teensy audio device (ID \(deviceID), name \"\(devName)\", UID \(teensyDeviceUID ?? "?"))")
                log("[tts] Will route TTS to Teensy via `say -a \"\(devName)\"`")
                return
            }
        }
        log("[speech] Teensy not found in CoreAudio devices")
    }

    /// Apply the stored Teensy device to the audio engine's input node.
    /// After setting the device, we must also set the audio unit's output
    /// stream format to match the hardware (44100Hz Float32) — otherwise
    /// AVAudioEngine's cached 48kHz format causes -10868 on start().
    private func applyTeensyDevice() {
        guard let deviceID = teensyDeviceID else { return }

        let audioUnit = audioEngine.inputNode.audioUnit!
        var inputDeviceID = deviceID

        // 1. Set the device
        var status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &inputDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            log("[speech] Failed to set Teensy device: OSStatus \(status)")
            return
        }
        log("[speech] Set input device to Teensy (ID \(deviceID))")

        // 2. Read the device's native format from the hardware (input) side
        var deviceFormat = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1, // Element 1 = input bus (hardware side)
            &deviceFormat,
            &formatSize
        )
        guard status == noErr else {
            log("[speech] Could not read device format: OSStatus \(status)")
            return
        }
        log("[speech] Teensy hardware: \(deviceFormat.mSampleRate)Hz, \(deviceFormat.mChannelsPerFrame)ch, \(deviceFormat.mBitsPerChannel)bit")

        // 3. Set the output (software) side to Float32 at the device's sample rate.
        //    This eliminates the 48kHz vs 44100Hz mismatch that causes -10868.
        var outputFormat = AudioStreamBasicDescription(
            mSampleRate: deviceFormat.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: deviceFormat.mChannelsPerFrame,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1, // Element 1 = input bus (software side)
            &outputFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        if status == noErr {
            log("[speech] Set software format to \(outputFormat.mSampleRate)Hz Float32 \(outputFormat.mChannelsPerFrame)ch")
        } else {
            log("[speech] Could not set output format: OSStatus \(status)")
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

        // Reset engine to clear cached format state from any previous device
        audioEngine.reset()

        // Apply Teensy device AFTER reset so the engine builds its graph
        // with Teensy's native format (44100Hz) instead of system default (48kHz)
        applyTeensyDevice()

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

        // Use nil format to let audio engine auto-negotiate with hardware.
        // Gate: don't feed audio to recognition while TTS is playing — the
        // speaker is right next to the mic and causes garbage transcripts.
        // Captures ttsGate directly (not through self) so it's not actor-isolated.
        let gate = ttsGate
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            guard !gate.muted else { return }
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self, self.isListening else { return }

                // Pet the watchdog — recognition is still alive
                self.resetRecognitionWatchdog()

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.processTranscript(transcript, isFinal: result.isFinal)

                    if result.isFinal {
                        self.log("[speech] Final, restarting...")
                        self.restartAttempts = 0
                        self.wakeWordDetected = false
                        self.restartListening()
                    }
                }

                if let error = error {
                    let msg = error.localizedDescription
                    // Don't log cancellation errors — they're expected after sendVoiceCommand
                    if !msg.contains("canceled") {
                        self.log("[speech] Recognition error: \(msg)")
                    }
                    self.lastError = msg
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
        recognitionWatchdog?.cancel()
        recognitionWatchdog = nil
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

    /// Watchdog: if recognition goes silent for 10s, restart it.
    /// SFSpeechRecognizer sometimes stops producing partials after a short
    /// utterance (e.g. just "Ducky") without giving a final or error.
    private func resetRecognitionWatchdog() {
        recognitionWatchdog?.cancel()
        recognitionWatchdog = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            if !Task.isCancelled && self.isListening {
                self.log("[speech] Watchdog: recognition silent for 10s, restarting...")
                self.wakeWordDetected = false
                self.restartAttempts = 0
                self.restartListening()
            }
        }
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

            // Start a 3s wake-word timeout. If no command text arrives,
            // give up and restart listening. User can say "ducky" again.
            voiceInputTimer?.cancel()
            voiceInputTimer = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                if !Task.isCancelled && self.wakeWordDetected {
                    self.log("[speech] No command after wake word, restarting...")
                    self.speak("Hmm?")
                    self.wakeWordDetected = false
                    self.lastHeard = ""
                    self.restartAttempts = 0
                    self.restartListening()
                }
            }
        }

        // Update what we're showing
        lastHeard = afterWake

        if afterWake.isEmpty {
            return
        }

        // We have command text — cancel the wake-word timeout and debounce instead.
        voiceInputTimer?.cancel()

        if isFinal {
            sendVoiceCommand(afterWake)
        } else {
            // Wait 2.5s of silence before treating partial as final.
            // 1.5s was too short — "ducky let's code" would send just "let's"
            // because the partial arrived before "code" was recognized.
            voiceInputTimer = Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if !Task.isCancelled {
                    sendVoiceCommand(afterWake)
                }
            }
        }
    }

    private func sendVoiceCommand(_ text: String) {
        // Kill current recognition FIRST to prevent double-send.
        // The dying task may fire final/error callbacks — guard with wakeWordDetected.
        wakeWordDetected = false
        pendingTranscript = ""
        voiceInputTimer?.cancel()
        stopListening()

        let quitWords = ["quit", "exit", "stop", "bye"]
        if quitWords.contains(where: { text.lowercased() == $0 }) {
            speak("Quack! See you later.")
            restartAfterTTS()
            return
        }

        log("[speech] Sending: \(text)")
        speak("On it.")
        onVoiceInput?(text)

        // Restart listening after TTS finishes (async)
        restartAfterTTS()
    }

    /// Restart listening after a short delay (lets TTS finish + unmute).
    private func restartAfterTTS() {
        Task {
            // Wait for TTS to finish — poll the gate
            while ttsGate.muted {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            self.restartAttempts = 0
            self.startListening()
        }
    }

    // MARK: - TTS (`say -a <deviceID>` → Teensy USB Audio → I2S speaker)

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        log("[tts] \(text)")

        // Stop any current speech to prevent pileup
        stopSpeaking()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/say")

        // Route to Teensy speaker via `-a <name>` if available.
        // Note: `say -a` uses its OWN device IDs (not CoreAudio AudioDeviceID),
        // but it also accepts device names — use the name for reliability.
        if let name = teensyDeviceName {
            task.arguments = ["-v", ttsVoice, "-a", name, text]
        } else {
            task.arguments = ["-v", ttsVoice, text]
        }

        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        // Mute mic input while speaking to prevent feedback
        // (speaker is right next to electret mic on the duck)
        ttsGate.muted = true
        ttsProcess = task

        let gate = ttsGate
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                Task { @MainActor in
                    self?.log("[tts] say failed: \(error)")
                }
            }
            // Unmute after say exits + brief delay for USB audio buffer drain
            Thread.sleep(forTimeInterval: 0.3)
            gate.muted = false
            Task { @MainActor in
                if self?.ttsProcess === task {
                    self?.ttsProcess = nil
                }
            }
        }
    }

    func stopSpeaking() {
        if let process = ttsProcess, process.isRunning {
            process.terminate()
            ttsProcess = nil
        }
        ttsGate.muted = false
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
