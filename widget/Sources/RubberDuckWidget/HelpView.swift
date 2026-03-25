// Duck Duck Duck — Help Window
//
// Because even ducks need a manual sometimes.

import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Text("🦆")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("Duck Duck Duck")
                            .font(.largeTitle.bold())
                        Text("He has opinions. He's not sorry about them.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // --- Core experience ---

                section("What is this thing?", """
                A rubber duck that actually talks back. It watches your Claude Code \
                sessions, scores every prompt and every response, then tells you \
                what it thinks — out loud, whether you asked or not.

                It's opinionated. It's sometimes wrong. It's always honest. \
                Just don't ask him about Ahab.
                """)

                section("Getting Started", """
                1. Launch the app — the duck appears in your menu bar (🦆)
                2. Click **Show Duck** to summon him
                3. Click **Install Claude Plugin** to connect to Claude Code
                4. Open Claude Code in any repo — he's already watching

                No config files. No API keys. No signing up for anything \
                except to duck around. Eval runs on-device for free.
                """)

                section("Modes", """
                **Permissions Only** — Silent watchdog. He only speaks up when Claude \
                needs permission to do something. Listens for "yes" or "no" — that's it. \
                The strong, silent type.

                **Companion** — The full experience. Opinions, permissions, voice control. \
                Listens for the wake word "ducky" so you can talk to him. \
                The ride-or-die supporter of your dreams, or a duck with nothing but \
                sharp wisecracks. Depends on the day.

                **Companion (No Mic)** — Same opinions, no listening. No microphone access \
                at all. For when you want to be judged but not heard.

                **Relay** — Say "ducky" followed by a command and it goes straight into \
                Claude Code. Hands-free coding. Requires tmux — see below.
                """)

                section("Microphone & Audio", """
                Yes, he can hear you. He uses your Mac's built-in mic to listen for \
                voice commands — all processed locally on your Mac. Nothing leaves the device.

                **What he listens for depends on the mode:**
                • Companion: the wake word "ducky", then your question or command
                • Relay: "ducky" followed by commands for Claude Code
                • Permissions Only: "yes" or "no" when Claude asks permission
                • No Mic: nothing. Mic is completely off.

                **Not hearing you?** System Settings → Privacy & Security → Microphone → \
                make sure Duck Duck Duck is enabled. Also check that your Mac's input \
                volume isn't muted.

                **Physical duck?** Audio routes through the Teensy hardware via USB. \
                Unplug the cable and it falls back to your Mac's mic and speakers.
                """)

                section("How Scoring Works", """
                Every prompt and response gets scored on five dimensions:

                **Creativity** — Novel and surprising, or boring and obvious?
                **Soundness** — Technically solid, or held together with duct tape?
                **Ambition** — Swinging for the fences, or barely a bunt?
                **Elegance** — Clean and clear, or a war crime against readability?
                **Risk** — Could go sideways, or playing it safe?

                Scores range from -1.0 to +1.0. His face, voice, and body language \
                all shift based on these scores. You'll know when he disapproves.
                """)

                section("The Menu Bar", """
                Everything lives under the 🦆 icon:

                **Intelligence** — Pick his brain. Foundation Models is free and private \
                (runs entirely on your Mac). Haiku and Gemini are sharper but need API keys.

                **Voice** — 15+ voices, Wildcard (AI picks per mood — chaotic), \
                or Silent (speech bubble only, for the library crowd).

                **Show / Hide Duck** — Toggle the floating widget without quitting.

                **Launch at Login** — Because you never want to code alone.
                """)

                section("Tips", """
                • His default voice is **Boing**. This is intentional.
                • Say "ducky" and he perks up. Say nothing after and he gets impatient.
                • Permission prompts are summarized ("Run git. Allow?") not raw tool names. \
                Your hands stay free.
                • If eval feels slow, switch to Foundation Models. Free, private, instant.
                • Right-click the duck for quick settings.
                • Ducks have weird hole-shaped ears. Now you know.

                **Plugin not working?** Make sure Claude is updated to **version 1.1.7714 \
                or newer**. Older versions had bugs with plugin hooks — the duck shows up \
                in the plugin list but doesn't actually fire. Update Claude, start a fresh \
                session, and he'll wake right up.
                """)

                Divider()

                // --- Experimental ---

                section("Experimental Features", """
                These push beyond what the App Store sandbox allows. Proceed with enthusiasm.

                **Relay Mode** — Voice commands piped into Claude Code via tmux. \
                Don't know what tmux is? That's okay. You can still have a duck. \
                Requires `brew install tmux` and launching Claude from the duck's menu.

                **Gemini CLI** — He can watch Gemini sessions too. Scoring works, \
                permission relay doesn't — you'll approve those yourself.

                **Dashboard** — Open **localhost:3333** in a browser for live eval \
                charts updating in real time via WebSocket. For the data nerds.
                """)

                section("Hardware", """
                He works perfectly as software. But if you want a physical duck \
                that tilts, chirps, and judges you with actual servos — real hardware, \
                made from real computer stuff:

                **Get one from IDEO** — reach out and we'll hook you up.

                **Build your own** — firmware, schematics, and BOM are on GitHub. \
                Teensy 4.0 or ESP32, a micro servo, an I2S speaker, and a weekend. \
                One USB-C cable carries power, serial, and bidirectional audio. \
                Plug in and say "well hello" to your new best friend. \
                Yank the cable and audio falls back to your Mac. He's resilient like that.
                """)

                Divider()

                // Footer
                HStack {
                    Text("Built at IDEO")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Link("GitHub", destination: URL(string: "https://github.com/ideo/Rubber-Duck")!)
                        .font(.caption)
                }
                .padding(.bottom, 8)
            }
            .padding(24)
        }
        .frame(width: 520, height: 640)
    }

    private func section(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(LocalizedStringKey(content))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
