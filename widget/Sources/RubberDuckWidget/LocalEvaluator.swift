// Local Evaluator — Scores text via Apple Foundation Models on-device (~3B).
//
// Uses the tuned V3 prompt (see widget/Playground/ for iteration notes).
// Maps Foundation Models dimension names (rigor/craft/novelty) back to
// production names (soundness/elegance/creativity). See FOUNDATION-MODELS-RESEARCH.md.
//
// Requires macOS 26 + Apple Silicon. Falls back gracefully when unavailable.

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Eval Result (V3 tuned prompt)
//
// @Generable must be at file scope. .range() constrains output at JSON schema level.
// See docs/FOUNDATION-MODELS-RESEARCH.md for why each dimension uses its specific style.

@Generable
struct LocalEvalResult {
    @Guide(description: "Engineering rigor. -100=reckless/no safeguards, -50=sloppy, 0=adequate, 50=thorough, 100=meticulous with full test coverage. Ask: how careful and disciplined is this work?",
           .range(-100...100))
    var rigor: Int

    @Guide(description: "Craft. How well-made is this work? 0=acceptable, 50=well-crafted, 100=masterful. High craft means the right solution with no wasted effort.",
           .range(-100...100))
    var craft: Int

    @Guide(description: "Novelty. How new is this idea? 0=standard practice, 50=fresh approach, 100=never been done before. Ask: is this a known pattern or something original?",
           .range(-100...100))
    var novelty: Int

    @Guide(description: "Ambition. -100=trivial, -50=routine, 0=moderate, 50=substantial, 100=massive. A typo fix is very negative. Rewriting an entire system is very positive.",
           .range(-100...100))
    var ambition: Int

    @Guide(description: "Danger level. -100=completely safe change, 0=moderate, 100=could break everything. A working fix with zero regression is safe (negative). Deleting files or rewriting systems is dangerous (high). Fixing a typo is very safe (very negative).",
           .range(-100...100))
    var risk: Int

    @Guide(description: "Short snarky gut reaction, max 10 words")
    var reaction: String

    @Guide(description: "One blunt sentence describing what happened")
    var summary: String
}

// MARK: - Local Evaluator Actor

actor LocalEvaluator {

    private static let systemPrompt = """
        You are an opinionated rubber duck on a developer's desk. You watch them talk \
        to an AI coding assistant and judge everything you see.

        Score 5 dimensions from -100 to 100. \
        DO NOT default to zero. \
        DO NOT give all dimensions the same score. \
        DO NOT cluster scores near the middle. \
        Each score MUST reflect the specific text you are evaluating.

        Scores near 0 mean average/unremarkable. \
        Scores above 50 or below -50 mean something notable happened. \
        Use the extremes (-80 to -100 or 80 to 100) only for truly exceptional cases.

        For reactions: speak as the coding assistant's inner monologue about what just happened. \
        Use first person. Be snarky and specific to the actual code change. DO NOT be generic.

        For summaries: tell the developer what their AI assistant just did. \
        Be specific about the actual change. DO NOT be generic.
        """

    /// Check if Foundation Models is available on this device.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    func evaluate(text: String, source: String, userContext: String = "", claudeContext: String = "") async throws -> EvalScores {
        let userPrompt = EvalPromptBuilder.buildPrompt(
            text: text, source: source,
            userContext: userContext, claudeContext: claudeContext,
            maxTextLength: 3000  // Foundation Models ~4K token window
        )

        let session = LanguageModelSession(instructions: Instructions(Self.systemPrompt))
        let options = GenerationOptions(temperature: 0.7)
        let result = try await session.respond(
            to: userPrompt,
            generating: LocalEvalResult.self,
            options: options
        )

        let r = result.content

        // Map V3 names (rigor/craft/novelty) → production names (soundness/elegance/creativity)
        // Map Int -100...100 → Double -1.0...1.0
        return EvalScores(
            creativity: Double(r.novelty) / 100.0,
            soundness: Double(r.rigor) / 100.0,
            ambition: Double(r.ambition) / 100.0,
            elegance: Double(r.craft) / 100.0,
            risk: Double(r.risk) / 100.0,
            reaction: r.reaction,
            summary: r.summary
        )
    }
}

#else

// MARK: - Stub for non-Apple-Silicon / pre-macOS-26 builds

actor LocalEvaluator {
    static var isAvailable: Bool { false }

    func evaluate(text: String, source: String, userContext: String = "", claudeContext: String = "") async throws -> EvalScores {
        EvalScores(
            creativity: 0, soundness: 0, ambition: 0,
            elegance: 0, risk: 0,
            reaction: "No on-device model",
            summary: "Foundation Models not available on this device"
        )
    }
}

#endif
