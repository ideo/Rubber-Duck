// Serial TTS Engine — Text-to-speech via AVSpeechSynthesizer → serial PCM streaming.
//
// For ESP32 boards that lack USB Audio Class. Renders speech to PCM buffers,
// resamples to 16kHz 16-bit mono, and streams over serial using binary framing.
// The ESP32 ring buffer plays the audio through I2S → MAX98357 → speaker.

import AVFoundation

@MainActor
class SerialTTSEngine {
    /// Shared gate for muting mic input during TTS playback.
    let gate = TTSGate()

    /// Voice identifier for AVSpeechSynthesizer.
    var voice: String = DuckConfig.ttsVoice

    /// Master volume (0.0–1.0). Scales the PCM boost applied during resampling.
    var volume: Float = DuckConfig.volume

    private let synth = AVSpeechSynthesizer()
    private weak var transport: SerialTransport?
    private var streamingTask: Task<Void, Never>?
    private var isStopping = false

    private func log(_ msg: String) { DuckLog.log(msg) }

    init(transport: SerialTransport) {
        self.transport = transport
    }

    /// Speak text by streaming PCM to the ESP32 over serial.
    /// Set `skipChirpWait` to true when no chirp was triggered (e.g. voice preview).
    func speak(_ text: String, skipChirpWait: Bool = false) {
        guard !text.isEmpty, let transport = transport else { return }
        log("[serial-tts] \(text)")

        stop()

        var cleaned = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "#", with: "")
        // Strip emoji
        cleaned = String(cleaned.unicodeScalars.filter { scalar in
            scalar.properties.isEmoji == false || scalar.value < 0x80
        })
        let utterance = AVSpeechUtterance(string: cleaned)

