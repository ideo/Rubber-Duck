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

    // Main — the duck's best voices, top of the menu
    static let main: [DuckVoice] = [
        DuckVoice(label: "Boing", sayName: "Boing", voiceId: "com.apple.speech.synthesis.voice.Boing"),
        DuckVoice(label: "Ralph", sayName: "Ralph", voiceId: "com.apple.speech.synthesis.voice.Ralph"),
        DuckVoice(label: "Kathy", sayName: "Kathy", voiceId: "com.apple.speech.synthesis.voice.Kathy"),
        DuckVoice(label: "Superstar", sayName: "Superstar", voiceId: "com.apple.speech.synthesis.voice.Princess"),
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
        DuckVoice(label: "Jester", sayName: "Jester", voiceId: "com.apple.speech.synthesis.voice.Jester"),
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

    /// Look up the AVSpeechSynthesisVoice identifier for a given sayName.
    static func voiceId(for sayName: String) -> String? {
        all.first { $0.sayName == sayName }?.voiceId
    }
}
