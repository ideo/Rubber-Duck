// Eval Prompt Builder — Shared context-building logic for both eval engines.
//
// Both LocalEvaluator and ClaudeEvaluator need to truncate text, build context
// lines, and assemble user prompts. This extracts that shared logic.
// Each engine has different truncation limits due to different token budgets.

import Foundation

enum EvalPromptBuilder {

    /// Build the user-facing prompt string sent to either eval engine.
    ///
    /// - Parameters:
    ///   - text: Raw text to evaluate (user prompt or Claude response)
    ///   - source: "user" or "claude"
    ///   - userContext: The user's original request (for context when evaluating Claude's response)
    ///   - claudeContext: Claude's last response (for context when evaluating user's prompt)
    ///   - maxTextLength: Truncation limit — 3000 for Foundation Models (4K token window),
    ///     4000 for Anthropic API (larger context)
    static func buildPrompt(
        text: String,
        source: String,
        userContext: String,
        claudeContext: String,
        maxTextLength: Int
    ) -> String {
        let truncated = String(text.prefix(maxTextLength))
            + (text.count > maxTextLength ? "..." : "")

        var contextLine = ""
        if !userContext.isEmpty && source == "claude" {
            contextLine = "User's request (for context): \(String(userContext.prefix(500)))\n"
        } else if !claudeContext.isEmpty && source == "user" {
            contextLine = "Claude's last message (for context): \(String(claudeContext.prefix(1000)))\n"
        }

        return """
            Source: \(source)
            \(contextLine)\
            Text to evaluate:
            \(truncated)
            """
    }
}
