// Duck Voices — Available TTS voices for the context menu picker.
//
// Each entry maps a short label (for the menu), the `say -v` name (Teensy path),
// and the AVSpeechSynthesisVoice identifier (ESP32 serial path).

import Foundation

struct DuckVoice {
    let label: String       // Short name for the menu
    let sayName: String     // Full name passed to `say -v` (Teensy/local path)
    let voiceId: String     // AVSpeechSynthesisVoice identifier (serial TTS path)
}

enum DuckVoices {

    // MARK: - Named voices (used as direct references instead of string lookups)

    static let superstar = DuckVoice(label: "Superstar", sayName: "Superstar", voiceId: "com.apple.speech.synthesis.voice.Princess")

    // Main — the duck's best voices, top of the menu
    static let main: [DuckVoice] = [
        DuckVoice(label: "Boing", sayName: "Boing", voiceId: "com.apple.speech.synthesis.voice.Boing"),
        DuckVoice(label: "Ralph", sayName: "Ralph", voiceId: "com.apple.speech.synthesis.voice.Ralph"),
        DuckVoice(label: "Kathy", sayName: "Kathy", voiceId: "com.apple.speech.synthesis.voice.Kathy"),
        superstar,
        DuckVoice(label: "Samantha", sayName: "Samantha", voiceId: "com.apple.voice.compact.en-US.Samantha"),
    ]

    // Classic — robot / speak-n-spell vibes
    static let classic: [DuckVoice] = [
        DuckVoice(label: "Fred", sayName: "Fred", voiceId: "com.apple.speech.synthesis.voice.Fred"),
        DuckVoice(label: "Eddy", sayName: "Eddy (English (US))", voiceId: "com.apple.eloquence.en-US.Eddy"),
        DuckVoice(label: "Rocko", sayName: "Rocko (English (US))", voiceId: "com.apple.eloquence.en-US.Rocko"),
        DuckVoice(label: "Shelley", sayName: "Shelley (English (US))", voiceId: "com.apple.eloquence.en-US.Shelley"),
        DuckVoice(label: "Flo", sayName: "Flo (English (US))", voiceId: "com.apple.eloquence.en-US.Flo"),
        DuckVoice(label: "Nicky", sayName: "Nicky (Enhanced)", voiceId: "com.apple.ttsbundle.siri_Nicky_en-US_premium"),
        DuckVoice(label: "Junior", sayName: "Junior", voiceId: "com.apple.speech.synthesis.voice.Junior"),
    ]

    // Special FX — musical, weird, wonderful
    static let specialFX: [DuckVoice] = [
        DuckVoice(label: "Bad News", sayName: "Bad News", voiceId: "com.apple.speech.synthesis.voice.BadNews"),
        DuckVoice(label: "Good News", sayName: "Good News", voiceId: "com.apple.speech.synthesis.voice.GoodNews"),
        DuckVoice(label: "Cellos", sayName: "Cellos", voiceId: "com.apple.speech.synthesis.voice.Cellos"),
        DuckVoice(label: "Organ", sayName: "Organ", voiceId: "com.apple.speech.synthesis.voice.Organ"),
        DuckVoice(label: "Whisper", sayName: "Whisper", voiceId: "com.apple.speech.synthesis.voice.Whisper"),
        DuckVoice(label: "Trinoids", sayName: "Trinoids", voiceId: "com.apple.speech.synthesis.voice.Trinoids"),
        DuckVoice(label: "Zarvox", sayName: "Zarvox", voiceId: "com.apple.speech.synthesis.voice.Zarvox"),
        DuckVoice(label: "Jester", sayName: "Jester", voiceId: "com.apple.speech.synthesis.voice.Hysterical"),
        DuckVoice(label: "Bubbles", sayName: "Bubbles", voiceId: "com.apple.speech.synthesis.voice.Bubbles"),
    ]

    // British — the UK variants
    static let british: [DuckVoice] = [
        DuckVoice(label: "Eddy (UK)", sayName: "Eddy (English (UK))", voiceId: "com.apple.eloquence.en-GB.Eddy"),
        DuckVoice(label: "Rocko (UK)", sayName: "Rocko (English (UK))", voiceId: "com.apple.eloquence.en-GB.Rocko"),
        DuckVoice(label: "Shelley (UK)", sayName: "Shelley (English (UK))", voiceId: "com.apple.eloquence.en-GB.Shelley"),
        DuckVoice(label: "Daniel (UK)", sayName: "Daniel", voiceId: "com.apple.voice.compact.en-GB.Daniel"),
    ]

