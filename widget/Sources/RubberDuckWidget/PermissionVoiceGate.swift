// Permission Voice Gate — Word-matching state machine for voice permissions.
//
// When Claude needs permission to use a tool, the duck asks out loud
// and listens for the user's response. This state machine processes
// transcripts and matches words like "yes", "no", "first", "second", etc.
// Pure logic — no audio dependencies, fully unit-testable.

import Foundation

struct PermissionVoiceGate {

    /// What the user decided.
    enum Decision {
        case allow                  // "yes", "yeah", "sure", etc.
        case deny                   // "no", "nope", "deny", etc.
        case selectOption(Int)      // "first", "second", etc. (1-based index)
        case repeatPrompt           // "repeat", "what?", "again"
        case noMatch                // Nothing recognized yet
    }

    /// Whether we're currently waiting for a permission response.
    var isWaiting = false

    /// Number of selectable options (from permission suggestions).
    var optionCount = 0

    /// The prompt text (for re-speaking on "repeat").
    var lastPrompt = ""

    // Word sets for matching
    private let affirmatives: Set<String> = ["yes", "yeah", "yep", "yup", "sure", "allow", "approve", "okay", "proceed", "accepted", "affirmative", "correct", "fine", "granted"]
    private let negatives: Set<String> = ["no", "nope", "deny", "block", "stop", "cancel", "reject", "refused", "negative", "nah", "pass", "skip", "not", "don't", "dont", "never"]
    private let repeatWords: Set<String> = ["repeat", "what", "again", "options", "huh"]
    private let ordinalWords = ["first", "second", "third", "fourth"]
    private let numberWords = ["one", "two", "three", "four"]

    /// Process a transcript and return the user's decision.
    /// Returns `.noMatch` if nothing was recognized.
    mutating func process(_ transcript: String) -> Decision {
        guard isWaiting else { return .noMatch }

        let words = Set(
            transcript.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .flatMap { $0.components(separatedBy: CharacterSet.punctuationCharacters) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )

        // "Repeat" / "what?" — re-speak the prompt
        if !words.isDisjoint(with: repeatWords) && words.isDisjoint(with: affirmatives) && words.isDisjoint(with: negatives) {
            return .repeatPrompt
        }

        // Ordinal words for picking a numbered suggestion
        for i in 0..<min(optionCount, ordinalWords.count) {
            if words.contains(ordinalWords[i]) || words.contains(numberWords[i]) {
                isWaiting = false
                return .selectOption(i + 1)  // 1-based
            }
        }

        // No before Yes — so "do not allow", "don't", "not okay" are caught
        // Negatives win when both match (e.g. "no, do not allow" has "allow" + "not")
        let hasNeg = !words.isDisjoint(with: negatives)
        let hasAff = !words.isDisjoint(with: affirmatives)
        if hasNeg {
            isWaiting = false
            return .deny
        } else if hasAff {
            isWaiting = false
            return .allow
        }

        return .noMatch
    }

    /// Begin waiting for a permission response.
    mutating func startWaiting(optionCount: Int, prompt: String) {
        self.isWaiting = true
        self.optionCount = optionCount
        self.lastPrompt = prompt
    }

    /// Reset the gate.
    mutating func reset() {
        isWaiting = false
        optionCount = 0
        lastPrompt = ""
    }
}
