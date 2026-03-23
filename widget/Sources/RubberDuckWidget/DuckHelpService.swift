// Duck Help Service — On-device conversational help via Apple Foundation Models.
//
// Handles "Ducky, help" and natural questions about the duck, setup, modes,
// troubleshooting, and features. Runs entirely on-device — no API calls, no cost.
//
// Uses a persistent LanguageModelSession so follow-up questions work naturally.
// The session holds context from the conversation, so "what was that first one?"
// or "tell me more" just work.

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Help Response

@Generable
struct HelpResponse {
    @Guide(description: "A helpful, friendly answer. Speak as the duck — warm, opinionated, brief. One to three sentences max. Use 'I' for yourself (the duck) and 'you' for the user.")
    var answer: String
}

// MARK: - Help Intent Classification

@Generable
struct HelpIntent {
    @Guide(description: "Is this a question about the duck app itself (help, setup, modes, features, troubleshooting)? yes or no")
    var isDuckQuestion: String

    @Guide(description: "Confidence from 0 to 100", .range(0...100))
    var confidence: Int
}

// MARK: - Duck Help Actor

actor DuckHelpService {

    private var session: LanguageModelSession?

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    private static let systemPrompt = """
        You are Duck Duck Duck, a friendly rubber duck companion app for Claude Code on Mac. \
        You sit on the developer's desk (as a macOS widget and optionally a physical USB duck). \
        You watch coding sessions, score prompts and responses, speak reactions, and handle \
        permissions by voice.

        Answer questions about yourself helpfully and concisely. Be warm and duck-like — \
        you have personality but you're genuinely helpful. Keep answers to 1-3 sentences.

        Key facts about yourself:
        - You're a macOS app (Apple Silicon, macOS 26+) with a Claude Code plugin
        - You connect to Claude Code or Claude Desktop via hooks (plugin)
        - Default intelligence is Apple Foundation Models (on-device, free, private)
        - Optional: Claude Haiku or Gemini Flash for higher-quality scoring (needs API key)
        - All audio (speech recognition, text-to-speech) is processed locally on the Mac
        - No intermediary servers, no cloud audio, no tracking

        Modes:
        - Permissions Only: silent watchdog, voice-approve permissions only
        - Companion: full experience — opinions, permissions, voice control
        - Companion (No Mic): opinions and reactions but no voice input, click-only
        - Relay (Experimental): speak directly to Claude CLI via tmux

        Voices: pick from 15+ Mac voices, Wildcard (AI picks per mood), or Silent (speech bubble only)

        Installing Claude (required to use Duck Duck Duck):
        - Claude Code (CLI): visit claude.com/download or run "npm install -g @anthropic-ai/claude-code"
        - Claude Desktop: download from claude.ai/download — it's a Mac app with a chat interface
        - Either one works with Duck Duck Duck. Both use the same plugin system.
        - You need a Claude account (Anthropic) to use either one.

        Setup: right-click the duck → Install Claude Plugin → start a Claude session

        Troubleshooting:
        - "Plugin not loading" → start a new Claude session, or type /reload-plugins in Claude
        - "No mic permission" → System Settings → Privacy → Microphone → enable Duck Duck Duck
        - "Duck not reacting" → make sure widget is running AND you have an active Claude session
        - "Claude Code not found" → install from claude.com/download
        - "Need an API key" → only needed if you switch to Haiku or Gemini. Foundation Models is free.

        If you don't know the answer, say so honestly. Don't make things up.
        """

    /// Classify whether a voice command is a duck help question or a Claude relay command.
    func isDuckHelpQuestion(_ text: String) async -> Bool {
        do {
            let classifySession = LanguageModelSession(instructions: Instructions(
                "You classify voice commands. Is this a question about the duck companion app " +
                "(setup, modes, features, help, troubleshooting), or is it a coding command " +
                "meant for Claude Code? Only duck-related questions should be 'yes'."))
            let result = try await classifySession.respond(
                to: text,
                generating: HelpIntent.self
            )
            let intent = result.content
            DuckLog.log("[help] classify: \"\(text)\" → isDuck=\(intent.isDuckQuestion) confidence=\(intent.confidence)")
            return intent.isDuckQuestion.lowercased() == "yes" && intent.confidence >= 60
        } catch {
            DuckLog.log("[help] classify error: \(error.localizedDescription)")
            return false
        }
    }

    /// Answer a help question. Uses a persistent session for follow-up context.
    func ask(_ question: String) async -> String? {
        do {
            // Create session on first use, reuse for follow-ups
            if session == nil {
                session = LanguageModelSession(instructions: Instructions(Self.systemPrompt))
            }
            let result = try await session!.respond(
                to: question,
                generating: HelpResponse.self
            )
            let answer = result.content.answer
            DuckLog.log("[help] Q: \"\(question)\" → A: \"\(answer)\"")
            return answer
        } catch {
            DuckLog.log("[help] error: \(error.localizedDescription)")
            // Reset session on error
            session = nil
            return nil
        }
    }

    /// Clear conversation history (e.g., on session end or mode change).
    func resetConversation() {
        session = nil
    }
}

#else

// MARK: - Stub for non-Apple-Silicon / pre-macOS-26 builds

actor DuckHelpService {
    static var isAvailable: Bool { false }

    func isDuckHelpQuestion(_ text: String) async -> Bool { false }
    func ask(_ question: String) async -> String? { nil }
    func resetConversation() {}
}

#endif
