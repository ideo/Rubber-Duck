// Melody Engine — Hums the Jeopardy "Think!" theme during context compaction.
//
// Uses AVAudioEngine to pitch-shift a vocal sample ("Mmmm" by Ralph)
// through the Final Jeopardy melody notes.
//
// Two playback paths:
// - Local: AVAudioEngine → Mac speakers (when no hardware connected)
// - Serial: Pre-rendered 16kHz Int16 PCM → SerialTransport → ESP32 I2S speaker
//
// Sample: ~0.58s of "Mmmm" at F3 (MIDI 53). Melody ranges F3-A4,
// max +16 semitones. Tempo: 90 BPM.

import AVFoundation
import CoreAudio

@MainActor
class MelodyEngine {

    // MARK: - Local playback (AVAudioEngine)

    // Audio graph — created once, reused across start/stop cycles.
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var pitchUnit: AVAudioUnitTimePitch?

    private var buffer: AVAudioPCMBuffer?
    private var fastBuffer: AVAudioPCMBuffer?
    private var melodyTask: Task<Void, Never>?
    private(set) var isPlaying = false

    /// Output device ID for local playback (Teensy USB audio).
    var outputDeviceID: AudioDeviceID? {
        didSet {
            if let engine = engine, let deviceID = outputDeviceID {
                setOutputDevice(engine: engine, deviceID: deviceID)
            }
        }
    }

    // MARK: - Serial playback (ESP32)

    /// Serial transport for ESP32 streaming. When set and connected,
    /// melody streams over serial instead of playing through speakers.
    weak var serialTransport: SerialTransport?

    /// Pre-rendered pitch-shifted notes as 16kHz mono Int16 samples.
    private var serialNoteCache: [Int: [Int16]] = [:]
    private var serialFastNoteCache: [Int: [Int16]] = [:]
    private var serialCacheReady = false

    /// Flag for serial cleanup in stop()
    private var usingSerial = false

    // MARK: - Constants

    private let baseMIDI: Float = 53.0
    private let melodyVolume: Float = 0.60
    private let bpm: Double = 90.0
    private var beatDuration: Double { 60.0 / bpm }
    private var sampleDuration: Double = 0.58
    private let fastTrim: Double = 0.29

    // MARK: - Jeopardy "Think!" Melody

    private enum Event {
        case note(Int)
        case fast(Int)
        case rest(Double)
    }

    private let melody: [Event] = [
        // Shifted down 6 semitones (half octave) from original
        .note(54), .note(59), .note(54), .note(47),
        .note(54), .note(59), .note(54), .rest(1.0),

        .note(54), .note(59), .note(54), .note(59), .note(63), .rest(0.5),
        .fast(61), .fast(59), .fast(58), .fast(56), .fast(55), .rest(0.5),

        .note(54), .note(59), .note(54), .note(47),
        .note(54), .note(59), .note(54), .rest(1.0),

        .note(59), .rest(0.5), .fast(56), .note(54), .note(52),
        .note(51), .rest(0.75), .note(49), .rest(0.75), .note(47), .rest(1.0),
    ]

    // MARK: - Start / Stop

    func start() {
        guard !isPlaying else { return }
        guard loadBuffer() else {
            DuckLog.log("[melody] Failed to load mmmm.aiff — no humming today")
            return
        }

        if let transport = serialTransport, transport.isConnected {
            startSerial(transport: transport)
        } else {
            startLocal()
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        melodyTask?.cancel()
        melodyTask = nil

        if usingSerial {
            // Send end-of-stream and exit audio mode
            if let transport = serialTransport, transport.inAudioMode {
                let payload = Array("A,0\n".utf8)
                transport.writeFrame(tag: 0x02, payload: payload)
                transport.exitAudioMode()
            }
            usingSerial = false
        } else {
            // Local path: just stop the player, keep engine alive
            playerNode?.stop()
        }

        DuckLog.log("[melody] Jeopardy humming stopped")
    }

    // MARK: - Local Playback

    private func startLocal() {
        guard let buf = buffer else { return }

        if engine == nil {
            let eng = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            pitch.rate = 1.0

            eng.attach(player)
            eng.attach(pitch)

            let format = buf.format
            eng.connect(player, to: pitch, format: format)
            eng.connect(pitch, to: eng.mainMixerNode, format: format)

            player.volume = melodyVolume

            self.engine = eng
            self.playerNode = player
            self.pitchUnit = pitch
        }

        guard let engine = engine, let player = playerNode, let pitch = pitchUnit else { return }

        if let deviceID = outputDeviceID {
            setOutputDevice(engine: engine, deviceID: deviceID)
        }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                DuckLog.log("[melody] Engine start failed: \(error)")
                return
            }
        }

