// LaunchGreeting — context-aware startup greetings for the duck.
//
// Picks a greeting based on time of day, time since last launch, and duck mode.
// Critic mode = inner monologue ("Oh, they're back..."), Relay mode = direct address ("Hey!").
// State file lives in Application Support (sandbox-safe).

import Foundation

enum LaunchGreeting {
    private static let stateFile: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DuckDuckDuck")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-launch")
    }()

    /// Pick a launch greeting based on time of day, recency, and mode.
    static func pick(mode: DuckMode = .critic) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let minutesSince = minutesSinceLastLaunch()
        recordLaunch()

        let isCritic = mode == .critic

        // First ever launch
        if minutesSince == nil {
            return isCritic
                ? ["Oh. A new one. Let's see what they've got.",
                   "First launch. No pressure.",
                   "Fresh install smell. Interesting."].randomElement()!
                : ["First time! Let's see what you've got.",
                   "Hey there. I'm the duck.",
                   "New duck, who dis?"].randomElement()!
        }

        let mins = minutesSince!

        // Back within 5 minutes
        if mins < 5 {
            return isCritic
                ? ["They're back already. That was fast.",
                   "Couldn't stay away, huh.",
                   "Something must have broken."].randomElement()!
                : ["Miss me already?",
                   "Back so soon?",
                   "That was quick.",
                   "Did you forget something?"].randomElement()!
        }

        // Back within an hour
        if mins < 60 {
            return isCritic
                ? ["Round two. Let's see if they learned anything.",
                   "Back again. Here we go.",
                   "Alright, what are they up to now."].randomElement()!
                : ["Where were we?",
                   "Round two.",
                   "Alright, what now?",
                   "Back at it."].randomElement()!
        }

        // Been hours
        if mins < 1440 {
            return timeOfDayGreeting(hour, isCritic: isCritic)
        }

        // Been days
        let days = mins / 1440
        if days == 1 {
            return isCritic
                ? ["A whole day without me. They survived somehow.",
                   "Yesterday was quiet. Too quiet.",
                   "They're back. Took them long enough."].randomElement()!
                : ["Been a day. What's new?",
                   "Yesterday feels like forever ago.",
                   "Back for more?"].randomElement()!
        }
        return isCritic
            ? ["Oh. They remember I exist. \(days) days later.",
               "It's been \(days) days. I was starting to wonder.",
               "The human returns. Eventually."].randomElement()!
            : ["Long time no quack.",
               "It's been \(days) days. I was getting bored.",
               "Oh, you remembered I exist.",
               "The prodigal coder returns."].randomElement()!
    }

    /// Pick a session-connect greeting (when /health is pinged by a Claude session).
    static func sessionConnect(mode: DuckMode = .critic) -> String {
        let isCritic = mode == .critic
        return isCritic
            ? ["Session's up. Let's see what they're made of.",
               "Alright, I'm watching.",
               "New session. The pressure is on.",
               "Here we go again.",
               "Connected. Time to judge."].randomElement()!
            : ["What are we getting into?",
               "Alright, let's see what you've got.",
               "The duck is in.",
               "Session's live. Impress me.",
               "Oh good, another one.",
               "Ready when you are.",
               "Let's do this.",
               "Quack. I mean, hi."].randomElement()!
    }

    private static func timeOfDayGreeting(_ hour: Int, isCritic: Bool) -> String {
        switch hour {
        case 0..<6:
            return isCritic
                ? ["They're coding at this hour. Questionable judgment.",
                   "Middle of the night. This should be interesting.",
                   "Nothing good happens after midnight. And yet here they are."].randomElement()!
                : ["Burning the midnight oil?",
                   "It's late. This better be good.",
                   "Nothing good happens after midnight. Let's go."].randomElement()!
        case 6..<12:
            return isCritic
                ? ["Morning session. They seem motivated. We'll see how long that lasts.",
                   "Early bird. Let's see if the code matches the energy.",
                   "Fresh morning, fresh mistakes probably."].randomElement()!
                : ["Morning. What are we building?",
                   "Fresh start. Don't waste it.",
                   "Coffee ready? Let's go."].randomElement()!
        case 12..<17:
            return isCritic
                ? ["Post-lunch coding. Bold strategy.",
                   "Afternoon. The focus tends to drift around now.",
                   "Let's see what the afternoon brings."].randomElement()!
                : ["Afternoon. What are we getting into?",
                   "Post-lunch coding. Bold.",
                   "Alright, what's the plan?"].randomElement()!
        case 17..<21:
            return isCritic
                ? ["Evening session. They're committed, I'll give them that.",
                   "After hours. Either dedicated or procrastinating.",
                   "Still at it. Interesting."].randomElement()!
                : ["Evening session. Respect.",
                   "After hours, huh?",
                   "Winding down or ramping up?"].randomElement()!
        default:
            return isCritic
                ? ["Late night coding. The bugs come out at night.",
                   "They should be sleeping. But here we are.",
                   "Night owl. The code quality tends to match the hour."].randomElement()!
                : ["Late night. Let's make it count.",
                   "Night owl mode activated.",
                   "Shouldn't you be sleeping?"].randomElement()!
        }
    }

    // MARK: - State (sandbox-safe: Application Support only)

    private static func minutesSinceLastLaunch() -> Int? {
        guard let data = try? Data(contentsOf: stateFile),
              let str = String(data: data, encoding: .utf8),
              let ts = TimeInterval(str) else { return nil }
        let elapsed = Date().timeIntervalSince1970 - ts
        return max(0, Int(elapsed / 60))
    }

    private static func recordLaunch() {
        let ts = String(Date().timeIntervalSince1970)
        try? ts.write(to: stateFile, atomically: true, encoding: .utf8)
    }
}
