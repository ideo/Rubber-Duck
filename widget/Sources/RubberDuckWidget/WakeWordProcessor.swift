// Wake Word Processor — State machine for "ducky" detection and command extraction.
//
// Processes STT transcripts to detect the wake word, extract the command
// text that follows, and handle debounce timing. Pure logic — no audio
// dependencies, fully unit-testable.

import Foundation

struct WakeWordProcessor {
    var wakeWord: String = "ducky"

    /// Result of processing a transcript.
    enum Result {
        case nothing                    // No wake word found
        case wakeWordOnly               // Heard "ducky" but no command text yet
        case command(String)            // Heard "ducky <command>" — ready to send
        case quit                       // Heard "ducky quit/exit/stop/bye"
    }

    /// Whether we've detected the wake word in the current recognition cycle.
    private(set) var isAwake = false

    /// The latest command text after the wake word (may be partial).
    private(set) var pendingText = ""

    private let quitWords: Set<String> = ["quit", "exit", "stop", "bye"]

    /// Process an incoming transcript and return what happened.
    /// - Parameters:
    ///   - transcript: Full transcript from speech recognizer
    ///   - isFinal: Whether this is the final result from the recognizer
    /// - Returns: What the processor detected
    mutating func process(_ transcript: String, isFinal: Bool) -> Result {
        // Case-insensitive search directly on the original transcript
        guard let range = transcript.range(of: wakeWord, options: .caseInsensitive) else {
            return .nothing
        }

        let afterWake = String(transcript[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // First time seeing the wake word this cycle
        if !isAwake {
            isAwake = true
        }

        pendingText = afterWake

        // No command text yet — just the wake word
        if afterWake.isEmpty {
            return .wakeWordOnly
        }

        // Check for quit commands
        if quitWords.contains(afterWake.lowercased()) {
            return .quit
        }

        // We have command text — if final, send immediately
        if isFinal {
            return .command(afterWake)
        }

        // Partial transcript — caller should debounce before treating as final
        return .command(afterWake)
    }

    /// Reset state for the next recognition cycle.
    mutating func reset() {
        isAwake = false
        pendingText = ""
    }
}
