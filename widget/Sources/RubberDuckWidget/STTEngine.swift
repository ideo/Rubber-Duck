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
    private var restartAttempts = 0
    private let maxRestartAttempts = 5
    private var recognitionWatchdog: Task<Void, Never>?

    // Mic mute gate — owned by TTSEngine, shared here
    private var ttsGate: TTSGate?

    var log: ((String) -> Void)?

    /// Set the TTSGate so the audio tap can mute during TTS playback.
    func setTTSGate(_ gate: TTSGate) {
        self.ttsGate = gate
    }

    /// Set the Teensy device ID for audio input (found via AudioDeviceDiscovery).
    func setTeensyDevice(_ deviceID: AudioDeviceID) {
        self.teensyDeviceID = deviceID
    }

    // MARK: - Listening

    func start() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            log?("[stt] Speech recognizer unavailable")
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
            log?("[stt] Failed to create recognition request")
            return
        }

        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        log?("[stt] Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch")

        guard recordingFormat.sampleRate > 0 else {
            log?("[stt] Invalid audio format (0 sample rate). Check mic connection.")
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
                self.resetWatchdog()

                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.onTranscript?(transcript, result.isFinal)

                    if result.isFinal {
                        self.log?("[stt] Final, restarting...")
                        self.restartAttempts = 0
                        self.restart()
                    }
                }

                if let error = error {
                    let msg = error.localizedDescription
                    // Don't log cancellation errors — they're expected after sendVoiceCommand
                    if !msg.contains("canceled") {
                        self.log?("[stt] Recognition error: \(msg)")
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
            restartAttempts = 0
            log?("[stt] Listening...")
        } catch {
            log?("[stt] Audio engine failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isListening = false
        }
    }

    func stop() {
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

    func restart() {
        stop()

        restartAttempts += 1
        if restartAttempts > maxRestartAttempts {
            log?("[stt] Too many restart attempts (\(restartAttempts)). Giving up.")
            lastError = "Recognition keeps failing. Try Start Listening from context menu."
            return
        }

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = UInt64(pow(2.0, Double(restartAttempts - 1))) * 1_000_000_000
        log?("[stt] Restarting in \(restartAttempts)s (attempt \(restartAttempts)/\(maxRestartAttempts))...")

        Task {
            try? await Task.sleep(nanoseconds: delay)
            if !self.isListening {
                self.start()
            }
        }
    }

    /// Reset restart attempts (e.g. after a successful voice command).
    func resetRestartAttempts() {
        restartAttempts = 0
    }

    // MARK: - Watchdog

    /// If recognition goes silent for 10s, restart it.
    /// SFSpeechRecognizer sometimes stops producing partials after a short
    /// utterance (e.g. just "Ducky") without giving a final or error.
    private func resetWatchdog() {
        recognitionWatchdog?.cancel()
        recognitionWatchdog = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            if !Task.isCancelled && self.isListening {
                self.log?("[stt] Watchdog: recognition silent for 10s, restarting...")
                self.restartAttempts = 0
                self.restart()
            }
        }
    }

    // MARK: - Teensy Device Setup

    /// Apply the stored Teensy device to the audio engine's input node.
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
            log?("[stt] Failed to set Teensy device: OSStatus \(status)")
            return
        }
        log?("[stt] Set input device to Teensy (ID \(deviceID))")

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
            log?("[stt] Could not read device format: OSStatus \(status)")
            return
        }
        log?("[stt] Teensy hardware: \(deviceFormat.mSampleRate)Hz, \(deviceFormat.mChannelsPerFrame)ch, \(deviceFormat.mBitsPerChannel)bit")

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
            log?("[stt] Set software format to \(outputFormat.mSampleRate)Hz Float32 \(outputFormat.mChannelsPerFrame)ch")
        } else {
            log?("[stt] Could not set output format: OSStatus \(status)")
        }
    }
}
