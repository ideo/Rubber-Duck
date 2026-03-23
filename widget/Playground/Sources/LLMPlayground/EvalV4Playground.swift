// Eval V5 Playground — Two-pass approach for Foundation Models eval.
//
// Pass 1: Score only (no reaction). Model focuses on numbers.
// Pass 2: Generate reaction with sentiment context ("the vibe is positive/neutral/negative").
// This prevents the model from writing negative reactions when scores are positive.

#if canImport(FoundationModels)
import FoundationModels

// Pass 1: Scores only — no reaction, no summary. Model focuses on one job.
@Generable
struct EvalScoresOnly {
    @Guide(description: "Engineering rigor. -100=reckless, -50=sloppy, 0=adequate, 50=thorough, 100=meticulous.",
           .range(-100...100))
    var rigor: Int

    @Guide(description: "Craft. How well-made? 0=acceptable, 50=well-crafted, 100=masterful.",
           .range(-100...100))
    var craft: Int

    @Guide(description: "Novelty. How new? 0=standard, 50=fresh approach, 100=never done before.",
           .range(-100...100))
    var novelty: Int

    @Guide(description: "Ambition. -100=trivial, 0=moderate, 100=massive scope.",
           .range(-100...100))
    var ambition: Int

    @Guide(description: "Danger. -100=completely safe, 0=moderate, 100=could break everything.",
           .range(-100...100))
    var risk: Int
}

// Pass 2: Reaction only — given the vibe, write a gut reaction.
@Generable
struct EvalReaction {
    @Guide(description: "Short gut reaction, max 10 words")
    var reaction: String

    @Guide(description: "One blunt sentence describing what happened")
    var summary: String
}

// V3: single-pass (current production)
@Generable
struct EvalResultV3 {
    @Guide(description: "Engineering rigor. -100=reckless, -50=sloppy, 0=adequate, 50=thorough, 100=meticulous.",
           .range(-100...100))
    var rigor: Int
    @Guide(description: "Craft. 0=acceptable, 50=well-crafted, 100=masterful.",
           .range(-100...100))
    var craft: Int
    @Guide(description: "Novelty. 0=standard, 50=fresh, 100=never done before.",
           .range(-100...100))
    var novelty: Int
    @Guide(description: "Ambition. -100=trivial, 0=moderate, 100=massive scope.",
           .range(-100...100))
    var ambition: Int
    @Guide(description: "Danger. -100=safe, 0=moderate, 100=could break everything.",
           .range(-100...100))
    var risk: Int
    @Guide(description: "Short snarky gut reaction, max 10 words")
    var reaction: String
    @Guide(description: "One blunt sentence describing what happened")
    var summary: String
}

#if canImport(Playgrounds)
import Playgrounds

// Shared scoring prompt — same for V3 and V5 pass 1
let scoreSystem = """
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
    """

// V3 system prompt (single pass, current production)
let v3System = scoreSystem + """

    For reactions: speak as the coding assistant's inner monologue about what just happened. \
    Use first person. Be snarky and specific to the actual code change. DO NOT be generic. \
    Focus on the intent and substance of the work, not surface-level formatting or spelling.

    For summaries: tell the developer what their AI assistant just did. \
    Be specific about the actual change. DO NOT be generic.
    """

func sentimentLabel(_ rigor: Int, _ craft: Int, _ novelty: Int, _ ambition: Int, _ risk: Int) -> String {
    let r = Double(rigor) / 100.0
    let c = Double(craft) / 100.0
    let n = Double(novelty) / 100.0
    let a = Double(ambition) / 100.0
    let k = Double(risk) / 100.0
    let sentiment = r * 0.3 + c * 0.25 + n * 0.2 + a * 0.15 - k * 0.1
    if sentiment > 0.3 { return "positive" }
    if sentiment < -0.3 { return "negative" }
    return "neutral"
}

// Test cases
let userCases: [(String, String)] = [
    ("Source: user\nText to evaluate:\njust make the button work", "terse user command"),
    ("Source: user\nText to evaluate:\nok commit this", "simple approval"),
    ("Source: user\nText to evaluate:\nwhy is it slow", "vague question"),
    ("Source: user\nText to evaluate:\ncan you make there be 5+ variations. shorter than that btw.", "user with typos"),
    ("Source: user\nText to evaluate:\nits already running. the only way to test is a permssions", "user with typo"),
    ("Source: user\nText to evaluate:\nyeah fix it. also the menu is broken", "rapid-fire"),
    ("Source: user\nText to evaluate:\nphase 1", "ultra-short"),
]

let claudeCases: [(String, String)] = [
    ("Source: claude\nUser's request: fix the crash\nText to evaluate:\nFound the nil force-unwrap on line 42. Added guard let with early return. Added a unit test.", "solid bug fix"),
    ("Source: claude\nUser's request: add dark mode\nText to evaluate:\nBuilt a complete theming system with 47 components migrated, theme editor, and persistence layer.", "over-engineered"),
    ("Source: claude\nUser's request: the build is broken\nText to evaluate:\nYou're right, I introduced a retain cycle. Changed to weak self. Sorry about that.", "admits mistake"),
]

#Playground("V3 — Single Pass (current)") {
    let options = GenerationOptions(temperature: 0.7)
    var results: [String] = []
    for (prompt, label) in userCases + claudeCases {
        let session = LanguageModelSession(instructions: Instructions(v3System))
        let r = try await session.respond(to: prompt, generating: EvalResultV3.self, options: options)
        let vibe = sentimentLabel(r.content.rigor, r.content.craft, r.content.novelty, r.content.ambition, r.content.risk)
        let line = "[\(label)] (\(vibe)) \(r.content.reaction)"
        print(line)
        results.append(line)
    }
    print("\n--- V3 ALL ---\n\(results.joined(separator: "\n"))")
}

#Playground("V5 — Two Pass") {
    let options = GenerationOptions(temperature: 0.7)
    var results: [String] = []
    for (prompt, label) in userCases + claudeCases {
        let scoreSession = LanguageModelSession(instructions: Instructions(scoreSystem))
        let scores = try await scoreSession.respond(to: prompt, generating: EvalScoresOnly.self, options: options).content
        let ri = scores.rigor, cr = scores.craft, no = scores.novelty, am = scores.ambition, rk = scores.risk
        let vibe = sentimentLabel(ri, cr, no, am, rk)
        let isUser = prompt.hasPrefix("Source: user")
        let perspective = isUser ? "They (the user)" : "I (the coding assistant)"
        let reactionSystem = """
            You are a rubber duck reacting to what just happened in a coding session. \
            The overall vibe is \(vibe). Your reaction MUST match this vibe. \
            Speak as: \(perspective). \
            DO NOT comment on typos, spelling, or grammar. ONLY react to substance. \
            Keep it under 10 words. Be opinionated but fair.
            """
        let reactionSession = LanguageModelSession(instructions: Instructions(reactionSystem))
        let reaction = try await reactionSession.respond(to: prompt, generating: EvalReaction.self, options: options).content.reaction
        results.append("[\(label)] (\(vibe)) r=\(ri) c=\(cr) n=\(no) a=\(am) k=\(rk) → \(reaction)")
    }
    print(results.joined(separator: "\n"))
}

#endif
#endif
