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
                1. Launch the app — the duck appears on your desktop and in the menu bar
                2. Click **Install Plugin** from the menu bar icon or the Setup menu
                3. Close and reopen Claude Code — he's already watching

                The plugin checks your Claude version automatically. If it's too old, \
                you'll be prompted to update.

                **Using Claude Desktop instead of CLI?** Export the plugin zip from \
                Setup → Export Plugin Zip, then upload it via Claude Desktop's plugin manager.

                No config files. No API keys required. Eval runs on-device for free.
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
                Claude Code. Hands-free coding. Requires tmux — see Experimental below.

                Switch modes from the right-click menu, menu bar icon, or \
                Preferences → Behavior tab.
                """)

                section("Microphone & Audio", """
                Yes, he can hear you. He uses your Mac's mic to listen for \
                voice commands — all processed locally on your Mac. Nothing leaves the device.

                **What he listens for depends on the mode:**
                • Companion: the wake word "ducky", then your question or command
                • Relay: "ducky" followed by commands for Claude Code
                • Permissions Only: "yes" or "no" when Claude asks permission
                • No Mic: nothing. Mic is completely off.

                **Microphone selection:** Open Preferences → Behavior → Microphone \
                to see which device is active and pick a different one. When a hardware \
                duck is connected, it switches automatically.

                **Not hearing you?** Check the menu bar icon — if it shows a warning \
                triangle, microphone or speech recognition permissions are missing. \
                Click the warning items in the menu for direct links to System Settings.

                **Hardware duck?** Audio routes through the device via USB. \
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

                If the cloud provider (Haiku or Gemini) fails, scoring falls back to \
                Apple Foundation Model automatically. You won't miss a beat.
                """)

                section("Menus", """
                **Menu bar icon (🦆)** — Quick access to Volume, Mode, Voice, \
                Intelligence, Launch Claude Code, Pause/Resume, and Quit. \
                Right-click the duck widget for the same menu.

                **Setup menu** (top menu bar) — Install Claude Code, Install/Update \
                Plugin, Export Plugin Zip, Launch at Login, Experimental features.

                **Help menu** — Get Started guide, Dashboard, and this manual.
                """)

                section("Preferences", """
                Open with **⌘,** or from the Duck Duck Duck menu.

                **Intelligence** — Pick the eval provider. Apple Foundation Model is free \
                and fully private (runs on your Mac). Claude Haiku and Gemini are sharper \
                but need API keys and send data to third-party servers.

                **Behavior** — Mode selection, voice picker, volume slider, and \
                microphone settings. See which mic is active, check permission status, \
                and pick a device if you have multiple.

                **About** — Credits and GitHub link.
                """)

                section("Stopping Speech", """
                Hover over the duck while it's speaking — wings slide up over the beak. \
                Tap to stop. He'll say a short quip and move on.

                Works for anything: eval reactions, help answers, even the bedtime story. \
                If he's mid-sentence about your code quality, one tap shuts him up.
                """)

                section("Tips", """
                • His default voice is **Boing**. This is intentional.
                • Say "ducky" and he perks up. Say nothing after and he gets impatient.
                • Permission prompts are summarized ("Run git. Allow?") not raw tool names. \
                Your hands stay free.
                • If eval feels slow, switch to Foundation Model. Free, private, instant.
                • Right-click the duck for quick settings.
                • Ducks have weird hole-shaped ears. Now you know.

                **Plugin not working?** Make sure Claude is updated to **version 1.1.7714 \
                or newer**. Older versions had bugs with plugin hooks — the duck shows up \
                in the plugin list but doesn't actually fire. Update Claude, start a fresh \
                session, and he'll wake right up.
                """)

                section("Privacy", """
                **Apple Foundation Model** — All scoring runs on your Mac. Your prompts, \
                Claude's responses, and all audio stay on the device. Nothing is sent anywhere.

                **Claude Haiku / Gemini** — Your prompts and Claude's responses are sent \
                to Anthropic or Google for scoring. Subject to their usage and privacy terms. \
                See links in Preferences → Intelligence when a cloud provider is selected.

                **Audio** — Microphone input and text-to-speech are always local. \
                Speech recognition uses Apple's on-device engine. No audio is ever \
                sent to any server.
                """)

                Divider()

                // --- Experimental ---

                section("Experimental Features", """
                These push beyond what the App Store sandbox allows. Proceed with enthusiasm.

                **Relay Mode** — Voice commands piped into Claude Code via tmux. \
                Don't know what tmux is? That's okay. You can still have a duck. \
                Requires `brew install tmux` and launching Claude from the duck's menu.

                **Gemini CLI** — He can watch Gemini sessions too. Scoring works, \
                permission relay doesn't — you'll approve those yourself. \
                Enable via Setup → Experimental.

                **Dashboard** — Open **localhost:3333** in a browser for live eval \
                charts updating in real time via WebSocket. For the data nerds.
                """)

                section("Hardware", """
                He works perfectly as software. But if you want a physical duck \
                that tilts, chirps, and judges you with actual servos — real hardware, \
                made from real computer stuff:

                **Get one from IDEO** — reach out and we'll hook you up.

                **Build your own** — firmware, schematics, and BOM are on GitHub. \
                Teensy 4.0 or ESP32-S3, a micro servo, an I2S speaker, and a weekend. \
                One USB-C cable carries power, serial, and bidirectional audio. \
                Plug in and the widget shows "Duck, Duck, Duck" as the audio device. \
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
