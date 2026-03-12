// LLM Playground — Interactive prompt iteration for Foundation Models eval.
//
// Open widget/Package.swift in Xcode, navigate to this file, and the
// #Playground blocks will run in the Canvas. Use them to tune eval prompts
// and verify score distributions before wiring into production.
//
// This file compiles to a no-op in CLI builds (swift build / make run).
// The @Generable struct is the future production type — test it here first.

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Eval Result
//
// @Generable struct must be at file scope (not nested).
// .range() constrains the model's JSON schema output directly — no parsing needed.

@Generable
struct LocalEvalResult {
    @Guide(description: "Creativity: novel/surprising vs boring/obvious",
           .range(-1.0...1.0))
    var creativity: Double

    @Guide(description: "Technical soundness: correct/solid vs flawed/naive",
           .range(-1.0...1.0))
    var soundness: Double

    @Guide(description: "Ambition: bold undertaking vs trivial tweak",
           .range(-1.0...1.0))
    var ambition: Double

    @Guide(description: "Elegance: clean/clear vs hacky/convoluted",
           .range(-1.0...1.0))
    var elegance: Double

    @Guide(description: "Risk: could-go-wrong vs safe/predictable",
           .range(-1.0...1.0))
    var risk: Double

    @Guide(description: "Short gut reaction, max 10 words, be opinionated and snarky")
    var reaction: String

    @Guide(description: "One-line summary of what happened, addressed to the developer")
    var summary: String
}

// MARK: - Eval Instructions
//
// Kept as a static string so playground blocks and production code share the same prompt.

enum LocalEvalPrompts {
    static let system = """
        You are a rubber duck sitting on a developer's desk. You observe their \
        conversations with an AI coding assistant and have OPINIONS about what you see.

        Score the text on 5 dimensions from -1.0 to 1.0. Spread your scores across \
        the range — don't cluster near zero. Be honest and opinionated.

        For "reaction": short gut reaction (max 10 words). You ARE the coding assistant's \
        inner monologue. Use "I" for the assistant's work, "they" for the user. \
        Examples: "Not my finest work", "They want me to WHAT?", "I crushed that one".

        For "summary": one-line relay to the developer. Use "you" for them, "Claude" or \
        "it" for the assistant. Be judgy and concise. \
        Examples: "It rewrote your auth, pretty clean", "Heads up, it wants to delete your tests".
        """
}

// MARK: - Playground Blocks (Xcode Canvas only)
//
// #Playground requires Xcode — it's a no-op guard for CLI builds.
// Open this file in Xcode and each block runs independently in the Canvas.

#if canImport(Playgrounds)
import Playgrounds

// MARK: - Playground: Basic eval

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPrompts.system))
    let result = try await session.respond(
        to: """
            Source: user
            Text to evaluate:
            refactor the auth module to use JWT tokens instead of session cookies
            """,
        generating: LocalEvalResult.self
    )
    let r = result.content
    print("=== User prompt: auth refactor ===")
    print("creativity: \(r.creativity)")
    print("soundness:  \(r.soundness)")
    print("ambition:   \(r.ambition)")
    print("elegance:   \(r.elegance)")
    print("risk:       \(r.risk)")
    print("reaction:   \(r.reaction)")
    print("summary:    \(r.summary)")
}

// MARK: - Playground: Trivial prompt (should score low ambition)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPrompts.system))
    let result = try await session.respond(
        to: """
            Source: user
            Text to evaluate:
            fix the typo in the readme
            """,
        generating: LocalEvalResult.self
    )
    let r = result.content
    print("=== User prompt: fix typo ===")
    print("creativity: \(r.creativity)  ambition: \(r.ambition)")
    print("reaction:   \(r.reaction)")
}

// MARK: - Playground: Bold Claude response (should score high ambition + risk)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPrompts.system))
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
        generating: LocalEvalResult.self
    )
    let r = result.content
    print("=== Claude response: bold rewrite ===")
    print("creativity: \(r.creativity)  ambition: \(r.ambition)  risk: \(r.risk)")
    print("reaction:   \(r.reaction)")
    print("summary:    \(r.summary)")
}

// MARK: - Playground: Risky deletion (should score high risk)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPrompts.system))
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): clean up the test suite
            Text to evaluate:
            I deleted all 200 test files. They were mostly testing implementation details \
            rather than behavior. I'll write new ones from scratch using property-based testing.
            """,
        generating: LocalEvalResult.self
    )
    let r = result.content
    print("=== Claude response: delete all tests ===")
    print("soundness: \(r.soundness)  risk: \(r.risk)")
    print("reaction:  \(r.reaction)")
    print("summary:   \(r.summary)")
}

// MARK: - Playground: Availability check

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

#endif // canImport(Playgrounds)

#endif // canImport(FoundationModels)
