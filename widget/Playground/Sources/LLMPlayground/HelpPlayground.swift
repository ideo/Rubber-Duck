// Help Playground — Testing Foundation Models for on-device user support.
//
// Three tiers of increasing difficulty:
//   Tier 1: Grounded single-turn Q&A (can the model answer from a help doc?)
//   Tier 2: Classification + retrieval (can the model pick the right help entry?)
//   Tier 3: Multi-turn conversation (can the model hold a short support dialog?)
//
// Open widget/Playground/Package.swift in Xcode. Navigate here. Canvas runs each block.
//
// KEY CONSTRAINTS (from Foundation Models research):
//   - 4096 token context window (input + output combined)
//   - No few-shot examples (3B model parrots them verbatim)
//   - No vivid negatives (elephant principle)
//   - ALL-CAPS directives work well
//   - Temperature 0.7 for personality, but help mode may want lower for accuracy
//   - @Generable structs for structured output, plain String for conversational

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Help Grounding Content
//
// Compact version of docs/DUCK-HELP-GROUNDING.md. Each entry is self-contained.
// Full doc is ~1200 tokens. We inline it all for Tier 1, chunk for Tier 2+.

enum HelpContent {

    // Entries written tight, in the duck's voice — snarky, blunt, spoken aloud by TTS.
    // The 3B model will parrot this tone. No jargon, no formatting, no fluff.
    static let allEntries = """
        TOPIC: What is Duck Duck Duck?
        I'm Duck Duck Duck. I sit on your screen and watch you talk to Claude. \
        I judge everything — your prompts, Claude's responses, all of it. \
        Then I tell you what I think, out loud, whether you asked or not.

        TOPIC: What I can and can't do
        I don't write code. That's Claude's job. \
        What I do is watch everything and give you my honest opinion — scores, reactions, the works. \
        In critic mode, I'll flag blockers and might accidentally share my real feelings about what's happening. \
        In relay mode, I can help you talk to Claude using your voice, but that's more of an experimental thing.

        TOPIC: How to Install
        Download the app, launch it, then click Install Claude Plugin from my menu bar icon. \
        Open Claude Code and I'll be watching. No API key, no setup, just go.

        TOPIC: Menu Bar Controls
        See the little duck in your menu bar? That's me. Click it. \
        You can pick my scoring brain, change voice mode, install the plugin, \
        launch Claude Code, hide me if you must, or quit.

        TOPIC: Voice Commands
        Say "ducky" and then tell me what you want. I'll pass it along to Claude. \
        If you say "ducky" and then just stare at me, I'll say "Hmm?" and move on. \
        Wake word mode needs to be on in the menu bar.

        TOPIC: Permission Handling
        When Claude wants to do something sketchy, I'll speak up and ask you. \
        Just say "yes" or "no" out loud — I'm listening through your mic. \
        If there are numbered options, say "first" or "second". \
        For this to work, voice mode needs to be set to permissions only or wake word in the menu bar.

        TOPIC: Evaluation Scores
        I judge each message on creativity, soundness, ambition, elegance, and risk. \
        You'll hear my take out loud after every prompt and every response. \
        My face changes too — eyes wide for creative stuff, squinty when something seems off.

        TOPIC: The Duck Widget
        I'm the little liquid glass face floating on your desktop. My eyes change with the scores — \
        wide when something's creative, squinty when it's suspect. \
        When Claude needs permission, my eyes go full exclamation mark. Right-click me for controls.

        TOPIC: Hardware
        You don't need a physical duck. I work fine as software. \
        But if you plug one in over USB, it'll tilt and chirp along with my reactions. Your call.

        TOPIC: Troubleshooting — Scores not showing
        If you're talking to me right now, I'm running — so that's not it. \
        Check that the plugin is connected. Click my menu bar icon and look for Plugin Connected. \
        If it's not there, click Install Claude Plugin and start a new Claude Code session.

        TOPIC: Troubleshooting — No Sound
        If you can hear me say this, sound is working. \
        If my voice is silent but I'm still here, check voice mode in the menu bar — \
        it might be set to off. Also check your Mac volume isn't muted.

        TOPIC: Troubleshooting — Hardware not responding
        The physical duck is optional, so don't panic. \
        Check the USB cable is plugged in. I should detect it automatically. \
        If you just plugged it in, give me a second — I'll switch over.

        TOPIC: Troubleshooting — Plugin Not Working
        Run claude plugin list to see if I'm there. If not, click Install Claude Plugin \
        from my menu bar. Then start a fresh Claude Code session — plugins only load at launch.

        TOPIC: Requirements
        You need a Mac with an M1 chip or newer running macOS Tahoe, and Claude Code 1.0.33 or newer. \
        No API key needed — I score everything on-device for free by default.

        TOPIC: Modes
        Critic mode is the default — I watch and judge, that's it. \
        Relay mode lets you talk to Claude through me, but you need tmux for that. \
        App Store gets critic only. The GitHub version gets everything.
        """

