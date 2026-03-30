// Permission Voice Gate — Word-matching state machine for voice permissions.
//
// When Claude needs permission to use a tool, the duck asks out loud
// and listens for the user's response. This state machine processes
// transcripts and matches words like "yes", "no", "always allow", etc.
// Pure logic — no audio dependencies, fully unit-testable.
//
// Falls back to PermissionClassifier (Foundation Models) for ambiguous input.

import Foundation

struct PermissionVoiceGate {

    /// What the user decided.
    enum Decision {
        case allow                  // "yes", "yeah", "sure", etc.
        case deny                   // "no", "nope", "deny", etc.
        case selectOption(Int)      // "always allow", "first", etc. (1-based index)
        case repeatPrompt           // "repeat", "what?", "again"
        case noMatch                // Nothing recognized yet
    }

    /// Whether we're currently waiting for a permission response.
    var isWaiting = false

    /// Number of selectable options (from permission suggestions).
    var optionCount = 0

    /// TTS-friendly labels for each option (e.g. "always allow Edit for this session").
    var optionLabels: [String] = []

    /// The prompt text (for re-speaking on "repeat").
    var lastPrompt = ""

    /// Full prompt with option descriptions (for detailed re-speak).
    var fullPrompt = ""

    // Word sets for matching
    // Includes common STT misrecognitions of "allow" (e.g. "aloud", "a loud")
    private let affirmatives: Set<String> = [
        "yes", "yeah", "yep", "yup", "sure", "allow", "approve", "okay",
        "proceed", "accepted", "affirmative", "correct", "fine", "granted",
        "go", "do", "ahead", "aloud", "allowed", "loud",
    ]
    private let negatives: Set<String> = [
        "no", "nope", "deny", "block", "stop", "cancel", "reject",
        "refused", "negative", "nah", "pass", "skip", "not", "don't",
        "dont", "never",
    ]
    private let repeatWords: Set<String> = [
        "repeat", "what", "again", "options", "huh", "sorry",
    ]

    // Natural language phrases that map to option selection
    // These are checked as substrings of the full transcript
    private let alwaysAllowPhrases = ["always allow", "always", "from now on", "every time", "permanently"]
    private let justOncePhrases = ["just once", "this once", "one time", "only once", "just this"]

    // Ordinal/number words for explicit option picking
    private let ordinalWords = ["first", "second", "third", "fourth"]
    private let numberWords = ["one", "two", "three", "four"]

    /// Process a transcript and return the user's decision.
    /// Returns `.noMatch` if nothing was recognized.
    mutating func process(_ transcript: String) -> Decision {
        guard isWaiting else { return .noMatch }

        let lower = transcript.lowercased()
        let words = Set(
            lower
                .components(separatedBy: .whitespacesAndNewlines)
                .flatMap { $0.components(separatedBy: CharacterSet.punctuationCharacters) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )

        // "Repeat" / "what?" — re-speak the prompt (only if no allow/deny words)
        if !words.isDisjoint(with: repeatWords) && words.isDisjoint(with: affirmatives) && words.isDisjoint(with: negatives) {
            return .repeatPrompt
        }

        // Natural language option matching — check phrases in the full transcript
        if optionCount > 0 {
            // "Always allow" / "from now on" → pick the first "always allow" option
            if alwaysAllowPhrases.contains(where: { lower.contains($0) }) {
                if let idx = findAlwaysAllowOption() {
                    isWaiting = false
                    return .selectOption(idx)
                }
            }

            // "Just once" / "this once" → simple allow (no suggestion)
            if justOncePhrases.contains(where: { lower.contains($0) }) {
                isWaiting = false
                return .allow
            }

            // Ordinal words for explicit picking: "first", "second", etc.
            for i in 0..<min(optionCount, ordinalWords.count) {
                if words.contains(ordinalWords[i]) || words.contains(numberWords[i]) {
                    isWaiting = false
                    return .selectOption(i + 1)  // 1-based
                }
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

    /// Find the best "always allow" option.
    /// Prefers the last matching label — Claude Code typically puts the broadest
    /// (most useful) "always allow" suggestion last, and narrower read-path
    /// rules first. Falling back to the last option if none match explicitly.
    private func findAlwaysAllowOption() -> Int? {
        var lastMatch: Int?
        for (i, label) in optionLabels.enumerated() {
            if label.lowercased().contains("always allow") {
                lastMatch = i + 1  // 1-based
            }
        }
        // Fall back to last option — more likely to be the tool-level rule
        return lastMatch ?? (optionCount > 0 ? optionCount : nil)
    }

    /// Begin waiting for a permission response.
    mutating func startWaiting(optionCount: Int, optionLabels: [String] = [], prompt: String, fullPrompt: String = "") {
        self.isWaiting = true
        self.optionCount = optionCount
        self.optionLabels = optionLabels
        self.lastPrompt = prompt
        self.fullPrompt = fullPrompt.isEmpty ? prompt : fullPrompt
    }

    /// Reset the gate.
    mutating func reset() {
        isWaiting = false
        optionCount = 0
        optionLabels = []
        lastPrompt = ""
        fullPrompt = ""
    }
}
