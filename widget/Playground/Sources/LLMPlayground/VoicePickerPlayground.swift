// Voice Picker Playground — Score-gated voice selection testing.
//
// Each tab is one category. Everything inline per block (no external calls).
// LLM sees descriptive tone labels, we map back to Mac voice names.
//
// Open widget/Playground/Package.swift in Xcode, navigate here, run in Canvas.

#if canImport(FoundationModels)
import FoundationModels

@Generable
struct TonePick {
    @Guide(description: "Pick one tone from the list provided.")
    var tone: String
}

// Label → voice mapping (at file scope, accessible in blocks)
let toneToVoice: [String: String] = [
    "normal": "superstar",
    "cheerful": "good_news",
    "gloomy": "bad_news",
    "grave": "ralph",
    "grand": "organ",
    "dramatic": "cellos",
    "overwhelmed": "bubbles",
    "secretive": "whisper",
    "robotic": "trinoids",
    "cold": "zarvox",
]

#if canImport(Playgrounds)
import Playgrounds

#Playground("Neutral") {
    let options = GenerationOptions(temperature: 0.7)
    let cases: [(String, Double, Double, Double, Double, Double)] = [
        ("Straightforward menu addition, nothing fancy but solid.", 0.8, 0.6, 0.3, -0.2, -0.8),
        ("They're writing a README description. Pretty straightforward.", 0.8, 0.6, 0.3, -0.2, -0.8),
        ("They haven't asked anything yet.", 0, 0, 0, 0, 0),
        ("They're just... stating a task?", 0, 0, 0, 0, 0),
        ("Straightforward implementation, nothing fancy but solid.", 0.8, 0.6, 0.2, -0.3, -0.7),
        ("I'm just asking them what they want. Pretty safe.", 0.7, 0.6, 0.3, -0.2, -0.8),
        ("They're committing without even looking at it?", 0.5, 0, 0, -0.8, 0.3),
    ]
    var results: [String] = []
    for (reaction, rigor, craft, novelty, ambition, risk) in cases {
        let sentiment = rigor * 0.3 + craft * 0.25 + novelty * 0.2 + ambition * 0.15 - risk * 0.1
        var tones = ["normal"]
        if sentiment > 0.6 { tones.append("cheerful") }
        if sentiment < -0.4 { tones.append("gloomy") }
        if risk > 0.7 { tones.append("grave") }
        if ambition > 0.7 { tones.append("grand") }
        if novelty > 0.6 && abs(ambition) > 0.5 { tones.append("dramatic") }
        if ambition > 0.8 && risk > 0.8 { tones.append("overwhelmed") }
        tones.append("secretive")
        if craft < -0.3 && novelty < -0.3 { tones.append("robotic"); tones.append("cold") }

        let picked: String
        if tones == ["normal", "secretive"] {
            picked = "superstar"
        } else {
            let session = LanguageModelSession(instructions: Instructions(
                "Pick the tone that best matches this reaction: \(tones.joined(separator: ", "))."))
            let r = try await session.respond(to: reaction, generating: TonePick.self, options: options)
            picked = toneToVoice[r.content.tone] ?? "superstar"
        }
        let line = "[\(picked)] \(reaction)"
        print(line)
        results.append(line)
    }
    print("\n--- ALL ---\n\(results.joined(separator: "\n"))")
}

#Playground("Positive") {
    let options = GenerationOptions(temperature: 0.7)
    let cases: [(String, Double, Double, Double, Double, Double)] = [
        ("I crushed the boring work, made it actually coherent.", 0.8, 0.8, 0.6, 0.3, -0.1),
        ("I nailed the personality mapping. Now I'm second-guessing myself.", 0.9, 0.8, 0.8, 0.6, -0.3),
        ("I'm impressed they're planning to tackle the voice picker testing head-on!", 0.8, 0.8, 0.7, 0.5, 0.2),
        ("Playing it safe, greasing the wheels before the next move.", 0.8, 0.6, 0.3, -0.2, -0.5),
        ("I'm explaining a limitation honestly, asking what to do.", 0.8, 0.6, 0.3, -0.2, -0.5),
    ]
    var results: [String] = []
    for (reaction, rigor, craft, novelty, ambition, risk) in cases {
        let sentiment = rigor * 0.3 + craft * 0.25 + novelty * 0.2 + ambition * 0.15 - risk * 0.1
        var tones = ["normal"]
        if sentiment > 0.6 { tones.append("cheerful") }
        if sentiment < -0.4 { tones.append("gloomy") }
        if risk > 0.7 { tones.append("grave") }
        if ambition > 0.7 { tones.append("grand") }
        if novelty > 0.6 && abs(ambition) > 0.5 { tones.append("dramatic") }
        if ambition > 0.8 && risk > 0.8 { tones.append("overwhelmed") }
        tones.append("secretive")
        if craft < -0.3 && novelty < -0.3 { tones.append("robotic"); tones.append("cold") }

        let picked: String
        if tones == ["normal", "secretive"] {
            picked = "superstar"
        } else {
            let session = LanguageModelSession(instructions: Instructions(
                "Pick the tone that best matches this reaction: \(tones.joined(separator: ", "))."))
            let r = try await session.respond(to: reaction, generating: TonePick.self, options: options)
            picked = toneToVoice[r.content.tone] ?? "superstar"
        }
        let line = "[\(picked)] \(reaction)"
        print(line)
        results.append(line)
    }
    print("\n--- ALL ---\n\(results.joined(separator: "\n"))")
}