    /// All voices in menu order.
    static let all: [DuckVoice] = main + classic + specialFX + british

    // MARK: - O(1) Lookups

    /// Dictionary for O(1) lookup by sayName.
    private static let sayNameMap: [String: DuckVoice] = {
        Dictionary(all.map { ($0.sayName, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    /// Look up the AVSpeechSynthesisVoice identifier for a given sayName.
    static func voiceId(for sayName: String) -> String? {
        sayNameMap[sayName]?.voiceId
    }

    /// Look up a DuckVoice by sayName.
    static func voice(for sayName: String) -> DuckVoice? {
        sayNameMap[sayName]
    }

    // MARK: - Wildcard Mode

    /// Sentinel value stored in UserDefaults when Wildcard is active.
    static let wildcardSayName = "__wildcard__"

    /// Check persisted voice setting (for use outside SpeechService, e.g. DuckServer).
    static var isWildcardPersisted: Bool {
        UserDefaults.standard.string(forKey: "duck_tts_voice") == wildcardSayName
    }

    /// Default voice when Wildcard can't pick (or AI returns unknown key).
    static let wildcardDefault = superstar

    /// Type-safe voice keys for AI wildcard selection.
    /// Raw values match the keys in the eval prompt and JSON response.
    enum WildcardKey: String, CaseIterable {
        case superstar
        case ralph
        case badNews = "bad_news"
        case goodNews = "good_news"
        case cellos
        case organ
        case whisper
        case trinoids
        case zarvox
        case jester
        case bubbles
    }

    /// Map WildcardKey → DuckVoice.
    private static let wildcardKeyMap: [WildcardKey: DuckVoice] = {
        var map: [WildcardKey: DuckVoice] = [:]
        let pairs: [(WildcardKey, String)] = [
            (.superstar, "Superstar"), (.ralph, "Ralph"),
            (.badNews, "Bad News"), (.goodNews, "Good News"),
            (.cellos, "Cellos"), (.organ, "Organ"),
            (.whisper, "Whisper"), (.trinoids, "Trinoids"),
            (.zarvox, "Zarvox"), (.jester, "Jester"),
            (.bubbles, "Bubbles"),
        ]
        for (key, sayName) in pairs {
            if let voice = sayNameMap[sayName] {
                map[key] = voice
            }
        }
        return map
    }()

    /// Resolve an AI-returned voice key string to a DuckVoice. Falls back to Superstar.
    static func wildcardVoice(for key: String) -> DuckVoice {
        guard let wk = WildcardKey(rawValue: key) else { return wildcardDefault }
        return wildcardKeyMap[wk] ?? wildcardDefault
    }

    /// Resolve a persisted sayName to a real engine voice name.
    /// Translates the wildcard sentinel to Superstar; passes everything else through.
    static func resolvedSayName(for sayName: String) -> String {
        sayName == wildcardSayName ? wildcardDefault.sayName : sayName
    }

    /// Voice descriptions for the AI prompt (Haiku eval).
    static let wildcardPromptDescription = """
        Pick the voice that best delivers your reaction. Use superstar about half the time — use the others whenever the moment has a clear vibe.
        - superstar: upbeat sparkly pop star. for positive, energetic, or neutral reactions.
        - ralph: deeper serious voice. ONLY for truly dull moments — pure boilerplate, config files, nothing remotely interesting.
        - bad_news: somber ominous organ. ONLY for genuinely bad news — failures, breaking changes, deleted data.
        - good_news: bright cheerful singing. for when the code is really good — elegant solution, impressive fix, high scores across the board.
        - cellos: deep dramatic strings. for big surprising changes — major refactors, unexpected approaches, "wait they did WHAT?"
        - organ: grand church-like. for ambitious scope — massive PRs, bold architecture decisions, swinging for the fences.
        - whisper: quiet secretive. for secrets, very internal thoughts, confiding something private. the inner voice.
        - trinoids: alien robotic. for inhuman things — bizarre code, incomprehensible logic.
        - zarvox: electronic sci-fi. for inhuman things — alien approaches, machine-like precision.
        - jester: silly court jester. ONLY when something is genuinely funny or absurd. must be hilarious.
        - bubbles: bubbly underwater. ONLY for overwhelm — "I'm drowning here", too much at once.
        """
}
