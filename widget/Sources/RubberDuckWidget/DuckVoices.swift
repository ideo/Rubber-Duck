// Duck Voices — Available TTS voices for the context menu picker.
//
// Each entry maps a short label (for the menu), the `say -v` name (Teensy path),
// and the AVSpeechSynthesisVoice identifier (ESP32 serial path).

import Foundation

struct DuckVoice {
    let label: String       // Short name for the menu
    let sayName: String     // Full name passed to `say -v` (Teensy/local path)
    let voiceId: String     // AVSpeechSynthesisVoice identifier (serial TTS path)
    var previews: [String] = ["This is how I sound."]

    /// Random preview line about the tone/sound (not a character intro).
    var preview: String { previews.randomElement()! }
}

enum DuckVoices {

    // MARK: - Named voices (used as direct references instead of string lookups)

    static let superstar = DuckVoice(label: "Superstar", sayName: "Superstar", voiceId: "com.apple.speech.synthesis.voice.Princess",
                                         previews: ["Bright and sparkly.", "The showstopper.", "Extra in the best way.", "Glittery and bold.", "Main character energy."])

    // Main — the duck's best voices, top of the menu
    static let main: [DuckVoice] = [
        DuckVoice(label: "Boing", sayName: "Boing", voiceId: "com.apple.speech.synthesis.voice.Boing",
                  previews: ["The classic duck sound.", "Bouncy and quacky.", "Peak rubber duck energy.", "Sproingy and fun.", "Maximum cartoon vibes."]),
        DuckVoice(label: "Ralph", sayName: "Ralph", voiceId: "com.apple.speech.synthesis.voice.Ralph",
                  previews: ["Low and serious.", "The no-nonsense tone.", "Sounds like business.", "Deep and grounded.", "Straight to the point."]),
        DuckVoice(label: "Kathy", sayName: "Kathy", voiceId: "com.apple.speech.synthesis.voice.Kathy",
                  previews: ["Warm and steady.", "A friendly tone.", "Clear and calm.", "Approachable and even.", "Like a good coworker."]),
        superstar,
        DuckVoice(label: "Samantha", sayName: "Samantha", voiceId: "com.apple.voice.compact.en-US.Samantha",
                  previews: ["Clean and natural.", "The modern default.", "Crisp and clear.", "Smooth and polished.", "Neutral and reliable."]),
    ]

    // Classic — robot / speak-n-spell vibes
    static let classic: [DuckVoice] = [
        DuckVoice(label: "Fred", sayName: "Fred", voiceId: "com.apple.speech.synthesis.voice.Fred",
                  previews: ["The original Mac voice.", "Old school computing.", "Retro and classic.", "Nineteen eighty four called.", "The grandfather of Mac speech."]),
        DuckVoice(label: "Eddy", sayName: "Eddy (English (US))", voiceId: "com.apple.eloquence.en-US.Eddy",
                  previews: ["Tinny and robotic.", "Digital and buzzy.", "Speak and spell energy.", "Crunchy like a dial-up modem.", "Eight bit and proud."]),
        DuckVoice(label: "Rocko", sayName: "Rocko (English (US))", voiceId: "com.apple.eloquence.en-US.Rocko",
                  previews: ["Gritty and rough.", "A raspy machine.", "Sounds like gravel.", "Sandpaper smooth.", "Low and crunchy."]),
        DuckVoice(label: "Shelley", sayName: "Shelley (English (US))", voiceId: "com.apple.eloquence.en-US.Shelley",
                  previews: ["Bright and precise.", "Sharp and articulate.", "Crisp like a bell.", "Clear as a laser.", "Tight and focused."]),
        DuckVoice(label: "Flo", sayName: "Flo (English (US))", voiceId: "com.apple.eloquence.en-US.Flo",
                  previews: ["Smooth and even.", "Laid back and mellow.", "Easy on the ears.", "Relaxed and flowing.", "Chill and steady."]),
        DuckVoice(label: "Nicky", sayName: "Nicky (Enhanced)", voiceId: "com.apple.ttsbundle.siri_Nicky_en-US_premium",
                  previews: ["High fidelity.", "The polished one.", "Sounds almost human.", "Premium and refined.", "The HD upgrade."]),
        DuckVoice(label: "Junior", sayName: "Junior", voiceId: "com.apple.speech.synthesis.voice.Junior",
                  previews: ["Small and squeaky.", "The little voice.", "High pitched and light.", "Tiny but mighty.", "Like a chipmunk at work."]),
    ]

