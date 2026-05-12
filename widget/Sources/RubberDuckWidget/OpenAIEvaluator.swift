// OpenAI Evaluator — Scores text via GPT-5.2 on 5 dimensions.
//
// Calls the OpenAI Responses API via URLSession — no SDK needed.
// Uses the same system prompt and dimensions as ClaudeEvaluator.

import Foundation

actor OpenAIEvaluator {

    private let session = URLSession.shared
    private var apiKey: String { DuckConfig.openAIAPIKey }

    init() {}

    // MARK: - Evaluate

    func evaluate(text: String, source: String, userContext: String = "", claudeContext: String = "", wildcardEnabled: Bool = false) async throws -> EvalScores {
        let userPrompt = EvalPromptBuilder.buildPrompt(
            text: text, source: source,
            userContext: userContext, claudeContext: claudeContext,
            maxTextLength: 4000
        )

        let requestBody: [String: Any] = [
            "model": "gpt-5.2-chat-latest",
            "instructions": ClaudeEvaluator.systemPrompt(wildcardEnabled: wildcardEnabled),
            "input": userPrompt,
            "max_output_tokens": 1024,
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            DuckLog.log("[openai-eval] API error \(status): \(body.prefix(200))")
            return Self.errorScores(status: status)
        }

        guard var raw = Self.extractOutputText(from: data) else {
            DuckLog.log("[openai-eval] Failed to extract output text from API response")
            return Self.fallbackScores()
        }

        raw = Self.stripCodeFences(raw.trimmingCharacters(in: .whitespacesAndNewlines))

        guard let scoreData = raw.data(using: .utf8),
              let scoreDict = try? JSONSerialization.jsonObject(with: scoreData) as? [String: Any] else {
            DuckLog.log("[openai-eval] Failed to parse JSON: \(raw.prefix(200))")
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

    private static func extractOutputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let text = json["output_text"] as? String, !text.isEmpty {
            return text
        }

        guard let output = json["output"] as? [[String: Any]] else {
            return nil
        }

        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for block in content {
                if let text = block["text"] as? String, !text.isEmpty {
                    return text
                }
            }
        }

        return nil
    }

    private static func stripCodeFences(_ raw: String) -> String {
        var text = raw
        if text.hasPrefix("```") {
            if let firstNewline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstNewline)...])
            }
            if let lastFence = text.range(of: "```", options: .backwards) {
                text = String(text[..<lastFence.lowerBound])
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func errorScores(status: Int) -> EvalScores {
        let reaction: String
        switch status {
        case 401, 403: reaction = "GPT-5.2 isn't working. Check your OpenAI API key."
        case 429: reaction = "GPT-5.2 is rate limited. Try again in a moment."
        case 500...599: reaction = "OpenAI's servers are down. Switch intelligence or try later."
        default: reaction = "GPT-5.2 isn't responding. Check your key or switch intelligence."
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
            reaction: "GPT-5.2 couldn't parse that one. Might be a fluke.",
            summary: "Failed to parse evaluation"
        )
    }
}
