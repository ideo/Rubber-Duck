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
                        Text("Your judgmental coding companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // --- Core experience ---

                section("What is this thing?", """
                A rubber duck that actually talks back. It watches your Claude Code \
                sessions, scores every prompt you write and every response Claude gives, \
                then tells you what it thinks — out loud.

                It's opinionated. It's sometimes wrong. It's always honest.
                """)

                section("Getting Started", """
                1. Launch the app — the duck lives in your menu bar (🦆)
                2. Click **Show Duck** to summon the floating widget
                3. Click **Install Claude Plugin** to connect to Claude Code
                4. Open Claude Code in any repo — the duck is watching

                That's it. No config files. No API keys. Eval runs on-device for free.
                """)

                section("Modes", """
                **Companion Mode** — The duck watches and reacts. It scores your prompts \
                and Claude's responses, speaks gut reactions, and helps with notifications. \
                This is the default and works everywhere, including the App Store.

                **Relay Mode** — The duck becomes a voice interface. Say "ducky" \
                followed by a command and it gets injected straight into Claude Code. \
                Say "yes" or "no" to approve permissions hands-free. \
                Requires tmux — see Experimental Features below.
                """)

                section("How Scoring Works", """
                Every prompt and response is scored on five dimensions:

                **Creativity** — Novel and surprising, or boring and obvious?
                **Soundness** — Technically solid, or held together with duct tape?
                **Ambition** — Swinging for the fences, or barely a bunt?
                **Elegance** — Clean and clear, or a war crime against readability?
                **Risk** — Could go sideways, or playing it safe?

                Scores range from -1.0 to +1.0. The duck's face, voice, and body \
                language all shift based on these scores. You'll know when it disapproves.
                """)

                section("The Menu Bar", """
                Everything lives under the 🦆 icon:

                **Intelligence** — Pick your eval brain. Foundation Models is free and \
                private (runs entirely on-device). Haiku and Gemini are sharper but \
                need API keys.

                **Voice** — Off, Permissions Only (duck asks yes/no on tool use), \
                or Wake Word (say "ducky" to talk to Claude).

                **Show / Hide Duck** — Toggle the floating widget without quitting.

                **Launch at Login** — Because you never want to code alone.
                """)

                section("Tips", """
                • The duck uses a voice called **Boing**. This is intentional.
                • Wildcard voice mode lets AI pick from 11 voices per reaction. Chaotic.
                • Permission prompts are summarized ("Run git. Allow?") not raw tool names.
                • If eval feels slow, switch to Foundation Models. It's free, private, and instant.
                • Right-click the duck widget for quick settings.
                """)

                Divider()

                // --- Experimental ---

                section("Experimental Features", """
                These features live under the Experimental menu. They work, but they \
                push beyond what the App Store sandbox allows.

                **Relay Mode** — Voice commands piped into Claude Code via tmux. \
                Requires `brew install tmux` and launching Claude from the duck's menu. \
                Not available in the App Store build.

                **Gemini CLI** — The duck can watch Gemini CLI sessions too. \
                Comments and scoring work, but permission relay doesn't — you'll \
                need to approve those yourself in the terminal.

                **Dashboard** — Open **localhost:3333** in a browser for live eval \
                charts updating in real time via WebSocket.
                """)

                section("Hardware", """
                The duck works perfectly as software. But if you want a physical duck \
                that tilts, chirps, and judges you with actual servos:

                **Get a robot from IDEO** — reach out and we'll hook you up.

                **Build your own** — the firmware, schematics, and bill of materials \
                are all on GitHub. Teensy 4.0 or ESP32, a servo, a speaker, and a \
                weekend of soldering. Plug in via USB and the widget picks it up \
                automatically. Hot-unplug works too — yank the cable and audio \
                falls back to your Mac.
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
