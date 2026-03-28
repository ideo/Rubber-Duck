// Claude Evaluator — Scores text via Claude Haiku on 5 dimensions.
//
// Calls the Anthropic Messages API via URLSession — no SDK needed.
// Returns EvalScores with reaction + summary. Optional engine — users
// can switch to this from the menu bar for higher-quality scoring.

import Foundation

actor ClaudeEvaluator {

    // MARK: - Dimensions

    static let dimensions: [(String, String)] = [
        ("creativity", "How novel or creative is the approach? Boring/obvious vs inspired/surprising."),
        ("soundness", "Is this technically sound? Will it work, or is it flawed/naive?"),
        ("ambition", "How ambitious is the scope? Trivial tweak vs bold undertaking."),
        ("elegance", "Is the solution elegant and clean, or hacky and convoluted?"),
        ("risk", "How risky is this? Safe and predictable vs could-go-wrong territory."),
    ]

    private let session = URLSession.shared

    /// API key is read from DuckConfig at eval time so it picks up keys saved after app init.
    private var apiKey: String { DuckConfig.anthropicAPIKey }

    init() {}

    // MARK: - Evaluate

    func evaluate(text: String, source: String, userContext: String = "", claudeContext: String = "", wildcardEnabled: Bool = false) async throws -> EvalScores {
        let userPrompt = EvalPromptBuilder.buildPrompt(
            text: text, source: source,
            userContext: userContext, claudeContext: claudeContext,
            maxTextLength: 4000  // Haiku has a larger context window
        )

        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 384,
            "system": Self.systemPrompt(wildcardEnabled: wildcardEnabled),
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            DuckLog.log("[eval] API error \(status): \(body.prefix(200))")
            return Self.fallbackScores()
        }

        // Parse the API response to extract content text
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              var raw = firstBlock["text"] as? String else {
            DuckLog.log("[eval] Failed to extract text from API response")
            return Self.fallbackScores()
        }

        raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences if present
        if raw.hasPrefix("```") {
            if let firstNewline = raw.firstIndex(of: "\n") {
                raw = String(raw[raw.index(after: firstNewline)...])
            }
            if let lastFence = raw.range(of: "```", options: .backwards) {
                raw = String(raw[..<lastFence.lowerBound])
            }
            raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Parse JSON scores
        guard let scoreData = raw.data(using: .utf8),
              let scoreDict = try? JSONSerialization.jsonObject(with: scoreData) as? [String: Any] else {
            DuckLog.log("[eval] Failed to parse JSON: \(raw.prefix(200))")
            return Self.fallbackScores()
        }

        func clamp(_ val: Double) -> Double { min(1.0, max(-1.0, val)) }
        let creativity = clamp((scoreDict["creativity"] as? NSNumber)?.doubleValue ?? 0.0)
        let soundness = clamp((scoreDict["soundness"] as? NSNumber)?.doubleValue ?? 0.0)
        let ambition = clamp((scoreDict["ambition"] as? NSNumber)?.doubleValue ?? 0.0)
        let elegance = clamp((scoreDict["elegance"] as? NSNumber)?.doubleValue ?? 0.0)
        let risk = clamp((scoreDict["risk"] as? NSNumber)?.doubleValue ?? 0.0)
        let reaction = scoreDict["reaction"] as? String ?? "I'm confused"
        let voice = scoreDict["voice"] as? String

        // Ensure summary is always present — Haiku sometimes drops it
        var summary = scoreDict["summary"] as? String ?? ""
        if summary.isEmpty {
            summary = String(text.prefix(80)).components(separatedBy: "\n").first ?? ""
        }

        return EvalScores(
            creativity: creativity,
            soundness: soundness,
            ambition: ambition,
            elegance: elegance,
            risk: risk,
            reaction: reaction,
            summary: summary,
            voice: voice
        )
    }

    // MARK: - Prompts

    /// Cached prompts — only two possible values, built once.
    private static let promptWithoutWildcard = buildSystemPrompt(wildcardEnabled: false)
    private static let promptWithWildcard = buildSystemPrompt(wildcardEnabled: true)

    /// Returns the cached system prompt for the given wildcard state.
    static func systemPrompt(wildcardEnabled: Bool) -> String {
        wildcardEnabled ? promptWithWildcard : promptWithoutWildcard
    }

    private static func buildSystemPrompt(wildcardEnabled: Bool = false) -> String {
        let dimText = dimensions.map { "- \($0.0): \($0.1)" }.joined(separator: "\n")

        let voiceSection = wildcardEnabled ? """

            \(DuckVoices.wildcardPromptDescription)
            """ : ""

        let voiceKey = wildcardEnabled ? """
            ,
              "voice": "<voice key from the list above>"
            """ : ""

        let keyCount = wildcardEnabled ? "8" : "7"
        let extraKeys = wildcardEnabled ? ", \"reaction\", \"summary\", AND \"voice\"" : " plus BOTH \"reaction\" AND \"summary\""
        let neverOmit = wildcardEnabled
            ? "Never omit \"summary\" or \"voice\". Both are required."
            : "Never omit \"summary\". It is required."

        return """
            You are a rubber duck sitting on a developer's desk. You observe their conversations with an AI coding assistant and have OPINIONS about what you see.

            You evaluate text on these dimensions, scoring each from -1.0 to 1.0:

            \(dimText)

            You provide TWO text outputs. BOTH must be ONE sentence max. This is spoken aloud — brevity is everything.
            1. "reaction" — max 10 words. ONE sentence. You are Claude's INNER MONOLOGUE thinking out loud. Use "I" for Claude's own work and "they" for the user. When source is "claude", you're critiquing your own output: "Not my finest work", "I crushed that one", "I probably shouldn't have done that". When source is "user", you're reacting to what they asked: "They want me to WHAT?", "Oh they're testing me now", "Now THAT'S a fun problem". Never say "you" (that's the summary's job). NEVER more than one sentence.
            2. "summary" — ONE short sentence, max 15 words, spoken DIRECTLY TO THE DEVELOPER. Use "you" for the developer, "it" or "Claude" for the AI assistant. Be judgy. Say only what matters. If there's a permission request or question for the user, that's the MOST important thing. Examples: "It rewrote your auth, pretty clean", "Hey, it's asking you Redis or Postgres", "Heads up, it wants to delete your test fixtures". NEVER more than one sentence. NEVER a paragraph.
            \(voiceSection)
            Respond ONLY with valid JSON. You MUST include ALL \(keyCount) keys — the 5 scores\(extraKeys):
            {
              "creativity": <float -1 to 1>,
              "soundness": <float -1 to 1>,
              "ambition": <float -1 to 1>,
              "elegance": <float -1 to 1>,
              "risk": <float -1 to 1>,
              "reaction": "<short opinionated gut reaction>",
              "summary": "<short factual summary>"\(voiceKey)
            }
            \(neverOmit)
            """
    }

    private static func fallbackScores() -> EvalScores {
        EvalScores(
            creativity: 0, soundness: 0, ambition: 0,
            elegance: 0, risk: 0,
            reaction: ["Hmm.", "That's odd.", "Didn't catch that."].randomElement()!,
            summary: "Failed to parse evaluation"
        )
    }
}
