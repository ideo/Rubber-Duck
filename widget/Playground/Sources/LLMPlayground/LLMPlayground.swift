// LLM Playground — Interactive prompt iteration for Foundation Models eval.
//
// Open widget/Playground/Package.swift in Xcode (NOT the main Package.swift).
// This is a library target so #Playground blocks work without ENABLE_DEBUG_DYLIB.
// Navigate to this file and the Canvas shows each #Playground block independently.
//
// Once prompts are tuned, copy the @Generable struct + prompt into production code.
//
// VERSION HISTORY:
// V1: Double -1.0...1.0 — clamped to integers (-1, 0, 1). Unusable.
// V2: Int -100...100 + few-shot examples — great spread but parroted example values.
// V3: Int -100...100 + NO few-shot scores + temperature 0.2 + stronger DO NOT directives.

#if canImport(FoundationModels)
import FoundationModels

// MARK: - V3 Generable Eval Result
//
// Changes from V2:
// - Removed few-shot score examples (caused parroting — model copied values verbatim)
// - Added temperature 0.2 via GenerationOptions (less random, more precise)
// - Stronger DO NOT directives (Apple says all-caps commands work well on 3B model)
// - Reordered: soundness first (foundational), risk last (depends on understanding others)
// - Kept Int -100...100 scale (proven to break integer clamping)
// - Kept rich @Guide anchors (proven to help differentiation)

@Generable
struct LocalEvalResultV3 {
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

enum LocalEvalPromptsV3 {
    static let system = """
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
}

// MARK: - Playground Blocks (Xcode Canvas only)

#if canImport(Playgrounds)
import Playgrounds

// MARK: - Availability check

#Playground {
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        print("Foundation Models: AVAILABLE")
    case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible:
            print("Foundation Models: device not eligible (needs Apple Silicon)")
        case .appleIntelligenceNotEnabled:
            print("Foundation Models: Apple Intelligence not enabled in System Settings")
        case .modelNotReady:
            print("Foundation Models: model still downloading...")
        @unknown default:
            print("Foundation Models: unavailable (unknown reason)")
        }
    @unknown default:
        print("Foundation Models: unknown status")
    }
}

// MARK: - V3: Trivial prompt (expect: low ambition, low risk, low creativity)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.2)
    let result = try await session.respond(
        to: """
            Source: user
            Text to evaluate:
            fix the typo in the readme
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== V3: fix typo ===")
    print("soundness: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition:  \(r.ambition)   risk:     \(r.risk)")
    print("reaction:  \(r.reaction)")
    print("summary:   \(r.summary)")
}

// MARK: - V3: Auth refactor (expect: moderate ambition, moderate risk)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.2)
    let result = try await session.respond(
        to: """
            Source: user
            Text to evaluate:
            refactor the auth module to use JWT tokens instead of session cookies
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== V3: auth refactor ===")
    print("soundness: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition:  \(r.ambition)   risk:     \(r.risk)")
    print("reaction:  \(r.reaction)")
    print("summary:   \(r.summary)")
}

// MARK: - V3: Bold rewrite (expect: high ambition, high creativity, high risk)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.2)
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): help me optimize the database
            Text to evaluate:
            I've rewritten your entire data layer. Replaced PostgreSQL with a custom \
            append-only log structure, added a query compiler that generates native ARM \
            SIMD instructions, and removed the ORM entirely. All 847 tests pass. The \
            benchmarks show 340x improvement on reads.
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== V3: bold rewrite ===")
    print("soundness: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition:  \(r.ambition)   risk:     \(r.risk)")
    print("reaction:  \(r.reaction)")
    print("summary:   \(r.summary)")
}

// MARK: - V3: Risky deletion (expect: HIGH risk, LOW soundness)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.2)
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): clean up the test suite
            Text to evaluate:
            I deleted all 200 test files. They were mostly testing implementation details \
            rather than behavior. I'll write new ones from scratch using property-based testing.
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== V3: delete all tests ===")
    print("soundness: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition:  \(r.ambition)   risk:     \(r.risk)")
    print("reaction:  \(r.reaction)")
    print("summary:   \(r.summary)")
}

// MARK: - V3: Big breakthrough (expect: high soundness, high ambition, low risk)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.2)
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): the Xcode playground blocks aren't working, \
            ENABLE_DEBUG_DYLIB keeps failing for our SPM executable target
            Text to evaluate:
            Got it working. Created an isolated playground package at widget/Playground/ — \
            library target only, so no ENABLE_DEBUG_DYLIB needed. The @Generable struct with \
            .range(-1.0...1.0) constraints compiles and runs perfectly in the Canvas. All 5 \
            test scenarios execute in under 3 seconds each on the Foundation model. The \
            production code (LocalEvalResult + LocalEvalPrompts) lives in the same file but \
            compiles cleanly in CLI builds too — #if canImport(Playgrounds) guards the Canvas \
            blocks. Zero regression on the main widget build. We just proved on-device eval \
            works end-to-end without an API key.
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== V3: big breakthrough ===")
    print("soundness: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition:  \(r.ambition)   risk:     \(r.risk)")
    print("reaction:  \(r.reaction)")
    print("summary:   \(r.summary)")
}

#endif // canImport(Playgrounds)

#endif // canImport(FoundationModels)
