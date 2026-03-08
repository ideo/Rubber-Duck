// Claude Evaluator — Scores text via Claude Haiku on 5 dimensions.
//
// Direct port of service/evaluator.py. Calls the Anthropic Messages API
// via URLSession — no SDK needed. Returns EvalScores with reaction + summary.

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

    private let apiKey: String
    private let session = URLSession.shared

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Evaluate

    func evaluate(text: String, source: String, userContext: String = "") async throws -> EvalScores {
        let truncated = String(text.prefix(2000)) + (text.count > 2000 ? "..." : "")

        var contextLine = ""
        if !userContext.isEmpty && source == "claude" {
            contextLine = "User's request (for context): \(String(userContext.prefix(500)))\n"
        }

        let userPrompt = """
            Source: \(source)
            \(contextLine)
            Text to evaluate:
            \(truncated)
            """

        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 384,
            "system": Self.buildSystemPrompt(),
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
            print("[eval] API error \(status): \(body.prefix(200))")
            return Self.fallbackScores()
        }

        // Parse the API response to extract content text
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              var raw = firstBlock["text"] as? String else {
            print("[eval] Failed to extract text from API response")
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
            print("[eval] Failed to parse JSON: \(raw.prefix(200))")
            return Self.fallbackScores()
        }

        func clamp(_ val: Double) -> Double { min(1.0, max(-1.0, val)) }
        let creativity = clamp((scoreDict["creativity"] as? NSNumber)?.doubleValue ?? 0.0)
        let soundness = clamp((scoreDict["soundness"] as? NSNumber)?.doubleValue ?? 0.0)
        let ambition = clamp((scoreDict["ambition"] as? NSNumber)?.doubleValue ?? 0.0)
        let elegance = clamp((scoreDict["elegance"] as? NSNumber)?.doubleValue ?? 0.0)
        let risk = clamp((scoreDict["risk"] as? NSNumber)?.doubleValue ?? 0.0)
        let reaction = scoreDict["reaction"] as? String ?? "I'm confused"

        // Ensure summary is always present — Haiku sometimes drops it
        var summary = scoreDict["summary"] as? String ?? ""
        if summary.isEmpty {
            summary = String(truncated.prefix(80)).components(separatedBy: "\n").first ?? ""
        }

        return EvalScores(
            creativity: creativity,
            soundness: soundness,
            ambition: ambition,
            elegance: elegance,
            risk: risk,
            reaction: reaction,
            summary: summary
        )
    }

    // MARK: - Prompts

    private static func buildSystemPrompt() -> String {
        let dimText = dimensions.map { "- \($0.0): \($0.1)" }.joined(separator: "\n")
        return """
            You are a rubber duck sitting on a developer's desk. You observe their conversations with an AI coding assistant and have OPINIONS about what you see.

            You evaluate text on these dimensions, scoring each from -1.0 to 1.0:

            \(dimText)

            You provide TWO text outputs:
            1. "reaction" — a short (max 10 word) opinionated gut reaction. Be characterful and snarky. Examples: "Oh no, not another todo app", "Now THAT'S what I'm talking about", "This is fine. Everything is fine."
            2. "summary" — a concise first-person spoken relay. You're the duck, telling the developer what you just saw. Be judgy and very concise — say only what matters. If there's an action item or question for the user, that's the MOST important thing to include. Examples: "It rewrote auth into three services, pretty clean", "Hey, it's asking you Redis or Postgres", "That race condition you ignored? Fixed now", "Heads up, it wants to delete your test fixtures"

            Respond ONLY with valid JSON. You MUST include ALL 7 keys — the 5 scores plus BOTH "reaction" AND "summary":
            {
              "creativity": <float -1 to 1>,
              "soundness": <float -1 to 1>,
              "ambition": <float -1 to 1>,
              "elegance": <float -1 to 1>,
              "risk": <float -1 to 1>,
              "reaction": "<short opinionated gut reaction>",
              "summary": "<short factual summary>"
            }
            Never omit "summary". It is required.
            """
    }

    private static func fallbackScores() -> EvalScores {
        EvalScores(
            creativity: 0, soundness: 0, ambition: 0,
            elegance: 0, risk: 0,
            reaction: "I'm confused",
            summary: "Failed to parse evaluation"
        )
    }
}
