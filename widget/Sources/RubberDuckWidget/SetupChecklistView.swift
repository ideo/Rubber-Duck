// Duck Duck Duck — Setup Checklist
//
// Non-blocking window shown when Claude or the plugin isn't installed.
// Same pattern as HelpView — a regular SwiftUI Window, not a modal.

import SwiftUI

struct SetupChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    private var hasClaude: Bool {
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
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let pluginDir = "\(home)/.claude/plugins/cache/duck-duck-duck-marketplace/duck-duck-duck"
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: pluginDir, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return (try? FileManager.default.contentsOfDirectory(atPath: pluginDir))?.isEmpty == false
    }

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

            Spacer()

            HStack {
                Spacer()
                Button(hasClaude && hasPlugin ? "Done" : "Later") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: 340)
        .onAppear {
            if hasClaude && hasPlugin {
                PluginInstaller.onSpeak?("You're all set! Everything's installed.")
            } else if hasClaude {
                PluginInstaller.onSpeak?("Almost there! Just need the plugin.")
            } else {
                PluginInstaller.onSpeak?("Let's get you set up.")
            }
        }
    }
}
