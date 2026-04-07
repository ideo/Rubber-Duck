// Mic Health Monitor — conservative duck-mic failure detection.
//
// Tracks the active duck mic path and only reports failure on strong evidence:
// missing buffers, repeated identical buffers, or explicit device/format errors.
// Low volume alone is treated as suspect at most, never as an automatic failure.

import AVFoundation
import Foundation

enum MicHealthState: String {
    case inactive
    case healthy
    case suspect
    case failed
}

struct MicHealthSnapshot: Sendable {
    let state: MicHealthState
    let reason: String?
    let healthyBufferStreak: Int
    let monitoringEnabled: Bool
    let lastBufferAge: TimeInterval?
}

final class MicHealthMonitor: @unchecked Sendable {
    private let lock = NSLock()

    private var monitoringEnabled = false
    private var expectsContinuousBuffers = false
    private var state: MicHealthState = .inactive
    private var reason: String?

    private var sessionStartedAt = Date.timeIntervalSinceReferenceDate
    private var lastBufferAt: TimeInterval?
    private var lastActivityAt: TimeInterval?
    private var lastSignature: UInt64?

    private var healthyBufferStreak = 0
    private var deadBufferStreak = 0
    private var repeatedBufferStreak = 0

    private let initialBufferTimeout: TimeInterval = 2.0
    private let stalledBufferTimeout: TimeInterval = 1.5
    private let suspectDeadThreshold = 20
    private let failedDeadThreshold = 60
    private let suspectRepeatedThreshold = 12
    private let failedRepeatedThreshold = 40
    private let healthyThreshold = 6

    nonisolated func activate(monitorDuckPath: Bool, expectsContinuousBuffers: Bool) {
        lock.lock()
        defer { lock.unlock() }

        monitoringEnabled = monitorDuckPath
        self.expectsContinuousBuffers = monitorDuckPath && expectsContinuousBuffers
        sessionStartedAt = now()
        lastBufferAt = nil
        lastActivityAt = nil
        lastSignature = nil
        healthyBufferStreak = 0
        deadBufferStreak = 0
        repeatedBufferStreak = 0
        state = monitorDuckPath ? .suspect : .inactive
        reason = monitorDuckPath ? "waiting for duck audio" : nil
    }

    nonisolated func deactivate() {
        lock.lock()
        monitoringEnabled = false
        expectsContinuousBuffers = false
        state = .inactive
        reason = nil
        lastBufferAt = nil
        lastActivityAt = nil
        lastSignature = nil
        healthyBufferStreak = 0
        deadBufferStreak = 0
        repeatedBufferStreak = 0
        lock.unlock()
    }

    nonisolated func noteMutedFrame() {
        lock.lock()
        if monitoringEnabled {
            lastActivityAt = now()
        }
        lock.unlock()
    }

    nonisolated func noteHardFailure(_ reason: String) {
        lock.lock()
        guard monitoringEnabled else {
            lock.unlock()
            return
        }
        state = .failed
        self.reason = reason
        lock.unlock()
    }

    nonisolated func update(fromPCMBuffer buffer: AVAudioPCMBuffer) {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        if let floatData = buffer.floatChannelData {
            let channelCount = Int(buffer.format.channelCount)
            let analysis = analyzeFloatBuffer(floatData: floatData, frameCount: frameCount, channelCount: channelCount)
            commit(analysis)
        } else if let intData = buffer.int16ChannelData {
            let channelCount = Int(buffer.format.channelCount)
            let analysis = analyzeInt16Buffer(intData: intData, frameCount: frameCount, channelCount: channelCount)
            commit(analysis)
        }
    }

    nonisolated func update(fromInt16Mono ptr: UnsafePointer<Int16>, count: Int) {
        guard count > 0 else { return }

        var sum: Double = 0
        var peak: Double = 0
        var zeroCount = 0
        var signature: UInt64 = 1469598103934665603

        for i in 0..<count {
            let sample = ptr[i]
            if sample == 0 { zeroCount += 1 }
            let normalized = Double(sample) / 32768.0
            let absValue = abs(normalized)
            sum += normalized * normalized
            peak = max(peak, absValue)
            if i < 64 {
                signature ^= UInt64(UInt16(bitPattern: sample))
                signature &*= 1099511628211
            }
        }

        let rms = sqrt(sum / Double(count))
        let zeroRatio = Double(zeroCount) / Double(count)
        commit((rms, peak, zeroRatio, signature))
    }

