// SineGenerator — Week 1 test source.
//
// Generates 20ms chunks of int16 LE PCM mono @ 16000 Hz and ships them to
// every connected duck on a 20ms tick. This is the simplest possible
// audio source we can throw at the protocol to verify the loop is closed:
// if the duck wobbles its head to a steady tone, the wire works.
//
// Each duck gets a different pitch so it's audibly obvious that channel
// routing is correct (no accidental "all ducks playing D1's stream").

import Foundation
import Dispatch

/// Pitch per duck. Recognizable as four distinct notes in a chord.
private let pitchHz: [DuckID: Double] = [
    .D1: 261.63,  // C4
    .D2: 329.63,  // E4
    .D3: 392.00,  // G4
    .D4: 523.25,  // C5
]

private let sampleRate: Double = 16000
private let chunkMs: Double = 20
private let samplesPerChunk = Int(sampleRate * chunkMs / 1000) // 320

final class SineGenerator: @unchecked Sendable {
    private let server: StageServer
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "boyband.stage.sine")
    /// Per-duck running phase. Continuity matters — restarting the phase
    /// at every chunk would click.
    private var phase: [DuckID: Double] = [:]
    /// Amplitude scaler (0..1). 0.2 ≈ -14 dBFS, plenty audible without
    /// clipping when summed with other things later.
    private let amplitude: Double = 0.2
    /// When set, only this duck gets sine; others get silence. Lets the
    /// operator solo a single duck for sound check.
    private var solo: DuckID?

    init(server: StageServer) {
        self.server = server
    }

    func start(solo: DuckID? = nil) {
        self.solo = solo
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(Int(chunkMs)))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        for conn in server.activeConnections() {
            let duck = conn.duck
            let active = (solo == nil || solo == duck)
            let pcm = active ? renderSine(duck: duck) : silence()
            conn.sendPCM(pcm)
        }
    }

    private func renderSine(duck: DuckID) -> Data {
        let freq = pitchHz[duck] ?? 440
        let twoPi = 2.0 * Double.pi
        let phaseInc = twoPi * freq / sampleRate
        var current = phase[duck] ?? 0

        var bytes = Data(capacity: samplesPerChunk * 2)
        for _ in 0..<samplesPerChunk {
            let sample = sin(current) * amplitude
            let s16 = Int16(max(-1.0, min(1.0, sample)) * Double(Int16.max))
            // int16 LE
            bytes.append(UInt8(truncatingIfNeeded: s16))
            bytes.append(UInt8(truncatingIfNeeded: Int(s16) >> 8))
            current += phaseInc
            if current >= twoPi { current -= twoPi }
        }
        phase[duck] = current
        return bytes
    }

    private func silence() -> Data {
        Data(repeating: 0, count: samplesPerChunk * 2)
    }
}