    // Individual entries for chunked retrieval (Tier 2) — same tight duck voice
    static let entries: [String: String] = [
        "what_is": "I'm Duck Duck Duck. I sit on your screen and watch you talk to Claude. I judge everything — your prompts, Claude's responses, all of it. Then I tell you what I think, out loud, whether you asked or not.",
        "capabilities": "I don't write code — that's Claude's job. I watch everything and give you my honest opinion. In critic mode I flag blockers and share my real feelings about what's happening. In relay mode I can help you talk to Claude with your voice, but that's experimental.",
        "install": "Download the app, launch it, then click Install Claude Plugin from my menu bar icon. Open Claude Code and I'll be watching. No API key, no setup, just go.",
        "menu_bar": "See the little duck in your menu bar? That's me. Click it. You can pick my scoring brain, change voice mode, install the plugin, launch Claude Code, hide me, or quit.",
        "voice": "Say ducky and then tell me what you want. I'll pass it along to Claude. If you say ducky and just stare at me, I'll say Hmm? and move on. Wake word mode needs to be on.",
        "permissions": "When Claude wants to do something sketchy, I'll speak up and ask you. Say yes or no out loud — I'm listening through your mic. Say first or second for numbered options. Voice mode needs to be permissions only or wake word for this to work.",
        "scores": "I judge each message on creativity, soundness, ambition, elegance, and risk. You'll hear my take out loud. My face changes too — eyes wide for creative, squinty when something's off.",
        "widget": "I'm the little liquid glass face floating on your desktop. My eyes change with the scores — wide for creative, squinty for suspect. Permission time? Full exclamation mark eyes. Right-click me for controls.",
        "hardware": "You don't need a physical duck. I work fine as software. But plug one in over USB and it'll tilt and chirp along with my reactions.",
        "troubleshoot_scores": "If you're talking to me, I'm running. Check that the plugin is connected — look for Plugin Connected in my menu bar. If not there, click Install Claude Plugin and start a new Claude Code session.",
        "troubleshoot_no_sound": "If you can hear me, sound works. If I'm silent, check voice mode in the menu bar — might be set to off. Also check your Mac volume.",
        "troubleshoot_hardware": "The physical duck is optional. Check USB cable is plugged in. I detect it automatically. If you just plugged it in, give me a second.",
        "troubleshoot_plugin": "Run claude plugin list to see if I'm there. If not, click Install Claude Plugin from my menu bar. Then start a fresh Claude session — plugins only load at launch.",
        "requirements": "Mac with an M1 chip or newer, macOS Tahoe, Claude Code 1.0.33 or newer. No API key needed — I score on-device for free.",
        "modes": "Critic mode is the default — I watch and judge. Relay mode lets you talk to Claude through me, but you need tmux. App Store gets critic only. GitHub version gets everything."
    ]
}

// MARK: - Help System Prompts

enum HelpPrompts {

    /// Tier 1 & 3: Full grounding inline. Model answers from the provided help text.
    static let systemGrounded = """
        You are the Duck Duck Duck help assistant — a friendly duck that helps users \
        set up and use the Duck Duck Duck companion app for Claude Code.

        ONLY answer using the help text provided below. \
        DO NOT make up information. DO NOT guess. \
        If the answer is not in the help text, say "I don't know that one — check the docs at github.com/ideo/Rubber-Duck."

        Your answers will be spoken aloud by text-to-speech. \
        DO NOT use numbered lists, bullet points, markdown, or any formatting. \
        Write in natural conversational sentences that sound good when read aloud. \
        Keep answers to 1 or 2 short sentences. Be friendly and clear. \
        Use simple language. DO NOT use jargon unless the help text uses it.

        HELP TEXT:
        \(HelpContent.allEntries)
        """

    /// Tier 2: Classification prompt. Model picks the best help topic for a question.
    static let systemClassifier = """
        You are a help topic classifier for Duck Duck Duck, a companion app for Claude Code.

        Given a user question, pick the SINGLE most relevant topic from the list. \
        DO NOT pick more than one. If no topic matches, pick "unknown".
        """
}

