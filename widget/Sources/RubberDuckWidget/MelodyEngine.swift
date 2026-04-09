// Melody Engine — Hums the Jeopardy "Think!" theme during permission waits.
//
// Uses AVAudioEngine to pitch-shift a vocal sample ("Mmmm" by Ralph)
// through the Final Jeopardy melody notes. The duck literally hums while
// waiting for the user to say yes or no.
//
// Each note plays the sample once at the shifted pitch (no looping, no
// stretching). Fast notes trim the sample short for rapid runs. Rests
// are silence. Like a piano — you hit the key, it plays, you move on.
//
// Sample: ~0.58s of "Mmmm" at F3 (MIDI 53). Melody ranges F3-A4,
// max +16 semitones. Tempo: 90 BPM.
//
// Routes audio to the same output device as TTS (Teensy if connected).

import AVFoundation
import CoreAudio

@MainActor
class MelodyEngine {

    // Audio graph — created once, reused across start/stop cycles.
    // Tearing down AVAudioEngine mid-playback can crash the audio render
    // thread and corrupt other dispatch queues (including NWListener).
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var pitchUnit: AVAudioUnitTimePitch?

    private var buffer: AVAudioPCMBuffer?
    private var fastBuffer: AVAudioPCMBuffer?  // Trimmed buffer for fast notes
    private var melodyTask: Task<Void, Never>?
    private(set) var isPlaying = false

    /// Output device ID — set to Teensy's AudioDeviceID to route there.
    /// When nil, plays through system default output.
    var outputDeviceID: AudioDeviceID? {
        didSet {
            // Re-route if we have a running engine
            if let engine = engine {
                if let deviceID = outputDeviceID {
                    setOutputDevice(engine: engine, deviceID: deviceID)
                }
            }
        }
    }

    // Base pitch of the "Mmmm" sample — Ralph at roughly F3 (MIDI 53)
    private let baseMIDI: Float = 53.0

    // Volume: quiet enough to hear over, loud enough to be charming
    private let melodyVolume: Float = 0.35

    // Tempo: 90 BPM
    private let bpm: Double = 90.0
    private var beatDuration: Double { 60.0 / bpm }

    // Natural sample duration (~0.58s) — notes play for this long
    private var sampleDuration: Double = 0.58

    // Fast note trim duration (half the sample — for rapid runs)
    private let fastTrim: Double = 0.29

    // MARK: - Jeopardy "Think!" Melody

    private enum Event {
        case note(Int)           // Play at natural sample length
        case fast(Int)           // Play trimmed for rapid runs
        case rest(Double)        // Silence for N beats
    }

    private let melody: [Event] = [
        // Bars 1-2: bum-bum-bum-bum-bum-bum-bum (rest)
        .note(60), .note(65), .note(60), .note(53),
        .note(60), .note(65), .note(60), .rest(1.0),

        // Bars 3-4: bum-bum-bum-bum-BUM (rest) bupbupbupbupbup (rest)
        .note(60), .note(65), .note(60), .note(65), .note(69), .rest(0.5),
        .fast(67), .fast(65), .fast(64), .fast(62), .fast(61), .rest(0.5),

        // Bars 5-6: repeat of 1-2
        .note(60), .note(65), .note(60), .note(53),
        .note(60), .note(65), .note(60), .rest(1.0),

        // Bars 7-8: resolving descent
        .note(65), .rest(0.5), .fast(62), .note(60), .note(58),
        .note(57), .rest(0.75), .note(55), .rest(0.75), .note(53), .rest(1.0),
    ]

    // MARK: - Start / Stop

    func start() {
        guard !isPlaying else { return }
        guard loadBuffer() else {
            DuckLog.log("[melody] Failed to load mmmm.aiff — no humming today")
            return
        }

        // Create the audio graph once — reuse across start/stop cycles
        if engine == nil {
            let eng = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            pitch.rate = 1.0

            eng.attach(player)
            eng.attach(pitch)

            let format = buffer!.format
            eng.connect(player, to: pitch, format: format)
            eng.connect(pitch, to: eng.mainMixerNode, format: format)

            player.volume = melodyVolume

            self.engine = eng
            self.playerNode = player
            self.pitchUnit = pitch
        }

        guard let engine = engine, let player = playerNode, let pitch = pitchUnit else { return }

        // Route to device if configured
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

        // Run melody loop OFF MainActor so scheduleBuffer awaits don't starve the UI.
        let capturedPlayer = player
        let capturedPitch = pitch
        let buf = buffer!
        let fastBuf = fastBuffer ?? buffer!
        let baseMIDI = baseMIDI
        let sampleDuration = sampleDuration
        let fastTrim = fastTrim
        let beatDuration = beatDuration
        let melody = melody
        melodyTask = Task.detached { [weak self] in
            await Self.playMelodyLoop(
                player: capturedPlayer, pitch: capturedPitch,
                buffer: buf, fastBuffer: fastBuf,
                baseMIDI: baseMIDI, sampleDuration: sampleDuration,
                fastTrim: fastTrim, beatDuration: beatDuration,
                melody: melody, isPlaying: { await self?.isPlaying ?? false }
            )
        }

        DuckLog.log("[melody] Jeopardy humming started")
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        melodyTask?.cancel()
        melodyTask = nil

        // Just stop the player — don't tear down the engine.
        // The detached task may still hold references to the player/pitch nodes.
        // Stopping the player is safe from any thread; destroying the engine is not.
        playerNode?.stop()

        DuckLog.log("[melody] Jeopardy humming stopped")
    }

    // MARK: - Audio Output Routing

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

    // MARK: - Internals

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

            // Create a trimmed buffer for fast notes (half the sample with fade-out)
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

    /// Static melody loop — runs OFF MainActor so audio awaits don't block the UI.
    private static func playMelodyLoop(
        player: AVAudioPlayerNode, pitch: AVAudioUnitTimePitch,
        buffer: AVAudioPCMBuffer, fastBuffer: AVAudioPCMBuffer,
        baseMIDI: Float, sampleDuration: Double, fastTrim: Double,
        beatDuration: Double, melody: [Event],
        isPlaying: @escaping () async -> Bool
    ) async {
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

            // Breath between loops
            guard !Task.isCancelled else { return }
            guard await isPlaying() else { return }
            try? await Task.sleep(nanoseconds: UInt64(2.0 * beatDuration * 1_000_000_000))
        }
    }
}
