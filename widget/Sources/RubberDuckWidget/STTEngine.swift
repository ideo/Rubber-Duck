// STT Engine — Speech-to-text via Apple Speech framework.
//
// Manages the SFSpeechRecognizer, AVAudioEngine, and audio tap.
// Handles Teensy device selection, format negotiation, start/stop/restart,
// and a watchdog timer for stuck recognition.

import Foundation
import Speech
import AVFoundation
import CoreAudio

@MainActor
class STTEngine: ObservableObject {
    @Published var isListening = false
    @Published var lastError = ""

    /// Called when a transcript is produced (text, isFinal).
    var onTranscript: ((String, Bool) -> Void)?

    // Audio
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Device
    private var teensyDeviceID: AudioDeviceID?

    // Restart logic
    private lazy var restartController: RecognitionRestartController = {
        let rc = RecognitionRestartController(label: "stt")
        rc.onRestart = { [weak self] in self?.start() }
        return rc
    }()

    // Mic mute gate — owned by TTSEngine, shared here
    private var ttsGate: TTSGate?

    private func log(_ msg: String) { DuckLog.log(msg) }

    /// Set the TTSGate so the audio tap can mute during TTS playback.
    func setTTSGate(_ gate: TTSGate) {
        self.ttsGate = gate
    }

    /// Set the Teensy device ID for audio input (found via AudioDeviceDiscovery).
    func setTeensyDevice(_ deviceID: AudioDeviceID) {
        self.teensyDeviceID = deviceID
    }

    /// Clear the Teensy device so next start() uses the default system mic.
    func clearTeensyDevice() {
        self.teensyDeviceID = nil
    }

    // MARK: - Listening

    func start() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            log("[stt] Speech recognizer unavailable")
            lastError = "Speech recognizer unavailable"
            return
        }

        // Cancel any existing task
        stop()

        // Reset engine to clear cached format state from any previous device
        audioEngine.reset()

        // Apply Teensy device AFTER reset so the engine builds its graph
        // with Teensy's native format (44100Hz) instead of system default (48kHz)
        applyTeensyDevice()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            log("[stt] Failed to create recognition request")
            return
        }

        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        log("[stt] Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch")

        guard recordingFormat.sampleRate > 0 else {
            log("[stt] Invalid audio format (0 sample rate). Check mic connection.")
            lastError = "Invalid audio format"
            return
        }

        // Gate: don't feed audio to recognition while TTS is playing.
        // Captures ttsGate directly (not through self) so it's not actor-isolated.
        let gate = ttsGate
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            if let g = gate, g.muted { return }
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self, self.isListening else { return }

                // Pet the watchdog — recognition is still alive
                self.restartController.resetWatchdog(isListening: self.isListening)

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.onTranscript?(transcript, result.isFinal)

                    if result.isFinal {
                        self.log("[stt] Final, restarting...")
                        self.restartController.resetAttempts()
                        self.restart()
                    }
                }

                if let error = error {
                    let msg = error.localizedDescription
                    // Don't log cancellation errors — they're expected after sendVoiceCommand
                    if !msg.contains("canceled") {
                        self.log("[stt] Recognition error: \(msg)")
                    }
                    self.lastError = msg
                    self.restart()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            // Don't reset attempts here — let backoff accumulate across error restarts.
            // Only reset on successful recognition or explicit resetRestartAttempts().
            log("[stt] Listening...")
        } catch {
            log("[stt] Audio engine failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isListening = false
        }
    }

    func stop() {
        restartController.cancelWatchdog()
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

    func restart() {
        stop()
        restartController.scheduleRestart()
    }

    /// Reset restart attempts (e.g. after a successful voice command).
    func resetRestartAttempts() {
        restartController.resetAttempts()
    }

    // MARK: - Teensy Device Setup

    /// Apply the stored Teensy device to the audio engine's input node.
    /// If the cached device ID is stale, re-discovers the Teensy.
    /// Falls back to default mic if Teensy is gone.
    private func applyTeensyDevice() {
        guard var deviceID = teensyDeviceID else { return }

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

        // If stale device ID, re-discover Teensy
        if status != noErr {
            log("[stt] Cached Teensy device \(deviceID) stale (OSStatus \(status)), re-discovering...")
            if let duckDevice = AudioDeviceDiscovery.findDuckDevice() {
                deviceID = duckDevice.deviceID
                teensyDeviceID = deviceID
                inputDeviceID = deviceID
                status = AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &inputDeviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
            } else {
                log("[stt] Teensy not found — falling back to default mic")
                teensyDeviceID = nil
                return
            }
        }

        guard status == noErr else {
            log("[stt] Failed to set Teensy device: OSStatus \(status)")
            teensyDeviceID = nil  // Clear so next attempt uses default mic
            return
        }
        log("[stt] Set input device to Teensy (ID \(deviceID))")

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
            log("[stt] Could not read device format: OSStatus \(status)")
            return
        }
        log("[stt] Teensy hardware: \(deviceFormat.mSampleRate)Hz, \(deviceFormat.mChannelsPerFrame)ch, \(deviceFormat.mBitsPerChannel)bit")

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
            log("[stt] Set software format to \(outputFormat.mSampleRate)Hz Float32 \(outputFormat.mChannelsPerFrame)ch")
        } else {
            log("[stt] Could not set output format: OSStatus \(status)")
        }
    }
}
