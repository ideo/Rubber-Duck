// Duck Duck Duck — Setup Checklist
//
// Non-blocking window shown when Claude or the plugin isn't installed,
// or when M1/M2 hardware is detected with on-device scoring.
// Same pattern as HelpView — a regular SwiftUI Window, not a modal.

import SwiftUI

struct SetupChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    // Toggled to force SwiftUI to re-evaluate computed properties
    @State private var refreshTick = false
    // Tracks if eval was slow when the view appeared (for detecting the transition to fast)
    @State private var wasSlowOnAppear = false

    private var hasClaude: Bool {
        _ = refreshTick // depend on tick so SwiftUI re-evaluates
        let hasCLI = PluginInstaller.findClaude() != nil
        let hasDesktop: Bool = {
            if let urls = LSCopyApplicationURLsForBundleIdentifier(
                "com.anthropic.claudefordesktop" as CFString, nil
            )?.takeRetainedValue() as? [URL] {
                return !urls.isEmpty
            }
            return false
        }()
        return hasCLI || hasDesktop
    }

    private var hasPlugin: Bool {
        _ = refreshTick
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pluginDir = "\(home)/.claude/plugins/cache/duck-duck-duck-marketplace/duck-duck-duck"
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: pluginDir, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return (try? FileManager.default.contentsOfDirectory(atPath: pluginDir))?.isEmpty == false
    }

    /// True when eval performance is optimal (M3+ or using a cloud provider).
    private var hasOptimalEval: Bool {
        _ = refreshTick
        return !DuckConfig.isOlderAppleSilicon || DuckConfig.evalProvider != .foundation
    }

    /// Whether to show the performance step (only on M1/M2).
    private var showPerformanceStep: Bool {
        DuckConfig.isOlderAppleSilicon
    }

    /// Whether the user already has an API key for a cloud provider but hasn't switched.
    private var hasExistingKey: Bool {
        !DuckConfig.anthropicAPIKey.isEmpty || !DuckConfig.geminiAPIKey.isEmpty
    }

    /// Human-readable name of the provider they already have a key for.
    private var existingKeyProvider: String {
        if !DuckConfig.anthropicAPIKey.isEmpty { return "a Claude Haiku key" }
        if !DuckConfig.geminiAPIKey.isEmpty { return "a Gemini key" }
        return ""
    }

    private var allDone: Bool {
        hasClaude && hasPlugin && (hasOptimalEval || !showPerformanceStep)
    }

    private static let speedQuips = [
        "Oh. OH. That's more like it.",
        "I feel faster already. Probably placebo. Nope, definitely faster.",
        "Finally. Do you know how long I've been buffering?",
        "Cloud brain activated. No more dial-up thoughts.",
        "Now my opinions arrive before you've finished regretting your choices.",
        "I went from carrier pigeon to fiber optic. You'll notice.",
        "So you DO care about my performance. I'm genuinely moved.",
        "That's the stuff. I can think in full sentences again.",
        "About time. I was starting to forget what I was mad about.",
        "Upgraded. My judgment is now instant and inescapable.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get Started with Duck Duck Duck")
                .font(.title2.bold())

            // Step 1
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hasClaude ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(hasClaude ? .green : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install Claude")
                        .font(.headline)
                    Text("Duck Duck Duck watches your Claude sessions and reacts. Install Claude Code (terminal) or Claude Desktop (app).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if !hasClaude {
                        HStack(spacing: 8) {
                            Button("Install Claude Code") {
                                StatusBarManager.installClaudeCLIAction()
                            }
                            Button("Download Claude Desktop") {
                                NSWorkspace.shared.open(URL(string: "https://claude.com/download")!)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Divider()

            // Step 2
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hasPlugin ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(hasPlugin ? .green : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install the Plugin")
                        .font(.headline)
                    Text("Connect your duck to Claude so it can watch your sessions.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if !hasPlugin {
                        Button("Install Plugin Now") {
                            PluginInstaller.install()
                        }
                        .padding(.top, 4)
                    } else {
                        Button("Update Plugin") {
                            PluginInstaller.install()
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Step 3 — only on M1/M2
            if showPerformanceStep {
                Divider()

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: hasOptimalEval ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(hasOptimalEval ? .green : .orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed up scoring")
                            .font(.headline)
                        if hasOptimalEval {
                            // Already using cloud — done
                            Text("Using \(DuckConfig.evalProvider == .anthropic ? "Claude Haiku" : "Gemini Flash") for scoring.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else if hasExistingKey {
                            // Has a key but still on Foundation — just need to switch
                            Text("On-device scoring is designed for M3+ and runs slowly on this Mac. You already have \(existingKeyProvider) — switch to it for instant reactions.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            SettingsLink {
                                Text("Open Preferences")
                            }
                            .padding(.top, 4)
                            Text("Switch providers in the Intelligence tab.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            // No key at all — guide them to get one
                            Text("On-device scoring is designed for M3+ and runs slowly on this Mac. Add a cloud API key for instant reactions.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Button("Get Free Gemini Key") {
                                    NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/apikey")!)
                                }
                                Button("Get Claude Haiku Key") {
                                    NSWorkspace.shared.open(URL(string: "https://console.anthropic.com/settings/keys")!)
                                }
                            }
                            .padding(.top, 4)
                            Text("Paste your key in Preferences → Intelligence after creating it.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button(allDone ? "Done" : "Later") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: showPerformanceStep ? 420 : 340)
        .onAppear {
            wasSlowOnAppear = showPerformanceStep && !hasOptimalEval
            if allDone {
                PluginInstaller.onSpeak?("You're all set! Everything's installed.")
            } else if hasClaude && hasPlugin && !hasOptimalEval {
                if hasExistingKey {
                    PluginInstaller.onSpeak?("One more thing. You already have an API key. Switch providers in Preferences for instant scoring.")
                } else {
                    PluginInstaller.onSpeak?("One more thing. Scoring will be slow on your Mac. I can show you how to speed it up.")
                }
            } else if hasClaude {
                PluginInstaller.onSpeak?("Almost there! Just need the plugin.")
            } else {
                PluginInstaller.onSpeak?("Let's get you set up.")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshTick.toggle()
            // Detect the moment eval goes from slow → fast
            if wasSlowOnAppear && hasOptimalEval {
                wasSlowOnAppear = false
                PluginInstaller.onSpeak?(Self.speedQuips.randomElement()!)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: PluginInstaller.pluginDidInstallNotification)) { _ in
            refreshTick.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let wasStillSlow = wasSlowOnAppear
            refreshTick.toggle()
            // Provider changed in Preferences → check if eval just went fast
            if wasStillSlow && hasOptimalEval {
                wasSlowOnAppear = false
                PluginInstaller.onSpeak?(Self.speedQuips.randomElement()!)
            }
        }
    }
}