        // Look up the exact AVSpeechSynthesisVoice identifier from DuckVoices.
        if let voiceId = DuckVoices.voiceId(for: voice),
           let v = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = v
        } else if let v = AVSpeechSynthesisVoice(identifier: "com.apple.speech.synthesis.voice.\(voice)") {
            utterance.voice = v
        } else if let v = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = v
        }

        gate.muted = true
        isStopping = false

        // DON'T enter audio mode yet — let the chirp play first.
        // Audio mode entry happens in the streaming task after a delay.

        let g = gate
        let transportRef = transport

        let engine = self
        let shouldWaitForChirp = !skipChirpWait
        let vol = volume
        streamingTask = Task.detached {
            // Wait for chirp to finish before entering audio mode.
            // The firmware sends "K\n" when the chirp completes.
            // Timeout after 3s in case no chirp was triggered or signal is missed.
            if shouldWaitForChirp {
                await SerialTTSEngine.waitForChirpDone(transport: transportRef)
            }
            guard !Task.isCancelled else {
                await MainActor.run { engine.sendEndOfStream() }
                return
            }

            // NOW enter audio mode on ESP32
            transportRef.enterAudioMode()
            transportRef.sendCommand("A,16000,16,1")

            // Stream PCM as it arrives — no waiting for full render.
            // AsyncStream bridges the synth callback (producer) to the streaming loop (consumer).
            let (bufferStream, bufferContinuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)

            Task { @MainActor in
                let delegate = SynthDelegate {
                    bufferContinuation.finish()
                }
                engine.synthDelegate = delegate
                engine.synth.delegate = delegate
                engine.synth.write(utterance) { buffer in
                    guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                        delegate.markDone()
                        return
                    }
                    bufferContinuation.yield(pcm)
                }
            }

            // Stream buffers paced to real-time at 16kHz as they arrive
            let targetRate: Double = 16000
            let startTime = ContinuousClock.now

            var totalSamplesSent: Int = 0
            for await pcmBuffer in bufferStream {
                if Task.isCancelled { break }

                let samples = SerialTTSEngine.resampleTo16kMono(pcmBuffer, volume: vol)
                if samples.isEmpty { continue }

                // Send in chunks of 512 samples (1024 bytes) — matches firmware expectations
                let chunkSize = 512
                for offset in stride(from: 0, to: samples.count, by: chunkSize) {
                    if Task.isCancelled { break }

                    let end = min(offset + chunkSize, samples.count)
                    let chunk = Array(samples[offset..<end])

                    // Encode Int16 samples to little-endian bytes
                    var payload = [UInt8]()
                    payload.reserveCapacity(chunk.count * 2)
                    for sample in chunk {
                        payload.append(UInt8(truncatingIfNeeded: sample))
                        payload.append(UInt8(truncatingIfNeeded: sample >> 8))
                    }

                    transportRef.writeFrame(tag: 0x01, payload: payload)
                    totalSamplesSent += chunk.count

                    // Pace to real-time: wait until we're caught up
                    let targetElapsed = Double(totalSamplesSent) / targetRate
                    let actualElapsed = (ContinuousClock.now - startTime).seconds
                    let sleepTime = targetElapsed - actualElapsed
                    if sleepTime > 0.001 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                    }
                }
            }

            DuckLog.log("[serial-tts] Streamed \(totalSamplesSent) samples")

            // End audio mode
            await MainActor.run { engine.sendEndOfStream() }

            // Brief delay for ESP32 ring buffer to drain, then unmute mic
            try? await Task.sleep(nanoseconds: 300_000_000)
            g.muted = false
        }
    }

    /// Stop current speech.
    func stop() {
        isStopping = true
        streamingTask?.cancel()
        streamingTask = nil
        synth.stopSpeaking(at: .immediate)
        sendEndOfStream()
        gate.muted = false
    }

    /// Whether TTS is currently muting the mic.
    var isMuted: Bool { gate.muted }

    // MARK: - Chirp Wait

    /// Wait for the firmware's chirp-complete signal ("K\n") before entering audio mode.
    /// Returns when the signal arrives, or after 3s timeout.
    private nonisolated static func waitForChirpDone(transport: SerialTransport) async {
        let previousCallback = transport.onChirpDone

        // Use an actor-isolated flag to safely coordinate the callback and timeout.
        final class OnceFlag: @unchecked Sendable {
            private let lock = NSLock()
            private var _resumed = false
            func tryResume() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                if _resumed { return false }
                _resumed = true
                return true
            }
        }
        let once = OnceFlag()

        let gotSignal = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            transport.onChirpDone = {
                previousCallback?()
                if once.tryResume() {
                    continuation.resume(returning: true)
                }
            }

            // Timeout after 3s
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if once.tryResume() {
                    continuation.resume(returning: false)
                }
            }
        }

        transport.onChirpDone = previousCallback

        if gotSignal {
            DuckLog.log("[serial-tts] Chirp done, entering audio mode")
        } else {
            DuckLog.log("[serial-tts] Chirp wait timed out (3s), proceeding")
        }
    }

    // MARK: - Private

    private var synthDelegate: SynthDelegate?

    private func sendEndOfStream() {
        guard let transport = transport else { return }
        // Send A,0 as a control frame (0x02) — firmware is in binary audio mode
        let payload = Array("A,0\n".utf8)
        transport.writeFrame(tag: 0x02, payload: payload)
        transport.exitAudioMode()
    }

    /// Resample an AVAudioPCMBuffer to 16kHz 16-bit mono Int16 samples.
    /// Volume (0.0–1.0) scales the output boost.
    private nonisolated static func resampleTo16kMono(_ buffer: AVAudioPCMBuffer, volume: Float = 1.0) -> [Int16] {
        let format = buffer.format
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }

        let srcRate = format.sampleRate
        let channels = Int(format.channelCount)

        // Read source samples as Float32
        var srcSamples = [Float]()
        srcSamples.reserveCapacity(frameCount)

        if let floatData = buffer.floatChannelData {
            // Float32 format — mix to mono
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channels {
                    sum += floatData[ch][i]
                }
                srcSamples.append(sum / Float(channels))
            }
        } else if let int16Data = buffer.int16ChannelData {
            // Int16 format — mix to mono, convert to float
            for i in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channels {
                    sum += Float(int16Data[ch][i]) / 32768.0
                }
                srcSamples.append(sum / Float(channels))
            }
        } else {
            return []
        }

        // Resample to 16kHz using linear interpolation
        let targetRate: Double = 16000
        let ratio = srcRate / targetRate
        let outputCount = Int(Double(frameCount) / ratio)

        var output = [Int16]()
        output.reserveCapacity(outputCount)

        for i in 0..<outputCount {
            let srcIdx = Double(i) * ratio
            let idx0 = Int(srcIdx)
            let frac = Float(srcIdx - Double(idx0))

            let s0 = idx0 < srcSamples.count ? srcSamples[idx0] : 0
            let s1 = (idx0 + 1) < srcSamples.count ? srcSamples[idx0 + 1] : s0
            let interpolated = s0 + frac * (s1 - s0)

            // Boost + scale to Int16 range (AVSpeechSynthesizer output is conservative)
            // Volume scales the base boost (2.5 at 100%) down to silence at 0%.
            let boosted = interpolated * 2.5 * volume
            let clamped = max(-1.0, min(1.0, boosted))
            output.append(Int16(clamped * 32767.0))
        }

        return output
    }
}

// MARK: - AVSpeechSynthesizerDelegate for completion detection

private class SynthDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let onComplete: () -> Void
    private var done = false

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func markDone() {
        guard !done else { return }
        done = true
        onComplete()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        markDone()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        markDone()
    }
}

// MARK: - ContinuousClock duration extension

private extension Duration {
    var seconds: Double {
        let (s, a) = components
        return Double(s) + Double(a) / 1_000_000_000_000_000_000
    }
}