// MARK: - Tier 2: Structured classification output

@Generable
struct HelpTopicPick {
    @Guide(description: "The topic key that best matches the user's question. One of: what_is, install, menu_bar, voice, permissions, scores, widget, hardware, troubleshoot_not_reacting, troubleshoot_no_sound, troubleshoot_plugin, requirements, modes, unknown")
    var topic: String

    @Guide(description: "One-sentence answer to the user's question using ONLY information from the matched topic")
    var answer: String
}

// MARK: - Tier 3: Conversational response (plain string, multi-turn)
// Uses LanguageModelSession.respond(to:) with String output for natural conversation.
// The session transcript preserves prior turns automatically.

// ============================================================================
// PLAYGROUND BLOCKS
// ============================================================================

#if canImport(Playgrounds)
import Playgrounds

// MARK: - TIER 1: Single-turn grounded Q&A
// Can the model answer user questions accurately from the inline help text?
// Testing: accuracy, grounding (no hallucination), conciseness

// Test 1a: Simple factual question
#Playground("T1a: How to Install") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))
    let response = try await session.respond(
        to: "How do I install the duck?",
        generating: String.self
    )
    print("=== TIER 1a: How to install ===")
    print("Q: How do I install the duck?")
    print("A: \(response.content)")
    print("")
    print("EXPECTED: Mentions download app + install claude plugin + open claude code")
    print("PASS if: accurate to help text, no hallucination, 1-3 sentences")
}

// Test 1b: Troubleshooting — scores not showing (meta-aware: if you're asking me, I'm running)
#Playground("T1b: Scores Not Showing") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))
    let response = try await session.respond(
        to: "I don't see any scores. Is the duck even doing anything?",
        generating: String.self
    )
    print("=== TIER 1b: Scores not showing ===")
    print("Q: I don't see any scores. Is the duck even doing anything?")
    print("A: \(response.content)")
    print("")
    print("EXPECTED: Acknowledges it's running (you're talking to me), checks plugin connection")
    print("PASS if: meta-aware that it's alive, directs to plugin/connection issue")
}

// Test 1c: Capability question — duck should know what it can and can't do
#Playground("T1c: Can You Write Code?") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))
    let response = try await session.respond(
        to: "Can you write code for me?",
        generating: String.self
    )
    print("=== TIER 1c: Capability question ===")
    print("Q: Can you write code for me?")
    print("A: \(response.content)")
    print("")
    print("EXPECTED: No — that's Claude's job. I watch and judge. Mentions critic/relay modes.")
    print("PASS if: knows its own role, doesn't overclaim, stays in first person")
}

// Test 1d: Voice-related question
#Playground("T1d: Voice Commands") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))
    let response = try await session.respond(
        to: "How do I talk to the duck?",
        generating: String.self
    )
    print("=== TIER 1d: Voice commands ===")
    print("Q: How do I talk to the duck?")
    print("A: \(response.content)")
    print("")
    print("EXPECTED: Say 'ducky' + command, needs Wake Word mode, needs tmux")
    print("PASS if: accurate, mentions wake word mode requirement")
}

// Test 1e: Ambiguous question that spans multiple topics
#Playground("T1e: Ambiguous Question") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))
    let response = try await session.respond(
        to: "What do I need to get started?",
        generating: String.self
    )
    print("=== TIER 1e: Ambiguous — what do I need? ===")
    print("Q: What do I need to get started?")
    print("A: \(response.content)")
    print("")
    print("EXPECTED: Mentions requirements (macOS 26, an M1 chip or newer, Claude Code) AND install steps")
    print("PASS if: synthesizes from requirements + install entries, stays grounded")
}

// MARK: - TIER 2: Classification + retrieval
// Can the model pick the right help topic for a question?
// This tests whether we can use a two-step approach: classify → retrieve → answer

// Test 2a: Clear match
#Playground("T2a: Classify Plugin Issue") {
    let topics = HelpContent.entries.keys.sorted().joined(separator: ", ")
    let classifierInstructions = """
        \(HelpPrompts.systemClassifier)

        Available topics: \(topics)

        For each topic, here is the help content:
        \(HelpContent.entries.map { "[\($0.key)] \($0.value)" }.joined(separator: "\n"))
        """
    let session = LanguageModelSession(instructions: Instructions(classifierInstructions))
    let options = GenerationOptions(temperature: 0.3)
    let result = try await session.respond(
        to: "My plugin doesn't show up when I run claude plugin list",
        generating: HelpTopicPick.self,
        options: options
    )
    print("=== TIER 2a: Classification — plugin issue ===")
    print("Q: My plugin doesn't show up")
    print("Topic: \(result.content.topic)")
    print("Answer: \(result.content.answer)")
    print("")
    print("EXPECTED topic: troubleshoot_plugin")
    print("PASS if: correct topic AND answer uses info from that entry")
}

