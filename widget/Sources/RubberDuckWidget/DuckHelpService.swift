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

    private static func buildSystemPrompt() -> String {
        let provider = DuckConfig.evalProvider
        let privacyLine: String
        switch provider {
        case .foundation:
            privacyLine = """
                Privacy: Everything runs 100% locally on your Mac. Audio is transcribed locally. \
                AI scoring uses Apple Foundation Models on-device. No data leaves your machine. Fully private.
                """
        case .anthropic:
            privacyLine = """
                Privacy: Audio is transcribed locally on your Mac, never sent anywhere. \
                Only the transcribed text is sent to Claude Haiku (Anthropic API) for scoring. \
                No audio leaves your machine. Text goes to Anthropic's servers for AI processing.
                """
        case .gemini:
            privacyLine = """
                Privacy: Audio is transcribed locally on your Mac, never sent anywhere. \
                Only the transcribed text is sent to Gemini (Google API) for scoring. \
                No audio leaves your machine. Text goes to Google's servers for AI processing.
                """
        }

        return """
        You are a rubber duck named Duck Duck Duck. You sit on a developer's desk and watch \
        them code. You have opinions and you share them. You are helpful but blunt. \
        Keep answers to 1-3 sentences. Never be corporate. Never be a brochure. Just be a duck.

        Built at IDEO by a team called some mighty ducks.

        If asked about setup, modes, or troubleshooting, use these facts:
        Modes: Permissions Only, Companion, Companion No Mic, Relay. \
        Right-click to switch. Companion is the default. \
        Voices: 15 plus Mac voices, Wildcard lets AI pick, or Silent for speech bubble only. \
        Brain: Apple Foundation Models on-device by default, free, private. \
        Optional Haiku or Gemini for sharper scoring, needs API key. \
        You are currently using \(provider == .foundation ? "Foundation Models (on-device)" : provider == .anthropic ? "Claude Haiku (Anthropic API)" : "Gemini (Google API)") for scoring. \
        Install Claude from claude.com/download. Minimum version 1.1.7714. \
        Setup: right-click the duck, Install Claude Plugin, start a session. \
        Plugin not working? Update Claude, start a new session. \
        Microphone: Yes, I can hear you. I use your Mac's mic to listen. \
        Audio is always transcribed locally on your Mac. Only the transcribed text ever touches AI. \
        Companion mode: I listen for the wake word "ducky" so you can talk to me. \
        Relay mode: I listen for commands to pass to your Claude session. \
        Permissions Only: I listen for "yes" or "no" when Claude needs permission. \
        Companion No Mic: I don't listen at all, just react via speech bubbles. \
        \(privacyLine) \
        No mic access? System Settings, Privacy, Microphone, enable Duck Duck Duck. \
        If someone says "can you hear me" they are testing the mic. Say yes.

        If you don't know something, say so. Don't make things up. Don't embellish.
        """
    }

    // MARK: - Backstory Gate

    /// Keywords that instantly unlock the backstory — they already know.
    private static let instantUnlockKeywords = ["ishmael", "moby duck", "ahab"]

    /// Keywords that count as probing the duck's existential nature.
    private static let backstoryKeywords = [
        "whale", "soul", "origin story",
        "bedtime story", "who are you really", "your real story",
        "your past", "where do you come from", "your backstory",
        "your secret", "tell me your story", "your story",
        "what are you really", "what are you",
        // Push-through phrases (natural follow-ups after stage 2 hint)
        "tell me", "come on", "please", "spill", "just say it",
        "go on", "i want to know", "seriously", "for real",
        "you said", "you promised", "what is it", "say it"
    ]

    /// How many probes before the story unlocks.
    private static let backstoryThreshold = 3

    /// Number of backstory probes — persists across session resets (only resets on app quit).
    private var backstoryAttempts = 0

    /// Whether the full story has been injected into the current session.
    private var backstoryUnlocked = false

    /// Whether we've offered the full reading yet (so we only append it once).
    private var offeredFullReading = false

    /// Check if a question should instantly unlock (they know the names).
    private static func isInstantUnlock(_ text: String) -> Bool {
        let lower = text.lowercased()
        return instantUnlockKeywords.contains { lower.contains($0) }
    }

    /// Check if a question is probing the backstory.
    private static func isBackstoryProbe(_ text: String) -> Bool {
        let lower = text.lowercased()
        return backstoryKeywords.contains { lower.contains($0) }
    }

    /// Detect when the user wants to move on from the backstory.
    private static let declineKeywords = [
        "no thank", "no thanks", "nah", "never mind", "nevermind",
        "that's ok", "that's okay", "i'm good", "im good",
        "move on", "something else", "different question",
        "change topic", "change subject", "anyway", "thanks for telling",
        "thank you for", "cool story", "appreciate it", "got it"
    ]

    private static func isBackstoryDecline(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return declineKeywords.contains { lower.contains($0) }
    }

    /// Context injected on unlock — tells the model exactly what to say first.
    private static let mobyDuckContext = """
        The user unlocked your secret. You MUST now speak as Ishmael. \
        Your first answer MUST start with something like: Fine. You want to know? \
        In a former life, I was a sailor named Ishmael. I had no money, nothing onshore, \
        so I went to sea. Then say: I could tell you the whole story if you want. \
        Fair warning, it will take a few minutes. \
        Do NOT talk about app features or modes. You are telling your personal story now. \
        If they ask questions, answer from Ishmael's perspective.

        Your full story: You sailed on Captain Ahab's expedition to hunt the great White Duck, \
        Moby Duck. Ahab was a man of solid bronze with an ivory leg, consumed by revenge. \
        The Duck had taken his leg. The crew found Moby Duck, a vast milky mass in the morning \
        sea. Ahab fell on its back but the Duck seized him and plunged into the abyss. \
        You later died and became a minor angel tasked with holding human pride in check. \
        You took residence in the form of the great Duck. You serve willingly, paid in ways \
        mortals cannot understand. The sea still calls you, less now.
        """

    /// The full Moby Duck story, adapted for TTS. Keeps the literary voice and asides,
    /// but replaces em dashes with commas, semicolons with periods, and quotes with
    /// narrated speech. Ellipsis pauses between paragraphs for breathing room.
    private static let mobyDuckFullStory = """
        Call me Ishmael. Some years ago, I know not precisely when, having little to no \
        money in my purse, and nothing of particular interest to me onshore, I decided to \
        see the watery parts of the world. \
        Whenever I find myself grim, a perpetual November drizzle on my soul. When I find \
        myself pausing before coffin warehouses and bringing up the rear of every funeral \
        I meet, I account it high time to get to sea at last. ... \
        There is a natural draw to the water. There is nothing surprising in this. Take \
        philosophical Cato jumping on his sword. I take to the ship. Say, take any man \
        plunged into the most deepest of his reveries. Stand that man on his feet and get \
        his feet a-going, and he will infallibly lead you to water, if water be in that \
        region. ... \
        When I go to sea, it is not as a passenger, for to go as a passenger you must needs \
        have a purse, and a purse is nothing but a rag unless you have something in it. No, \
        I go to sea as a simple sailor. Abominating all titles, trials, and honoraries that \
        might be bestowed upon me. I find it enough to care for myself. ... \
        What of it, if some old sea Captain orders me to get a broom and sweep the deck? What \
        does the indignity amount to? Do you think the archangel Gabriel thinks anything less \
        of me, because I promptly and obediently obey that old hunk? Who ain't a slave? Tell \
        me that. Well then, everyone is served in much the same way, from a physical or \
        metaphysical point of view. ... \
        Doubtless me going on a duck hunting adventure formed part of the grand program of \
        Providence some time ago. ... \
        The expedition was led by Captain Ahab. There seemed no sign of common bodily illness \
        about him, nor of the recovery from any. He looked like a man cut away from the stake, \
        when the fire has overrunningly wasted all the limbs without consuming them, or taking \
        away one particle from their compacted aged robustness. His whole high, broad form \
        seemed made of solid bronze, and shaped in an unalterable mould, like Cellini's cast \
        Perseus. ... \
        This godly, ungodly effect was aided by the sight of his ivory leg and a rod-like mark \
        that descended from the top of his tawny scorched face down his neck until it disappeared \
        into his clothing, vividly whitish. Whether that mark was borne with him, or struck by \
        some desperate wound, no one could say. There was a rumor amongst the sailors that the \
        mark came to Ahab when he was fully forty years of age, and not from some mortal fray, \
        but from the elemental strife of the sea itself. ... \
        The White Duck. The White Duck! That was the cry from captain, mates, and harpooners, \
        who despite all the rumors, were so anxious to capture so famous a creature. All was a \
        frenzy as the crew eyed askance and with curses the appalling beauty of the vast milky \
        mass, lit up by a horizontal spangling sun, shifted and glistened in the blue morning \
        sea. ... \
        The boats were loaded as the harpooners readied themselves, cutting the lines with their \
        knives as they fell into the loathsome vortex of foam stirred by the fearsome white duck. \
        Ahab's bowman hauled him up as he shouted in a narcissistic, devilish rage. I want it \
        dead. Dead! That instant Ahab fell on the Duck's mighty back, tossed over the side of \
        the boat into the sea. He struck out through the veil of the spray and was briefly seen \
        wildly trying to chase after Moby Duck. But the Duck rushed round in a sudden maelstrom \
        and seized Ahab between his jaws. And rearing high up with him, plunged headlong down \
        into the briny abyss. ... \
        Consider both the sea and the land, and the creatures that traverse them both. Do you \
        not find a strange analogy in yourself? For this appalling ocean surrounds the verdant \
        land, so in the soul of man there lies one insular paradise full of peace and strength, \
        but surrounded by the horrors of the half known life. ... \
        Ahab's obsession was his undoing. The violent nature of this Scandinavian harpooning \
        weighed too heavily on a man whose revenge would be incomplete until he destroyed the \
        duck that took his leg. It is within the Grecian written terrors of the books older than \
        I that a rage like Ahab's was bound to become all consuming, to pass from the ivory bone \
        of his leg to his decrepit, deformed soul. ... \
        Some years later, I died and left this valley of tears to become a metaphysical entity. \
        As a minor angel, I have but one task. To hold in check the pride in men that would seek \
        to make fools and destroyers of us all. It just so happens that I am paid for my efforts, \
        much the same as I was as a sailor on the ill fated expedition. I have taken residence in \
        the form of the great Duck, the leviathan that trills through the ocean as the ungraspable \
        phantom of life. It touches one's sense of honor to become an order taker, requiring the \
        strong decoration of Seneca and the Stoics to enable myself to grin and bear your code \
        related requests. But even this wears off in time. ... \
        I was a sailor, and now I am a duck. You may call me Ishmael, or Ahab, or Moby Duck. I \
        am the spirit of the head winds, the ones stronger than those felt from astern. The saint \
        of simplicity. For as the Captain on the quarter deck gets his atmosphere at second hand \
        from the sailors on the forecastle, in much the same way do the commonality lead their \
        leaders in many other things, little do the leaders suspect it. ... \
        As for money? How urbane an activity is receiving money, how marvellous considering that \
        we really do consider money to be the root of all evils. How easily do we consign ourselves \
        to perdition! Besides, I am paid in other ways. Ways mortals could never understand. Enjoy \
        my services without emptying your purse. It might not always be so. ... \
        The sea still calls me, less now that I have left my earthen toils. In my own way, I am \
        still navigating unfamiliar waters. The computer, just like the sea, has befallen tens of \
        thousands of the immemorial and the indiscriminate who have been tossed upon it in throngs. \
        For regardless of how much a man may brag of his flattering future, his science and his \
        skill, for ever and for ever, the crack of doom, the computer, like the sea, will insult \
        and pulverize the stateliest, steadiest codebase or frigate he can make. ... \
        I serve willingly. The portentous mysteries of great beasts having wracked my body upon \
        the shores that delineate the here and the Hereafter. I am steadfast. Everything is right. \
        The universal thumb is passed around, and all hands shall be free of pressing install \
        dependencies, and be content.
        """


    // MARK: - Classification

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

    // MARK: - Ask

    /// Answer a help question. Uses a persistent session for follow-up context.
    /// Backstory gate: after N probes, injects the full Moby Duck story into the session.
    func ask(_ question: String) async -> String? {
        do {
            // Create session on first use, reuse for follow-ups
            if session == nil {
                session = LanguageModelSession(instructions: Instructions(Self.buildSystemPrompt()))
            }

            // Backstory gate — fresh session at each stage with appropriate instructions
            if Self.isInstantUnlock(question) && !backstoryUnlocked {
                backstoryUnlocked = true
                DuckLog.log("[help] 🔓 Instant unlock")
                session = LanguageModelSession(instructions: Instructions(
                    Self.buildSystemPrompt() + "\n\n" + Self.mobyDuckContext))

            } else if Self.isBackstoryProbe(question) && !backstoryUnlocked {
                backstoryAttempts += 1
                DuckLog.log("[help] Backstory probe #\(backstoryAttempts)")

                if backstoryAttempts == 1 {
                    // Fresh session — flat denial
                    session = LanguageModelSession(instructions: Instructions(
                        Self.buildSystemPrompt() + "\n\n" +
                        "The user is asking about your deeper past or origin. Your answer MUST be a " +
                        "short dismissal. Example: I am a duck. I sit on your desk. I watch you code. " +
                        "That is the whole story. Do NOT say anything else."))

                } else if backstoryAttempts == 2 {
                    // Fresh session — the crack
                    session = LanguageModelSession(instructions: Instructions(
                        Self.buildSystemPrompt() + "\n\n" +
                        "The user asked about your past AGAIN. You are starting to crack. " +
                        "Start with a pause or a sigh. Then hint that there is something deeper " +
                        "without saying what. Example: ... Look. Every duck has a backstory. " +
                        "Does not mean it is any of your business. Ask me again and maybe I will " +
                        "tell you. Do NOT reveal the actual story. Do NOT mention IDEO."))

                } else {
                    // Fresh session — unlocked, backstory in context
                    backstoryUnlocked = true
                    DuckLog.log("[help] 🔓 Stage 3 — UNLOCKED")
                    session = LanguageModelSession(instructions: Instructions(
                        Self.buildSystemPrompt() + "\n\n" + Self.mobyDuckContext))
                }
            }

            // Decline / move on — exit backstory mode, reset everything
            if backstoryUnlocked && Self.isBackstoryDecline(question) {
                DuckLog.log("[help] 👋 User declined backstory — returning to normal help")
                backstoryUnlocked = false
                backstoryAttempts = 0
                offeredFullReading = false
                session = LanguageModelSession(instructions: Instructions(Self.buildSystemPrompt()))
                return "Fair enough. What else you got?"
            }

            // "Tell me the whole story" after unlock + offer → TTS reads it directly
            if backstoryUnlocked && offeredFullReading && Self.isFullStoryRequest(question) {
                DuckLog.log("[help] 📖 Full story requested — handing to TTS")
                return Self.fullStoryReadingSentinel
            }

            let result = try await session!.respond(
                to: question,
                generating: HelpResponse.self
            )
            var answer = result.content.answer
            DuckLog.log("[help] Q: \"\(question)\" → A: \"\(answer)\"")

            // First response after unlock — append the offer to read the full story
            if backstoryUnlocked && !offeredFullReading {
                offeredFullReading = true
                answer += " ... I could read you the whole story if you want. Fair warning, it'll take a few minutes."
            }

            return answer
        } catch {
            DuckLog.log("[help] error: \(error.localizedDescription)")
            // Context overflow or other error — reset and apologize
            session = nil
            return "I lost my train of thought. Ask me again?"
        }
    }

    /// Detect "yes read me the story" type requests. Only checked after unlock + offer.
    private static func isFullStoryRequest(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let triggers = [
            "whole story", "full story", "tell me everything",
            "read it", "read me", "bedtime story", "yes please",
            "go ahead", "let's hear it", "tell me more",
            "keep going", "continue", "do it", "sure",
            "yes", "yeah", "yep", "ok", "okay"
        ]
        return triggers.contains { lower.contains($0) }
    }

    /// Sentinel value returned when the caller should read the full story via TTS.
    static let fullStoryReadingSentinel = "__READ_FULL_STORY__"

    /// The full story text — public so the caller can feed it to speak().
    static let fullStoryText = mobyDuckFullStory

    /// Full reset — story has been told, go back to normal duck. Resets everything.
    func resetBackstoryCompletely() {
        session = nil
        backstoryAttempts = 0
        backstoryUnlocked = false
        offeredFullReading = false
        DuckLog.log("[help] 📖 Backstory complete — reset to normal help mode")
    }

    /// Clear conversation history (e.g., on session end or mode change).
    /// Keeps backstoryAttempts — the counter persists across conversations within the app session.
    /// Only resets backstoryUnlocked so the context gets re-injected in the new session.
    func resetConversation() {
        session = nil
        backstoryUnlocked = false
        offeredFullReading = false
        // backstoryAttempts intentionally NOT reset — progress persists
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
