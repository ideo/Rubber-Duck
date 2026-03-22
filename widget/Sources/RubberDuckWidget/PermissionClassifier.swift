// Permission Classifier — Foundation Models fallback for ambiguous voice input.
//
// When the word-matching fast path in PermissionVoiceGate returns .noMatch,
// this classifier uses Apple's on-device ~3B model to interpret the user's
// intent. Keeps voice permissions natural — "uh, I guess so" → allow.
//
// Only called for ambiguous transcripts. Clear "yes"/"no" never reaches here.

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Intent

@Generable
struct PermissionIntent {
    @Guide(description: "The user's intent: allow, deny, selectOption, repeat, or unclear")
    var decision: String

    @Guide(description: "1-based option index if decision is selectOption, otherwise 0",
           .range(0...10))
    var optionIndex: Int

    @Guide(description: "Confidence from 0 to 100. 100=absolutely certain, 50=guessing",
           .range(0...100))
    var confidence: Int
}

// MARK: - Permission Classifier Actor

actor PermissionClassifier {

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    /// Classify a transcript into a permission decision.
    /// Returns nil if confidence is too low or the model is unavailable.
    func classify(
        transcript: String,
        optionLabels: [String]
    ) async -> PermissionVoiceGate.Decision? {
        let optionsDesc: String
        if optionLabels.isEmpty {
            optionsDesc = "No extra options. Only allow or deny."
        } else {
            let numbered = optionLabels.enumerated().map { "  \($0.offset + 1). \($0.element)" }
            optionsDesc = "Available options:\n" + numbered.joined(separator: "\n")
        }

        let systemPrompt = """
            You classify voice responses to a yes/no permission prompt. \
            The user was asked whether to allow a coding tool action. \
            Classify their spoken response as: allow, deny, selectOption, repeat, or unclear. \
            If they want one of the numbered options, set decision to selectOption and optionIndex to the number. \
            If they seem confused or asking a question, classify as repeat. \
            If you genuinely cannot tell, classify as unclear with low confidence.
            """

        let userPrompt = """
            The user said: "\(transcript)"

            \(optionsDesc)

            What is the user's intent?
            """

        do {
            let session = LanguageModelSession(instructions: Instructions(systemPrompt))
            let result = try await session.respond(
                to: userPrompt,
                generating: PermissionIntent.self
            )
            let intent = result.content

            DuckLog.log("[classifier] transcript=\"\(transcript)\" → decision=\(intent.decision) confidence=\(intent.confidence) optionIndex=\(intent.optionIndex)")

            // High confidence threshold — we're making permission decisions
            guard intent.confidence >= 60 else {
                DuckLog.log("[classifier] Low confidence (\(intent.confidence)), asking to repeat")
                return .repeatPrompt
            }

            switch intent.decision.lowercased() {
            case "allow":
                return .allow
            case "deny":
                return .deny
            case "selectoption", "select_option", "select option":
                if intent.optionIndex > 0 {
                    return .selectOption(intent.optionIndex)
                }
                return .allow  // Wanted to select but no valid index → treat as allow
            case "repeat":
                return .repeatPrompt
            default:
                // "unclear" or unexpected → ask to repeat
                return .repeatPrompt
            }
        } catch {
            DuckLog.log("[classifier] Error: \(error.localizedDescription)")
            return nil
        }
    }
}

#else

// MARK: - Stub for non-Apple-Silicon / pre-macOS-26 builds

actor PermissionClassifier {
    static var isAvailable: Bool { false }

    func classify(
        transcript: String,
        optionLabels: [String]
    ) async -> PermissionVoiceGate.Decision? {
        nil
    }
}

#endif