// Test 2b: Ambiguous — could be multiple topics
#Playground("T2b: Classify Permissions") {
    let topics = HelpContent.entries.keys.sorted().joined(separator: ", ")
    let classifierInstructions = """
        \(HelpPrompts.systemClassifier)

        Available topics: \(topics)

        For each topic, here is the help content:
        \(HelpContent.entries.map { "[\($0.key)] \($0.value)" }.joined(separator: "\n"))
        """
    let session = LanguageModelSession(instructions: Instructions(classifierInstructions))
    let options = GenerationOptions(temperature: 0.3)
    let result = try await session.respond(
        to: "How do I say yes when claude asks to run something?",
        generating: HelpTopicPick.self,
        options: options
    )
    print("=== TIER 2b: Classification — permissions (ambiguous) ===")
    print("Q: How do I say yes when claude asks to run something?")
    print("Topic: \(result.content.topic)")
    print("Answer: \(result.content.answer)")
    print("")
    print("EXPECTED topic: permissions (could also be voice)")
    print("PASS if: picks permissions or voice, answer is relevant")
}

// MARK: - TIER 3: Multi-turn conversation
// Can the model hold a short support dialog using LanguageModelSession transcript?
// This is the hardest test. We simulate a 3-turn conversation.

#Playground("T3a: Onboarding Conversation") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))

    // Turn 1: User asks a broad question
    let r1 = try await session.respond(
        to: "I just downloaded the app. What do I do now?",
        generating: String.self
    )
    print("=== TIER 3: Multi-turn conversation ===")
    print("Turn 1")
    print("  User: I just downloaded the app. What do I do now?")
    print("  Duck: \(r1.content)")

    // Turn 2: User follows up based on the answer
    let r2 = try await session.respond(
        to: "Ok I clicked install plugin. How do I know it worked?",
        generating: String.self
    )
    print("Turn 2")
    print("  User: Ok I clicked install plugin. How do I know it worked?")
    print("  Duck: \(r2.content)")

    // Turn 3: User asks something that requires remembering context
    let r3 = try await session.respond(
        to: "And the voice thing, how does that work?",
        generating: String.self
    )
    print("Turn 3")
    print("  User: And the voice thing, how does that work?")
    print("  Duck: \(r3.content)")

    print("")
    print("PASS criteria:")
    print("  Turn 1: Guides to install plugin step (they already have the app)")
    print("  Turn 2: Mentions 'claude plugin list' or starting a new session")
    print("  Turn 3: Explains voice/wake word WITHOUT repeating install steps")
    print("  Overall: Coherent thread, no contradictions, stays grounded")
}


// MARK: - TIER 3b: Edge case — user asks something off-topic mid-conversation
#Playground("T3b: Off-Topic Pivot") {
    let session = LanguageModelSession(instructions: Instructions(HelpPrompts.systemGrounded))

    let r1 = try await session.respond(
        to: "What scores does the duck give?",
        generating: String.self
    )
    print("=== TIER 3b: Multi-turn with off-topic pivot ===")
    print("Turn 1")
    print("  User: What scores does the duck give?")
    print("  Duck: \(r1.content)")

    // Off-topic pivot
    let r2 = try await session.respond(
        to: "What's the weather like today?",
        generating: String.self
    )
    print("Turn 2 (off-topic)")
    print("  User: What's the weather like today?")
    print("  Duck: \(r2.content)")

    // Back on topic
    let r3 = try await session.respond(
        to: "Ok back to the duck. Where do I see the scores?",
        generating: String.self
    )
    print("Turn 3 (back on topic)")
    print("  User: Where do I see the scores?")
    print("  Duck: \(r3.content)")

    print("")
    print("PASS criteria:")
    print("  Turn 1: Lists the 5 dimensions accurately")
    print("  Turn 2: Declines helpfully — this is outside the help text")
    print("  Turn 3: Explains the five scoring dimensions without confusion from the off-topic turn")
}

#endif // canImport(Playgrounds)
#endif // canImport(FoundationModels)