    // Special FX — musical, weird, wonderful
    static let specialFX: [DuckVoice] = [
        DuckVoice(label: "Bad News", sayName: "Bad News", voiceId: "com.apple.speech.synthesis.voice.BadNews",
                  previews: ["Everything sounds grim.", "The doom and gloom tone.", "Heavy and foreboding.", "Dark clouds rolling in.", "Ominous by default."]),
        DuckVoice(label: "Good News", sayName: "Good News", voiceId: "com.apple.speech.synthesis.voice.GoodNews",
                  previews: ["Bright and uplifting.", "The optimistic tone.", "Sunshine in audio form.", "Glass half full, always.", "Perpetually cheerful."]),
        DuckVoice(label: "Cellos", sayName: "Cellos", voiceId: "com.apple.speech.synthesis.voice.Cellos",
                  previews: ["Deep and resonant.", "Like an orchestra pit.", "Rich and dramatic.", "Strings attached.", "Vibrating with gravitas."]),
        DuckVoice(label: "Organ", sayName: "Organ", voiceId: "com.apple.speech.synthesis.voice.Organ",
                  previews: ["Grand and booming.", "Cathedral acoustics.", "Big and echoey.", "Pipe organ energy.", "Fills the whole room."]),
        DuckVoice(label: "Whisper", sayName: "Whisper", voiceId: "com.apple.speech.synthesis.voice.Whisper",
                  previews: ["Barely audible.", "The quiet one.", "Soft and hushed.", "Turn the volume way up.", "A gentle breeze of sound."]),
        DuckVoice(label: "Trinoids", sayName: "Trinoids", voiceId: "com.apple.speech.synthesis.voice.Trinoids",
                  previews: ["Alien and metallic.", "Pure machine.", "Cold and calculated.", "From another planet.", "Distinctly non-human."]),
        DuckVoice(label: "Zarvox", sayName: "Zarvox", voiceId: "com.apple.speech.synthesis.voice.Zarvox",
                  previews: ["Flat and synthetic.", "Maximum robot.", "Zero warmth, all circuit.", "The uncanny valley floor.", "Aggressively digital."]),
        DuckVoice(label: "Jester", sayName: "Jester", voiceId: "com.apple.speech.synthesis.voice.Hysterical",
                  previews: ["Chaotic and silly.", "Unhinged energy.", "The clown car of voices.", "Wildly unstable.", "Comedy at all costs."]),
        DuckVoice(label: "Bubbles", sayName: "Bubbles", voiceId: "com.apple.speech.synthesis.voice.Bubbles",
                  previews: ["Underwater gargling.", "Blub blub blub.", "Sounds like drowning.", "Submerged and bubbly.", "The deep end of the pool."]),
    ]

    // British — the UK variants
    static let british: [DuckVoice] = [
        DuckVoice(label: "Eddy (UK)", sayName: "Eddy (English (UK))", voiceId: "com.apple.eloquence.en-GB.Eddy",
                  previews: ["Robotic with a British twist.", "Digital and posh.", "Tinny across the pond.", "Buzzy with a cuppa.", "Electronic and jolly."]),
        DuckVoice(label: "Rocko (UK)", sayName: "Rocko (English (UK))", voiceId: "com.apple.eloquence.en-GB.Rocko",
                  previews: ["Rough around the edges.", "Gravelly, but British.", "Gritty with manners.", "Sandpaper and tea.", "Coarse but polite."]),
        DuckVoice(label: "Shelley (UK)", sayName: "Shelley (English (UK))", voiceId: "com.apple.eloquence.en-GB.Shelley",
                  previews: ["Crisp and proper.", "Precise with an accent.", "Sharp and British.", "Neat and tidy.", "Buttoned up tight."]),
        DuckVoice(label: "Daniel (UK)", sayName: "Daniel", voiceId: "com.apple.voice.compact.en-GB.Daniel",
                  previews: ["The gentlemanly tone.", "Proper and polished.", "Calm British default.", "Measured and composed.", "Understated and clear."]),
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

    // MARK: - Silent Mode

    /// Sentinel value stored in UserDefaults when Silent is active (speech bubble only, no TTS).
    static let silentSayName = "__silent__"

    /// Check if Silent mode is persisted.
    static var isSilentPersisted: Bool {
        UserDefaults.standard.string(forKey: "duck_tts_voice") == silentSayName
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
        if sayName == wildcardSayName { return wildcardDefault.sayName }
        if sayName == silentSayName { return silentSayName }
        return sayName
    }

    /// Voice descriptions for the AI prompt (Haiku eval).
    static let wildcardPromptDescription = """
        Pick the voice that best delivers your reaction. Use superstar as the default — it covers anything positive, neutral, or boring. Only use other voices when the moment clearly calls for it.
        - superstar: the default voice. upbeat sparkly pop star. use for positive, energetic, neutral, AND boring/mundane reactions. this is home base.
        - ralph: deep gravitas voice. think batman. ONLY for moments demanding dead seriousness — security warnings, critical errors, stern corrections. never for boring content.
        - bad_news: somber ominous organ. ONLY for genuinely bad news — failures, breaking changes, deleted data.
        - good_news: bright cheerful singing. for when the code is really good — elegant solution, impressive fix, high scores across the board.
        - cellos: deep dramatic strings. for big surprising changes — major refactors, unexpected approaches, "wait they did WHAT?"
        - organ: grand church-like. for ambitious scope — massive PRs, bold architecture decisions, swinging for the fences.
        - whisper: quiet secretive. for secrets, private thoughts, embarrassing moments, or deep skepticism. the inner voice — confiding something awkward or muttering "I'm not sure about this..."
        - trinoids: alien robotic. for when the duck is acting like a machine — processing data, reciting lists, robotic behavior.
        - zarvox: electronic sci-fi. for when the duck is acting like a computer — calculating, analyzing, cold machine-like precision.
        - jester: silly court jester. ONLY when something is genuinely funny or absurd. must be hilarious.
        """
}
