// Duck Voices — Available TTS voices for the context menu picker.
//
// Each entry maps a short label (for the menu) to the full `say -v` name.
// Only includes English voices that are fun or sound good on a duck.

import Foundation

struct DuckVoice {
    let label: String    // Short name for the menu
    let sayName: String  // Full name passed to `say -v`
}

enum DuckVoices {

    // Novelty (the goofy ones)
    static let novelty: [DuckVoice] = [
        DuckVoice(label: "Bad News", sayName: "Bad News"),
        DuckVoice(label: "Boing", sayName: "Boing"),
        DuckVoice(label: "Cellos", sayName: "Cellos"),
        DuckVoice(label: "Good News", sayName: "Good News"),
        DuckVoice(label: "Organ", sayName: "Organ"),
        DuckVoice(label: "Superstar", sayName: "Superstar"),
    ]

    // Siri / modern voices
    static let siri: [DuckVoice] = [
        DuckVoice(label: "Nicky", sayName: "Nicky (Enhanced)"),
        DuckVoice(label: "Eddy", sayName: "Eddy (English (US))"),
        DuckVoice(label: "Flo", sayName: "Flo (English (US))"),
        DuckVoice(label: "Grandma", sayName: "Grandma (English (US))"),
        DuckVoice(label: "Grandpa", sayName: "Grandpa (English (US))"),
        DuckVoice(label: "Reed", sayName: "Reed (English (US))"),
        DuckVoice(label: "Sandy", sayName: "Sandy (English (US))"),
        DuckVoice(label: "Shelley", sayName: "Shelley (English (US))"),
        DuckVoice(label: "Rocko", sayName: "Rocko (English (US))"),
    ]

    // Classic macOS voices
    static let classic: [DuckVoice] = [
        DuckVoice(label: "Fred", sayName: "Fred"),
        DuckVoice(label: "Junior", sayName: "Junior"),
        DuckVoice(label: "Kathy", sayName: "Kathy"),
        DuckVoice(label: "Ralph", sayName: "Ralph"),
        DuckVoice(label: "Samantha", sayName: "Samantha"),
    ]

    /// All voices in menu order: novelty → siri → classic.
    static let all: [DuckVoice] = novelty + siri + classic
}
