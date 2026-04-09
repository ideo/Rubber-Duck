// Gemini Evaluator — Scores text via Google Gemini Flash on 5 dimensions.
//
// Calls the Gemini generateContent API via URLSession — no SDK needed.
// Returns EvalScores with reaction + summary. Optional engine — users
// can switch to this from the menu bar for higher-quality scoring.
// Uses the same system prompt and dimensions as ClaudeEvaluator.

import Foundation

actor GeminiEvaluator {

    private let session = URLSession.shared

    /// API key is read from DuckConfig at eval time so it picks up keys saved after app init.
    private var apiKey: String { DuckConfig.geminiAPIKey }

    init() {}

    // MARK: - Evaluate

    func evaluate(text: String, source: String, userContext: String = "", claudeContext: String = "", wildcardEnabled: Bool = false) async throws -> EvalScores {
        let userPrompt = EvalPromptBuilder.buildPrompt(
            text: text, source: source,
            userContext: userContext, claudeContext: claudeContext,
            maxTextLength: 4000  // Flash has a large context window
        )

        let systemPrompt = ClaudeEvaluator.systemPrompt(wildcardEnabled: wildcardEnabled)

        // Gemini API format: systemInstruction + contents
        let requestBody: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["parts": [["text": userPrompt]]]
            ],
            "generationConfig": [
                "maxOutputTokens": 1024,
                "temperature": 0.7,
                "responseMimeType": "application/json",
                "thinkingConfig": ["thinkingBudget": 0],
            ]
        ]

        let model = "gemini-2.5-flash"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            DuckLog.log("[gemini-eval] API error \(status): \(body.prefix(200))")
            return Self.errorScores(status: status)
        }

        // Parse the Gemini API response
        // Structure: { candidates: [{ content: { parts: [{ text: "..." }] } }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              var raw = firstPart["text"] as? String else {
            DuckLog.log("[gemini-eval] Failed to extract text from API response")
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
            DuckLog.log("[gemini-eval] Failed to parse JSON: \(raw.prefix(200))")
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

        // Ensure summary is always present
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

    private static func errorScores(status: Int) -> EvalScores {
        let reaction: String
        switch status {
        case 401, 403: reaction = "Gemini isn't working. Check your API key or switch intelligence in the menu."
        case 429: reaction = "Gemini is rate limited. Try again in a moment or switch intelligence."
        case 500...599: reaction = "Gemini's servers are down. Switch intelligence or try later."
        default: reaction = "Gemini isn't responding. Check your API key or switch intelligence."
        }
        return EvalScores(
            creativity: 0, soundness: 0, ambition: 0,
            elegance: 0, risk: 0,
            reaction: reaction,
            summary: "Evaluation failed (HTTP \(status))"
        )
    }

    private static func fallbackScores() -> EvalScores {
        EvalScores(
            creativity: 0, soundness: 0, ambition: 0,
            elegance: 0, risk: 0,
            reaction: "Gemini couldn't parse that one. Might be a fluke.",
            summary: "Failed to parse evaluation"
        )
    }
}
