// Mic Level Store — Thread-safe RMS meter for dashboard / troubleshooting.
//
// Updated from CoreAudio STT taps and serial PCM frames; read on MainActor
// for WebSocket broadcast.

import AVFoundation
import Foundation

final class MicLevelStore: @unchecked Sendable {
    private let lock = NSLock()
    private var level: Float = 0

    nonisolated func update(fromPCMBuffer buffer: AVAudioPCMBuffer) {
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        let chCount = Int(buffer.format.channelCount)
        guard chCount >= 1 else { return }

        var sum: Double = 0
        let denom = Double(n * chCount)

        if let floatData = buffer.floatChannelData {
            for ch in 0..<chCount {
                let ptr = floatData[ch]
                for i in 0..<n {
                    let s = Double(ptr[i])
                    sum += s * s
                }
            }
            let rms = sqrt(sum / denom)
            let normalized = Float(min(1.0, rms * 4.0))
            commit(normalized)
        } else if let intData = buffer.int16ChannelData {
            for ch in 0..<chCount {
                let ptr = intData[ch]
                for i in 0..<n {
                    let s = Double(ptr[i]) / 32768.0
                    sum += s * s
                }
            }
            let rms = sqrt(sum / denom)
            let normalized = Float(min(1.0, rms * 4.0))
            commit(normalized)
        }
    }

    nonisolated func update(fromInt16Mono ptr: UnsafePointer<Int16>, count: Int) {
        guard count > 0 else { return }
        var sum: Double = 0
        for i in 0..<count {
            let s = Double(ptr[i]) / 32768.0
            sum += s * s
        }
        let rms = sqrt(sum / Double(count))
        let normalized = Float(min(1.0, rms * 5.0))
        commit(normalized)
    }

    nonisolated func snapshot() -> Float {
        lock.lock()
        let v = level
        lock.unlock()
        return v
    }

    nonisolated func reset() {
        lock.lock()
        level = 0
        lock.unlock()
    }

    nonisolated private func commit(_ v: Float) {
        lock.lock()
        level = level * 0.6 + v * 0.4
        lock.unlock()
    }
}
