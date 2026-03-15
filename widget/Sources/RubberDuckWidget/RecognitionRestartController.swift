// Recognition Restart Controller — shared restart + watchdog logic for STT engines.
//
// Both STTEngine (CoreAudio) and SerialMicEngine (serial PDM) need identical
// exponential-backoff restart and 10-second silence watchdog. This class
// extracts that pattern so both engines delegate to a single implementation.

import Foundation

/// Manages restart attempts with exponential backoff and a silence watchdog.
/// Must be used from @MainActor (same as both STT engines).
@MainActor
final class RecognitionRestartController {
    private let label: String
    private let maxAttempts: Int
    private let watchdogTimeout: UInt64 // nanoseconds

    private var attempts = 0
    private var watchdogTask: Task<Void, Never>?

    /// Called when a restart should happen (after backoff delay).
    var onRestart: (() -> Void)?

    init(label: String, maxAttempts: Int = 5, watchdogTimeoutSeconds: Int = 10) {
        self.label = label
        self.maxAttempts = maxAttempts
        self.watchdogTimeout = UInt64(watchdogTimeoutSeconds) * 1_000_000_000
    }

    /// Schedule a restart with exponential backoff.
    /// Returns false if max attempts exceeded.
    func scheduleRestart(isListening: Bool) {
        attempts += 1
        if attempts > maxAttempts {
            DuckLog.log("[\(label)] Too many restart attempts (\(attempts)). Giving up.")
            return
        }

        let delay = UInt64(pow(2.0, Double(attempts - 1))) * 1_000_000_000
        DuckLog.log("[\(label)] Restarting in \(attempts)s (attempt \(attempts)/\(maxAttempts))...")

        Task {
            try? await Task.sleep(nanoseconds: delay)
            if !isListening {
                self.onRestart?()
            }
        }
    }

    /// Reset attempt counter (e.g. after successful recognition or device change).
    func resetAttempts() {
        attempts = 0
    }

    /// Pet the watchdog — recognition is still alive.
    func resetWatchdog(isListening: Bool) {
        watchdogTask?.cancel()
        watchdogTask = Task {
            try? await Task.sleep(nanoseconds: watchdogTimeout)
            if !Task.isCancelled && isListening {
                DuckLog.log("[\(label)] Watchdog: recognition silent for \(watchdogTimeout / 1_000_000_000)s, restarting...")
                self.attempts = 0
                self.onRestart?()
            }
        }
    }

    /// Cancel the watchdog (e.g. on stop).
    func cancelWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }
}