    nonisolated func snapshot(suppressTimeouts: Bool) -> MicHealthSnapshot {
        lock.lock()
        if monitoringEnabled && expectsContinuousBuffers && !suppressTimeouts {
            let now = self.now()
            let anchor = lastActivityAt ?? lastBufferAt ?? sessionStartedAt
            let timedOut = (lastBufferAt == nil && now - sessionStartedAt > initialBufferTimeout)
                || (lastBufferAt != nil && now - anchor > stalledBufferTimeout)
            if timedOut {
                state = .failed
                reason = (lastBufferAt == nil)
                    ? "no duck mic audio arrived"
                    : "duck mic stream stalled"
            }
        }

        let age = lastBufferAt.map { max(0, self.now() - $0) }
        let snapshot = MicHealthSnapshot(
            state: state,
            reason: reason,
            healthyBufferStreak: healthyBufferStreak,
            monitoringEnabled: monitoringEnabled,
            lastBufferAge: age
        )
        lock.unlock()
        return snapshot
    }

    private typealias Analysis = (rms: Double, peak: Double, zeroRatio: Double, signature: UInt64)

    nonisolated private func commit(_ analysis: Analysis) {
        lock.lock()
        guard monitoringEnabled else {
            lock.unlock()
            return
        }

        let identical = (lastSignature == analysis.signature)
        lastSignature = analysis.signature
        lastBufferAt = now()
        lastActivityAt = lastBufferAt

        let allZero = analysis.zeroRatio > 0.999 && analysis.peak < 0.0001
        let deadBuffer = allZero && identical
        let clearlyHealthy = !identical && !allZero && (analysis.peak > 0.01 || analysis.rms > 0.002)

        repeatedBufferStreak = identical ? repeatedBufferStreak + 1 : 0
        deadBufferStreak = deadBuffer ? deadBufferStreak + 1 : 0
        healthyBufferStreak = clearlyHealthy ? healthyBufferStreak + 1 : 0

        if deadBufferStreak >= failedDeadThreshold {
            state = .failed
            reason = "duck mic is sending repeated silent buffers"
        } else if repeatedBufferStreak >= failedRepeatedThreshold {
            state = .failed
            reason = "duck mic is repeating identical audio frames"
        } else if deadBufferStreak >= suspectDeadThreshold {
            if state != .failed {
                state = .suspect
                reason = "duck mic looks unnaturally silent"
            }
        } else if repeatedBufferStreak >= suspectRepeatedThreshold {
            if state != .failed {
                state = .suspect
                reason = "duck mic audio is unusually repetitive"
            }
        } else if healthyBufferStreak >= healthyThreshold {
            state = .healthy
            reason = nil
        }

        lock.unlock()
    }

    nonisolated private func analyzeFloatBuffer(
        floatData: UnsafePointer<UnsafeMutablePointer<Float>>,
        frameCount: Int,
        channelCount: Int
    ) -> Analysis {
        var sum: Double = 0
        var peak: Double = 0
        var zeroCount = 0
        let totalSampleCount = frameCount * max(channelCount, 1)
        var signature: UInt64 = 1469598103934665603

        for channel in 0..<channelCount {
            let ptr = floatData[channel]
            for index in 0..<frameCount {
                let sample = ptr[index]
                if abs(sample) < 0.000001 { zeroCount += 1 }
                let value = Double(sample)
                let absValue = abs(value)
                sum += value * value
                peak = max(peak, absValue)
                if index < 64 {
                    let quantized = Int16(max(-32768, min(32767, Int(sample * 32767))))
                    signature ^= UInt64(UInt16(bitPattern: quantized))
                    signature &*= 1099511628211
                }
            }
        }

        return (
            rms: sqrt(sum / Double(totalSampleCount)),
            peak: peak,
            zeroRatio: Double(zeroCount) / Double(totalSampleCount),
            signature: signature
        )
    }

    nonisolated private func analyzeInt16Buffer(
        intData: UnsafePointer<UnsafeMutablePointer<Int16>>,
        frameCount: Int,
        channelCount: Int
    ) -> Analysis {
        var sum: Double = 0
        var peak: Double = 0
        var zeroCount = 0
        let totalSampleCount = frameCount * max(channelCount, 1)
        var signature: UInt64 = 1469598103934665603

        for channel in 0..<channelCount {
            let ptr = intData[channel]
            for index in 0..<frameCount {
                let sample = ptr[index]
                if sample == 0 { zeroCount += 1 }
                let normalized = Double(sample) / 32768.0
                let absValue = abs(normalized)
                sum += normalized * normalized
                peak = max(peak, absValue)
                if index < 64 {
                    signature ^= UInt64(UInt16(bitPattern: sample))
                    signature &*= 1099511628211
                }
            }
        }

        return (
            rms: sqrt(sum / Double(totalSampleCount)),
            peak: peak,
            zeroRatio: Double(zeroCount) / Double(totalSampleCount),
            signature: signature
        )
    }

    nonisolated private func now() -> TimeInterval {
        Date.timeIntervalSinceReferenceDate
    }
}