        isPlaying = true
        usingSerial = false

        let capturedPlayer = player
        let capturedPitch = pitch
        let fastBuf = fastBuffer ?? buf
        let baseMIDI = baseMIDI
        let sampleDuration = sampleDuration
        let fastTrim = fastTrim
        let beatDuration = beatDuration
        let melody = melody
        melodyTask = Task.detached { [weak self] in
            await Self.playLocalLoop(
                player: capturedPlayer, pitch: capturedPitch,
                buffer: buf, fastBuffer: fastBuf,
                baseMIDI: baseMIDI, sampleDuration: sampleDuration,
                fastTrim: fastTrim, beatDuration: beatDuration,
                melody: melody, isPlaying: { await self?.isPlaying ?? false }
            )
        }

        DuckLog.log("[melody] Jeopardy humming started (local)")
    }

    // MARK: - Serial Playback

    private func startSerial(transport: SerialTransport) {
        // Don't start if TTS is currently streaming
        if transport.inAudioMode {
            DuckLog.log("[melody] Serial audio busy (TTS streaming), skipping melody")
            return
        }

        // Pre-render notes on first use
        if !serialCacheReady {
            prerenderSerialNotes()
        }

        guard serialCacheReady else {
            DuckLog.log("[melody] Serial pre-render failed, falling back to local")
            startLocal()
            return
        }

        isPlaying = true
        usingSerial = true

        let noteCache = serialNoteCache
        let fastCache = serialFastNoteCache
        let beatDuration = beatDuration
        let melody = melody
        // Cleanup is handled by stop() — NOT in the detached task.
        // If the task cleaned up after itself, it could send A,0 after TTS
        // has already started streaming, clobbering the active audio session.
        melodyTask = Task.detached { [weak self] in
            // Wait for any recent TTS to fully drain before taking the serial bus.
            // The ESP32 ring buffer needs time to flush and the mic to unmute.
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
            guard !Task.isCancelled else { return }
            guard await self?.isPlaying ?? false else { return }

            // Now safe to enter audio mode
            transport.enterAudioMode()
            transport.sendCommand("A,16000,16,1")

            await Self.playSerialLoop(
                noteCache: noteCache, fastNoteCache: fastCache,
                transport: transport,
                beatDuration: beatDuration, melody: melody,
                isPlaying: { await self?.isPlaying ?? false }
            )
        }

        DuckLog.log("[melody] Jeopardy humming started (serial)")
    }

    // MARK: - Pre-render for Serial

    /// Render each unique pitch-shifted note using AVAudioEngine offline mode.
    /// Resamples output to 16kHz Int16 mono for serial streaming.
    private func prerenderSerialNotes() {
        guard let sourceBuffer = buffer else { return }

        // Collect unique MIDI pitches from melody
        var midiPitches = Set<Int>()
        for event in melody {
            switch event {
            case .note(let midi), .fast(let midi): midiPitches.insert(midi)
            case .rest: break
            }
        }

        let srcFormat = sourceBuffer.format
        let targetRate: Double = 16000
        let fullSamples = Int(sampleDuration * targetRate)  // ~9280
        let fastSamples = Int(fastTrim * targetRate)         // ~4640

        for midi in midiPitches {
            guard let rendered = renderPitchShifted(
                source: sourceBuffer, midi: midi,
                srcFormat: srcFormat
            ) else {
                DuckLog.log("[melody] Failed to render MIDI \(midi)")
                continue
            }

            // Resample from source rate to 16kHz and convert to Int16
            let resampled = resampleToInt16(rendered, srcRate: srcFormat.sampleRate, targetRate: targetRate)

            // Full note: truncate/pad to exact duration
            var fullNote = Array(resampled.prefix(fullSamples))
            if fullNote.count < fullSamples {
                fullNote.append(contentsOf: [Int16](repeating: 0, count: fullSamples - fullNote.count))
            }
            serialNoteCache[midi] = fullNote

            // Fast note: trimmed with fade-out
            var fastNote = Array(resampled.prefix(fastSamples))
            if fastNote.count < fastSamples {
                fastNote.append(contentsOf: [Int16](repeating: 0, count: fastSamples - fastNote.count))
            }
            // Apply fade-out on last 30ms
            let fadeSamples = Int(0.03 * targetRate) // 480 samples
            let fadeStart = max(0, fastNote.count - fadeSamples)
            for i in fadeStart..<fastNote.count {
                let t = Float(fastNote.count - i) / Float(fadeSamples)
                fastNote[i] = Int16(Float(fastNote[i]) * t)
            }
            serialFastNoteCache[midi] = fastNote
        }

        serialCacheReady = !serialNoteCache.isEmpty
        DuckLog.log("[melody] Pre-rendered \(serialNoteCache.count) serial notes (\(serialNoteCache.values.reduce(0) { $0 + $1.count * 2 }) bytes)")
    }

    /// Render a pitch-shifted version of the source buffer using AVAudioEngine offline mode.
    /// Returns Float32 samples at the source sample rate.
    private func renderPitchShifted(source: AVAudioPCMBuffer, midi: Int, srcFormat: AVAudioFormat) -> [Float]? {
        let eng = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
        pitch.rate = 1.0
        pitch.pitch = (Float(midi) - baseMIDI) * 100.0

        eng.attach(player)
        eng.attach(pitch)
        eng.connect(player, to: pitch, format: srcFormat)
        eng.connect(pitch, to: eng.mainMixerNode, format: srcFormat)

        // Enable offline rendering
        let maxFrames: AVAudioFrameCount = 4096
        do {
            try eng.enableManualRenderingMode(.offline, format: srcFormat, maximumFrameCount: maxFrames)
        } catch {
            DuckLog.log("[melody] Offline render setup failed: \(error)")
            return nil
        }

        do {
            try eng.start()
        } catch {
            DuckLog.log("[melody] Offline engine start failed: \(error)")
            return nil
        }

        player.scheduleBuffer(source, at: nil, options: [])
        player.play()

        // Render enough frames to cover the full sample + pitch processing latency
        let totalFrames = Int(source.frameLength) + 4096 // extra for pitch unit latency
        var output = [Float]()
        output.reserveCapacity(totalFrames)

        guard let renderBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: maxFrames) else {
            return nil
        }

        var framesRendered = 0
        while framesRendered < totalFrames {
            do {
                let status = try eng.renderOffline(maxFrames, to: renderBuffer)
                if status == .success {
                    let count = Int(renderBuffer.frameLength)
                    if count == 0 { break }
                    if let floatData = renderBuffer.floatChannelData {
                        // Mix to mono if needed
                        let channels = Int(srcFormat.channelCount)
                        for i in 0..<count {
                            var sum: Float = 0
                            for ch in 0..<channels { sum += floatData[ch][i] }
                            output.append(sum / Float(channels))
                        }
                    }
                    framesRendered += count
                } else {
                    break
                }
            } catch {
                break
            }
        }

        eng.stop()
        return output.isEmpty ? nil : output
    }

    /// Resample Float32 samples to Int16 at target rate using linear interpolation.
    private func resampleToInt16(_ samples: [Float], srcRate: Double, targetRate: Double) -> [Int16] {
        let ratio = srcRate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)

        var output = [Int16]()
        output.reserveCapacity(outputCount)

        for i in 0..<outputCount {
            let srcIdx = Double(i) * ratio
            let idx0 = Int(srcIdx)
            let frac = Float(srcIdx - Double(idx0))

            let s0 = idx0 < samples.count ? samples[idx0] : 0
            let s1 = (idx0 + 1) < samples.count ? samples[idx0 + 1] : s0
            let interpolated = s0 + frac * (s1 - s0)

            // Scale by melody volume
            // Match TTS volume levels (SerialTTSEngine uses 2.5× boost)
            let scaled = interpolated * 2.5 * melodyVolume
            let clamped = max(-1.0, min(1.0, scaled))
            output.append(Int16(clamped * 32767.0))
        }

        return output
    }

    // MARK: - Audio Output Routing (Local)

    private func setOutputDevice(engine: AVAudioEngine, deviceID: AudioDeviceID) {
        let outputNode = engine.outputNode
        guard let audioUnit = outputNode.audioUnit else {
            DuckLog.log("[melody] No audio unit on output node — using default output")
            return
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        if status == noErr {
            DuckLog.log("[melody] Routed audio to device \(deviceID)")
        } else {
            DuckLog.log("[melody] Failed to route audio to device \(deviceID) (status \(status)) — using default")
        }
    }

    // MARK: - Load Source Buffer

    private func loadBuffer() -> Bool {
        if buffer != nil { return true }

        guard let url = Resources.bundle.url(forResource: "mmmm", withExtension: "aiff") else {
            DuckLog.log("[melody] mmmm.aiff not found in bundle")
            return false
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return false
            }
            try file.read(into: pcm)
            self.buffer = pcm
            self.sampleDuration = Double(frameCount) / format.sampleRate

            // Trimmed buffer for fast notes (local playback path)
            let fastFrames = AVAudioFrameCount(fastTrim * format.sampleRate)
            if fastFrames < frameCount, let fastPCM = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: fastFrames) {
                if let src = pcm.floatChannelData, let dst = fastPCM.floatChannelData {
                    for ch in 0..<Int(format.channelCount) {
                        memcpy(dst[ch], src[ch], Int(fastFrames) * MemoryLayout<Float>.size)
                        let fadeFrames = Int(0.03 * format.sampleRate)
                        let fadeStart = Int(fastFrames) - fadeFrames
                        if fadeStart > 0 {
                            for i in fadeStart..<Int(fastFrames) {
                                let t = Float(Int(fastFrames) - i) / Float(fadeFrames)
                                dst[ch][i] *= t
                            }
                        }
                    }
                }
                fastPCM.frameLength = fastFrames
                self.fastBuffer = fastPCM
            }

            DuckLog.log("[melody] Loaded mmmm.aiff: \(frameCount) frames, \(format.sampleRate) Hz, \(String(format: "%.2f", sampleDuration))s")
            return true
        } catch {
            DuckLog.log("[melody] Failed to read mmmm.aiff: \(error)")
            return false
        }
    }

    // MARK: - Local Playback Loop

    private static func playLocalLoop(
        player: AVAudioPlayerNode, pitch: AVAudioUnitTimePitch,
        buffer: AVAudioPCMBuffer, fastBuffer: AVAudioPCMBuffer,
        baseMIDI: Float, sampleDuration: Double, fastTrim: Double,
        beatDuration: Double, melody: [Event],
        isPlaying: @escaping () async -> Bool
    ) async {
        // Escalating silence: 60s, 5min, 15min between loops
        let pauseSeconds: [UInt64] = [60, 300, 900]
        var loopCount = 0

        while !Task.isCancelled {
            guard await isPlaying() else { return }
            for event in melody {
                guard !Task.isCancelled else { return }
                guard await isPlaying() else { return }

                switch event {
                case .note(let midi):
                    let cents = (Float(midi) - baseMIDI) * 100.0
                    pitch.pitch = cents
                    await player.scheduleBuffer(buffer, at: nil, options: [])
                    player.play()
                    try? await Task.sleep(nanoseconds: UInt64(sampleDuration * 1_000_000_000))

                case .fast(let midi):
                    let cents = (Float(midi) - baseMIDI) * 100.0
                    pitch.pitch = cents
                    await player.scheduleBuffer(fastBuffer, at: nil, options: [])
                    player.play()
                    try? await Task.sleep(nanoseconds: UInt64(fastTrim * 1_000_000_000))

                case .rest(let beats):
                    let duration = beats * beatDuration
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }

            loopCount += 1
            guard !Task.isCancelled else { return }
            guard await isPlaying() else { return }
            let pause = pauseSeconds[min(loopCount - 1, pauseSeconds.count - 1)]
            try? await Task.sleep(nanoseconds: pause * 1_000_000_000)
        }
    }

    // MARK: - Serial Playback Loop

    private static func playSerialLoop(
        noteCache: [Int: [Int16]], fastNoteCache: [Int: [Int16]],
        transport: SerialTransport,
        beatDuration: Double, melody: [Event],
        isPlaying: @escaping () async -> Bool
    ) async {
        let targetRate: Double = 16000
        let chunkSize = 512
        // Escalating silence: 60s, 5min, then 15min forever
        let pauseSeconds: [UInt64] = [60, 300, 900]
        var loopCount = 0

        while !Task.isCancelled {
            guard await isPlaying() else { return }

            let loopStart = ContinuousClock.now
            var totalSamplesSent = 0

            for event in melody {
                guard !Task.isCancelled else { return }
                guard await isPlaying() else { return }

                switch event {
                case .note(let midi):
                    if let samples = noteCache[midi] {
                        totalSamplesSent += await streamSamples(
                            samples, transport: transport,
                            chunkSize: chunkSize, targetRate: targetRate,
                            startTime: loopStart, baseSampleOffset: totalSamplesSent
                        )
                    }

                case .fast(let midi):
                    if let samples = fastNoteCache[midi] {
                        totalSamplesSent += await streamSamples(
                            samples, transport: transport,
                            chunkSize: chunkSize, targetRate: targetRate,
                            startTime: loopStart, baseSampleOffset: totalSamplesSent
                        )
                    }

                case .rest(let beats):
                    let duration = beats * beatDuration
                    totalSamplesSent += Int(duration * targetRate)
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }

            loopCount += 1
            guard !Task.isCancelled else { return }
            guard await isPlaying() else { return }
            let pause = pauseSeconds[min(loopCount - 1, pauseSeconds.count - 1)]
            try? await Task.sleep(nanoseconds: pause * 1_000_000_000)
        }
    }

    /// Stream Int16 samples over serial in 512-sample chunks, paced to real-time.
    /// Returns the number of samples sent.
    private static func streamSamples(
        _ samples: [Int16], transport: SerialTransport,
        chunkSize: Int, targetRate: Double,
        startTime: ContinuousClock.Instant, baseSampleOffset: Int
    ) async -> Int {
        var sent = 0
        for offset in stride(from: 0, to: samples.count, by: chunkSize) {
            guard !Task.isCancelled, transport.inAudioMode else { break }

            let end = min(offset + chunkSize, samples.count)
            let chunk = samples[offset..<end]

            // Encode Int16 to little-endian bytes
            var payload = [UInt8]()
            payload.reserveCapacity(chunk.count * 2)
            for sample in chunk {
                payload.append(UInt8(truncatingIfNeeded: sample))
                payload.append(UInt8(truncatingIfNeeded: sample >> 8))
            }

            transport.writeFrame(tag: 0x01, payload: payload)
            sent += chunk.count

            // Pace to real-time
            let totalSent = baseSampleOffset + sent
            let targetElapsed = Double(totalSent) / targetRate
            let elapsed: Duration = ContinuousClock.now - startTime
            let actualElapsed = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let sleepTime = targetElapsed - actualElapsed
            if sleepTime > 0.001 {
                try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
            }
        }
        return sent
    }
}
