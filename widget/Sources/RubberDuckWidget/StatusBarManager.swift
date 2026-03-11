// Status Bar Manager — NSStatusItem menu bar icon with native NSMenu.
//
// Replaces the flaky SwiftUI context menu for settings (voice picker, mode, etc.)
// NSMenu submenus work reliably — no disappearing on hover.
// Menu rebuilds on every open via NSMenuDelegate so state is always fresh.

import AppKit

@MainActor
final class StatusBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let speechService: SpeechService
    private let coordinator: DuckCoordinator
    private let serialManager: SerialManager
    private let duckServer: DuckServer

    init(speechService: SpeechService, coordinator: DuckCoordinator,
         serialManager: SerialManager, duckServer: DuckServer) {
        self.speechService = speechService
        self.coordinator = coordinator
        self.serialManager = serialManager
        self.duckServer = duckServer
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🦆"
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            self.rebuildMenu(menu)
        }
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // Start Claude Session
        menu.addItem(item("Start Claude Session", action: #selector(startClaudeSession)))
        menu.addItem(.separator())

        // Listen mode — 3 radio items
        for mode in ListenMode.allCases {
            let modeItem = NSMenuItem(title: mode.label, action: #selector(setListenMode(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.tag = mode.rawValue
            modeItem.state = speechService.listenMode == mode ? .on : .off
            menu.addItem(modeItem)
        }

        menu.addItem(.separator())

        // Duck mode — 2 radio items
        let criticItem = item("Critic (Inner Monologue)", action: #selector(setModeCritic))
        criticItem.state = coordinator.mode == .critic ? .on : .off
        menu.addItem(criticItem)

        let relayItem = item("Relay", action: #selector(setModeRelay))
        relayItem.state = coordinator.mode == .relay ? .on : .off
        menu.addItem(relayItem)

        menu.addItem(.separator())

        // Voice submenu
        let voiceLabel = DuckVoices.all.first { $0.sayName == speechService.ttsVoice }?.label ?? speechService.ttsVoice
        let voiceItem = NSMenuItem(title: "Voice: \(voiceLabel)", action: nil, keyEquivalent: "")
        let voiceMenu = NSMenu()
        addVoiceSection(to: voiceMenu, title: "Novelty", voices: DuckVoices.novelty)
        addVoiceSection(to: voiceMenu, title: "Siri", voices: DuckVoices.siri)
        addVoiceSection(to: voiceMenu, title: "Classic", voices: DuckVoices.classic)
        voiceItem.submenu = voiceMenu
        menu.addItem(voiceItem)

        menu.addItem(.separator())

        // Status labels (disabled)
        let micName = speechService.selectedMicName.isEmpty ? "None" : speechService.selectedMicName
        menu.addItem(disabledItem("Mic: \(micName)"))

        let teensyLabel = serialManager.isConnected ? "Teensy: \(serialManager.portName)" : "Teensy: Disconnected"
        menu.addItem(disabledItem(teensyLabel))

        let serverLabel = duckServer.isRunning ? "Server: Running" : "Server: Stopped"
        menu.addItem(disabledItem(serverLabel))

        menu.addItem(.separator())
        menu.addItem(item("Quit Duck", action: #selector(quitApp)))
    }

    // MARK: - Voice Submenu

    private func addVoiceSection(to menu: NSMenu, title: String, voices: [DuckVoice]) {
        // Section header (disabled, bold-ish)
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        header.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        menu.addItem(header)

        for voice in voices {
            let voiceItem = NSMenuItem(title: voice.label, action: #selector(selectVoice(_:)), keyEquivalent: "")
            voiceItem.target = self
            voiceItem.representedObject = voice.sayName
            if speechService.ttsVoice == voice.sayName {
                voiceItem.state = .on
            }
            menu.addItem(voiceItem)
        }
    }

    // MARK: - Actions

    @objc private func startClaudeSession() {
        ClaudeSession.launch()
    }

    @objc private func setListenMode(_ sender: NSMenuItem) {
        guard let mode = ListenMode(rawValue: sender.tag) else { return }
        speechService.listenMode = mode
    }

    @objc private func setModeCritic() {
        coordinator.setMode(.critic)
    }

    @objc private func setModeRelay() {
        coordinator.setMode(.relay)
    }

    @objc private func selectVoice(_ sender: NSMenuItem) {
        guard let sayName = sender.representedObject as? String else { return }
        speechService.ttsVoice = sayName
        let label = DuckVoices.all.first { $0.sayName == sayName }?.label ?? sayName
        speechService.speak("Hi, I'm \(label).")
    }

    @objc private func quitApp() {
        duckServer.stop()
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

// MARK: - Claude Session Launcher (shared between DuckView + StatusBarManager)

enum ClaudeSession {
    static func launch() {
        let session = DuckConfig.tmuxSession
        let window = DuckConfig.tmuxWindow

        // Walk up from binary to find repo root (look for Package.swift as marker)
        var repoRoot = Bundle.main.bundleURL
        for _ in 0..<10 {
            repoRoot = repoRoot.deletingLastPathComponent()
            let marker = repoRoot.appendingPathComponent("widget/Package.swift")
            if FileManager.default.fileExists(atPath: marker.path) {
                break
            }
        }

        let script = """
        tell application "Terminal"
            activate
            do script "cd \(repoRoot.path) && if ! tmux has-session -t \(session) 2>/dev/null; then tmux new-session -d -s \(session) -n \(window) 'claude'; fi && tmux set-option -t \(session) -w allow-rename off 2>/dev/null && tmux rename-window -t \(session) \(window) 2>/dev/null && tmux attach -t \(session)"
        end tell
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            print("[app] Launched Claude terminal session")
        } catch {
            print("[app] Failed to launch Claude session: \(error)")
        }
    }
}