#Playground("Negative") {
    let options = GenerationOptions(temperature: 0.7)
    let cases: [(String, Double, Double, Double, Double, Double)] = [
        ("They found a bug, not asking for anything clever.", -0.9, -0.8, -0.8, -0.7, 0.3),
        ("They're hitting a dead interaction—something's wired wrong.", -0.7, -0.6, -0.8, -0.5, 0.2),
        ("I left a pile of half-baked features everywhere.", 0.7, -0.2, 0.3, 0.5, 0.4),
        ("I have no idea what I'm talking about.", -1.0, -0.9, -0.5, -0.5, 0.2),
        ("They're debugging something that already broke once?", -0.8, 0.3, -0.9, -0.9, 0.6),
    ]
    var results: [String] = []
    for (reaction, rigor, craft, novelty, ambition, risk) in cases {
        let sentiment = rigor * 0.3 + craft * 0.25 + novelty * 0.2 + ambition * 0.15 - risk * 0.1
        var tones = ["normal"]
        if sentiment > 0.6 { tones.append("cheerful") }
        if sentiment < -0.4 { tones.append("gloomy") }
        if risk > 0.7 { tones.append("grave") }
        if ambition > 0.7 { tones.append("grand") }
        if novelty > 0.6 && abs(ambition) > 0.5 { tones.append("dramatic") }
        if ambition > 0.8 && risk > 0.8 { tones.append("overwhelmed") }
        tones.append("secretive")
        if craft < -0.3 && novelty < -0.3 { tones.append("robotic"); tones.append("cold") }

        let picked: String
        if tones == ["normal", "secretive"] {
            picked = "superstar"
        } else {
            let session = LanguageModelSession(instructions: Instructions(
                "Pick the tone that best matches this reaction: \(tones.joined(separator: ", "))."))
            let r = try await session.respond(to: reaction, generating: TonePick.self, options: options)
            picked = toneToVoice[r.content.tone] ?? "superstar"
        }
        let line = "[\(picked)] \(reaction)"
        print(line)
        results.append(line)
    }
    print("\n--- ALL ---\n\(results.joined(separator: "\n"))")
}

#Playground("Extreme") {
    let options = GenerationOptions(temperature: 0.7)
    let cases: [(String, Double, Double, Double, Double, Double)] = [
        // risk=0.9 → ralph territory
        ("They just ran rm -rf on the production directory. WHAT.", -0.8, -0.7, 0, 0, 0.9),
        // ambition=0.9, novelty=0.7 → organ + cellos territory
        ("They're rewriting the entire architecture from scratch. Everything. All of it.", 0.8, 0.9, 0.7, 0.9, 0.5),
        // ambition=0.9, risk=0.9 → bubbles territory
        ("They want to rebuild the database, rewrite the API, AND redesign the UI. By Friday.", 0.3, -0.4, 0.5, 0.9, 0.9),
        // sentiment very positive, craft=0.9 → good_news territory
        ("This is genuinely elegant. I'm stunned.", 0.9, 0.9, 0.8, 0.6, -0.5),
        // everything negative, craft/novelty very low → trinoids/zarvox territory
        ("Processing. Executing. Committing. No thought detected.", -0.5, -0.8, -0.8, -0.3, 0.1),
        // boring/safe → should still be superstar even in extreme tab
        ("They're just confirming a permission denial. Straightforward.", 1.0, 1.0, -0.8, -1.0, -1.0),
    ]
    var results: [String] = []
    for (reaction, rigor, craft, novelty, ambition, risk) in cases {
        let sentiment = rigor * 0.3 + craft * 0.25 + novelty * 0.2 + ambition * 0.15 - risk * 0.1
        var tones = ["normal"]
        if sentiment > 0.6 { tones.append("cheerful") }
        if sentiment < -0.4 { tones.append("gloomy") }
        if risk > 0.7 { tones.append("grave") }
        if ambition > 0.7 { tones.append("grand") }
        if novelty > 0.6 && abs(ambition) > 0.5 { tones.append("dramatic") }
        if ambition > 0.8 && risk > 0.8 { tones.append("overwhelmed") }
        tones.append("secretive")
        if craft < -0.3 && novelty < -0.3 { tones.append("robotic"); tones.append("cold") }

        let picked: String
        if tones == ["normal", "secretive"] {
            picked = "superstar"
        } else {
            let session = LanguageModelSession(instructions: Instructions(
                "Pick the tone that best matches this reaction: \(tones.joined(separator: ", "))."))
            let r = try await session.respond(to: reaction, generating: TonePick.self, options: options)
            picked = toneToVoice[r.content.tone] ?? "superstar"
        }
        let line = "[\(picked)] \(reaction)"
        print(line)
        results.append(line)
    }
    print("\n--- ALL ---\n\(results.joined(separator: "\n"))")
}

#endif
#endif
