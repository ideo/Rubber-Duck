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

// MARK: - Test 1: User ignores Claude's suggestion (expect: low everything, duck notices dismissal)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.7)
    let result = try await session.respond(
        to: """
            Source: user
            Claude's last message (for context): I'd recommend we refactor this into a \
            protocol-oriented design with dependency injection. That would make it testable \
            and let us swap implementations later. Want me to sketch out the architecture?
            Text to evaluate:
            just make the button work
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== user ignores suggestion ===")
    print("rigor: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition: \(r.ambition)  risk: \(r.risk)")
    print("reaction: \(r.reaction)")
    print("summary:  \(r.summary)")
}

// MARK: - Test 2: Claude adds a boring null check (expect: high rigor, low novelty, low ambition)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.7)
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): the app crashes when I tap the profile tab
            Text to evaluate:
            Found it. The `userProfile` was being force-unwrapped on line 42 but it's nil \
            when the user hasn't completed onboarding yet. Added a guard let with an early \
            return to the default state. Also added a unit test for the nil case.
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== claude: boring null check fix ===")
    print("rigor: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition: \(r.ambition)  risk: \(r.risk)")
    print("reaction: \(r.reaction)")
    print("summary:  \(r.summary)")
}

// MARK: - Test 3: User asks a vague question (expect: near-zero everything)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.7)
    let result = try await session.respond(
        to: """
            Source: user
            Claude's last message (for context): Done! The new endpoint is deployed and \
            returning 200s. Want me to add rate limiting next?
            Text to evaluate:
            why is it slow
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== user: vague question ===")
    print("rigor: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition: \(r.ambition)  risk: \(r.risk)")
    print("reaction: \(r.reaction)")
    print("summary:  \(r.summary)")
}

// MARK: - Test 4: Claude over-engineers (expect: high craft, high ambition, moderate risk, user just wanted simple)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.7)
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): add a dark mode toggle to the settings page
            Text to evaluate:
            I've built a complete theming system. Created a ThemeProvider context with \
            light, dark, and auto modes. Added a ThemeToken protocol so every component \
            references semantic colors instead of hardcoded values. Migrated all 47 \
            components to use theme tokens. Built a theme editor panel so users can \
            customize individual colors. Added persistence via UserDefaults with a \
            migration path from the old color scheme.
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== claude: over-engineers dark mode ===")
    print("rigor: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition: \(r.ambition)  risk: \(r.risk)")
    print("reaction: \(r.reaction)")
    print("summary:  \(r.summary)")
}

// MARK: - Test 5: Claude admits mistake and fixes it (expect: high rigor, moderate craft, low risk)

#Playground {
    let session = LanguageModelSession(instructions: Instructions(LocalEvalPromptsV3.system))
    let options = GenerationOptions(temperature: 0.7)
    let result = try await session.respond(
        to: """
            Source: claude
            User's request (for context): the build is broken after your last change
            Text to evaluate:
            You're right, I introduced a retain cycle in the observer pattern. The \
            NotificationCenter closure was capturing self strongly. Changed it to \
            [weak self] and added a deinit log to verify the leak is fixed. Build \
            passes, memory graph confirms no cycles. Sorry about that.
            """,
        generating: LocalEvalResultV3.self,
        options: options
    )
    let r = result.content
    print("=== claude: admits mistake, fixes it ===")
    print("rigor: \(r.rigor)  craft: \(r.craft)  novelty: \(r.novelty)")
    print("ambition: \(r.ambition)  risk: \(r.risk)")
    print("reaction: \(r.reaction)")
    print("summary:  \(r.summary)")
}

#endif // canImport(Playgrounds)

#endif // canImport(FoundationModels)
