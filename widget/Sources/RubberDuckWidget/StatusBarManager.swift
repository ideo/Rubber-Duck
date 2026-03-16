// Status Bar Manager — NSStatusItem menu bar icon with native NSMenu.
//
// Replaces the flaky SwiftUI context menu for settings (voice picker, mode, etc.)
// NSMenu submenus work reliably — no disappearing on hover.
// Menu rebuilds on every open via NSMenuDelegate so state is always fresh.

import AppKit
import ServiceManagement

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
        if let icon = Self.menuBarIcon() {
            statusItem?.button?.image = icon
            statusItem?.button?.title = ""
        } else {
            statusItem?.button?.title = "🦆"  // fallback
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    /// Load the duck silhouette SVG from the resource bundle as a menu bar template image.
    private static func menuBarIcon() -> NSImage? {
        guard let url = Resources.bundle.url(forResource: "duck-symbol", withExtension: "svg"),
              let svgImage = NSImage(contentsOf: url) else {
            return nil
        }
        // SVG is 13×12 (wider than tall). Scale to 18pt height, preserve aspect ratio.
        let height: CGFloat = 18
        let aspectRatio: CGFloat = 13.0 / 12.0
        let width = height * aspectRatio
        let size = NSSize(width: width, height: height)
        let resized = NSImage(size: size, flipped: false) { rect in
            svgImage.draw(in: rect)
            return true
        }
        resized.isTemplate = true  // adapts to light/dark menu bar
        return resized
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            self.rebuildMenu(menu)
        }
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // --- Session launcher ---
        let claudeSession = NSMenuItem(title: "Launch Claude Code", action: #selector(startClaudeSession), keyEquivalent: "")
        claudeSession.target = self
        claudeSession.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Terminal")
        menu.addItem(claudeSession)
        menu.addItem(.separator())

        // --- Mode submenu ---
        let modeLabel = coordinator.mode == .critic ? "Critic" : "Relay"
        let modeItem = NSMenuItem(title: "Mode: \(modeLabel)", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()

        let criticItem = NSMenuItem(title: "Critic", action: #selector(setModeCritic), keyEquivalent: "")
        criticItem.target = self
        criticItem.state = coordinator.mode == .critic ? .on : .off
        criticItem.image = NSImage(systemSymbolName: "eyeglasses", accessibilityDescription: "Critic mode")
        criticItem.subtitle = "Inner monologue and alerts"
        modeMenu.addItem(criticItem)

        let relayItem = NSMenuItem(title: "Relay", action: #selector(setModeRelay), keyEquivalent: "")
        relayItem.target = self
        relayItem.state = coordinator.mode == .relay ? .on : .off
        relayItem.image = NSImage(systemSymbolName: "phone.fill", accessibilityDescription: "Relay mode")
        relayItem.subtitle = "Walkie talkie with Claude"
        modeMenu.addItem(relayItem)

        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        // --- Intelligence submenu ---
        let providerLabel: String = {
            switch DuckConfig.evalProvider {
            case .foundation: return "Foundation"
            case .anthropic: return "Haiku"
            case .gemini: return "Gemini"
            }
        }()
        let intelligenceItem = NSMenuItem(title: "Intelligence: \(providerLabel)", action: nil, keyEquivalent: "")
        let intelligenceMenu = NSMenu()

        if duckServer.foundationModelsAvailable {
            let foundationItem = NSMenuItem(title: "Foundation", action: #selector(setProviderFoundation), keyEquivalent: "")
            foundationItem.target = self
            foundationItem.state = DuckConfig.evalProvider == .foundation ? .on : .off
            foundationItem.image = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: "Apple")
            foundationItem.subtitle = "Free on-device LLM"
            intelligenceMenu.addItem(foundationItem)
        }

        let anthropicItem = NSMenuItem(title: "Haiku", action: #selector(setProviderAnthropic), keyEquivalent: "")
        anthropicItem.target = self
        anthropicItem.state = DuckConfig.evalProvider == .anthropic ? .on : .off
        anthropicItem.image = NSImage(systemSymbolName: "asterisk", accessibilityDescription: "Anthropic")
        anthropicItem.subtitle = "Requires Claude API key"
        intelligenceMenu.addItem(anthropicItem)

        let geminiItem = NSMenuItem(title: "Gemini", action: #selector(setProviderGemini), keyEquivalent: "")
        geminiItem.target = self
        geminiItem.state = DuckConfig.evalProvider == .gemini ? .on : .off
        geminiItem.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Google")
        geminiItem.subtitle = "Requires Gemini API key"
        intelligenceMenu.addItem(geminiItem)

        let hasAnyKey = !DuckConfig.anthropicAPIKey.isEmpty || !DuckConfig.geminiAPIKey.isEmpty
        if hasAnyKey {
            intelligenceMenu.addItem(.separator())
            let removeKeyItem = NSMenuItem(title: "Delete API Key(s)", action: #selector(removeAPIKey), keyEquivalent: "")
            removeKeyItem.target = self
            removeKeyItem.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Remove")
            intelligenceMenu.addItem(removeKeyItem)
        }

        intelligenceItem.submenu = intelligenceMenu
        menu.addItem(intelligenceItem)

        // --- Voice submenu ---
        let isWildcard = speechService.isWildcardMode
        let voiceLabel = isWildcard ? "Wildcard" : (DuckVoices.all.first { $0.sayName == speechService.ttsVoice }?.label ?? speechService.ttsVoice)
        let voiceItem = NSMenuItem(title: "Voice: \(voiceLabel)", action: nil, keyEquivalent: "")
        let voiceMenu = NSMenu()

        let wildcardItem = NSMenuItem(title: "Wildcard", action: #selector(selectWildcard), keyEquivalent: "")
        wildcardItem.target = self
        wildcardItem.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle voices")
        wildcardItem.state = isWildcard ? .on : .off
        voiceMenu.addItem(wildcardItem)
        voiceMenu.addItem(.separator())

        addVoiceItems(to: voiceMenu, voices: DuckVoices.main)
        voiceMenu.addItem(.separator())
        addVoiceItems(to: voiceMenu, voices: DuckVoices.classic)
        voiceMenu.addItem(.separator())
        addVoiceItems(to: voiceMenu, voices: DuckVoices.british)
        voiceMenu.addItem(.separator())
        addVoiceItems(to: voiceMenu, voices: DuckVoices.specialFX)
        voiceItem.submenu = voiceMenu
        menu.addItem(voiceItem)

        // --- Mic submenu ---
        let micLabel = speechService.listenMode.label
        let micItem = NSMenuItem(title: "Mic: \(micLabel)", action: nil, keyEquivalent: "")
        let micMenu = NSMenu()

        let listenModeIcons: [ListenMode: String] = [
            .off: "microphone.slash.fill",
            .permissionsOnly: "microphone.badge.xmark",
            .active: "microphone.fill",
        ]
        for mode in ListenMode.allCases {
            let listenItem = NSMenuItem(title: mode.label, action: #selector(setListenMode(_:)), keyEquivalent: "")
            listenItem.target = self
            listenItem.tag = mode.rawValue
            listenItem.state = speechService.listenMode == mode ? .on : .off
            if let iconName = listenModeIcons[mode] {
                listenItem.image = NSImage(systemSymbolName: iconName, accessibilityDescription: mode.label)
            }
            if mode == .active {
                listenItem.subtitle = "Use wake word \"Ducky\""
            }
            micMenu.addItem(listenItem)
        }

        // Mic device info at bottom of submenu
        let micName = speechService.selectedMicName.isEmpty ? "None" : speechService.selectedMicName
        micMenu.addItem(.separator())
        let micDeviceItem = NSMenuItem(title: micName, action: nil, keyEquivalent: "")
        micDeviceItem.isEnabled = false
        micMenu.addItem(micDeviceItem)

        micItem.submenu = micMenu
        menu.addItem(micItem)

        // --- Launch at Login (settings group with other prefs above) ---
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // --- Status ---
        let deviceLabel: String
        if serialManager.isConnected {
            let board = serialManager.serialTransport.connectedBoard ?? "Unknown"
            deviceLabel = "\(board) · \(serialManager.portName)"
        } else {
            deviceLabel = "No hardware connected"
        }
        menu.addItem(disabledItem(deviceLabel))

        if duckServer.pluginConnected {
            menu.addItem(disabledItem("Plugin connected"))
        }

        menu.addItem(.separator())

        // --- Setup ---
        if duckServer.pluginConnected {
            menu.addItem(item("Update Claude Plugin", action: #selector(installPlugin)))
        } else {
            menu.addItem(item("Install Claude Plugin", action: #selector(installPlugin)))
        }

        // --- Experimental ---
        let experimentalItem = NSMenuItem(title: "Experimental", action: nil, keyEquivalent: "")
        let experimentalMenu = NSMenu()

        let geminiInstall = NSMenuItem(title: "Install Gemini Extension", action: #selector(installGeminiExtension), keyEquivalent: "")
        geminiInstall.target = self
        geminiInstall.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Gemini")
        geminiInstall.subtitle = "Experimental — eval scoring and alerts only"
        experimentalMenu.addItem(geminiInstall)

        let geminiLaunch = NSMenuItem(title: "Launch Gemini CLI", action: #selector(startGeminiSession), keyEquivalent: "")
        geminiLaunch.target = self
        geminiLaunch.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Terminal")
        geminiLaunch.subtitle = "Experimental — comments and notifications only"
        experimentalMenu.addItem(geminiLaunch)

        experimentalItem.submenu = experimentalMenu
        menu.addItem(experimentalItem)

        menu.addItem(.separator())

        // --- Turn On/Off ---
        if AppDelegate.isDuckActive {
            let offItem = NSMenuItem(title: "Turn Off Duck-Duck-Duck", action: #selector(turnOffDuck), keyEquivalent: "")
            offItem.target = self
            if let icon = svgMenuIcon("no-duck-symbol") {
                offItem.image = icon
            }
            menu.addItem(offItem)
        } else {
            let onItem = NSMenuItem(title: "Turn On Duck-Duck-Duck", action: #selector(turnOnDuck), keyEquivalent: "")
            onItem.target = self
            if let icon = svgMenuIcon("duck-symbol") {
                onItem.image = icon
            }
            menu.addItem(onItem)
        }

        let quitItem = NSMenuItem(title: "Quit Duck-Duck-Duck", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark.square.fill", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
    }

    // MARK: - Voice Submenu

    private func addVoiceItems(to menu: NSMenu, voices: [DuckVoice]) {
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
        CLISession.launch()
    }

    @objc private func startGeminiSession() {
        CLISession.launchPlain("gemini")
    }

    @objc private func installGeminiExtension() {
        GeminiExtensionInstaller.install()
    }

    @objc private func installPlugin() {
        PluginInstaller.install()
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

    @objc private func setProviderFoundation() {
        DuckConfig.evalProvider = .foundation
    }

    @objc private func setProviderAnthropic() {
        guard DuckConfig.ensureAPIKey() else { return }
        DuckConfig.evalProvider = .anthropic
    }

    @objc private func setProviderGemini() {
        guard DuckConfig.ensureGeminiAPIKey() else { return }
        DuckConfig.evalProvider = .gemini
    }

    @objc private func removeAPIKey() {
        DuckConfig.removeAPIKey()
        DuckConfig.removeGeminiAPIKey()
        DuckConfig.evalProvider = .foundation
    }

    @objc private func selectWildcard() {
        speechService.ttsVoice = DuckVoices.wildcardSayName
        // Preview in Superstar (the default wildcard voice)
        speechService.setVoiceTransient(DuckVoices.wildcardDefault.sayName)
        speechService.speak("Wildcard mode.", skipChirpWait: true)
    }

    @objc private func selectVoice(_ sender: NSMenuItem) {
        guard let sayName = sender.representedObject as? String else { return }
        speechService.ttsVoice = sayName
        let label = DuckVoices.all.first { $0.sayName == sayName }?.label ?? sayName
        speechService.speak("Hi, I'm \(label).", skipChirpWait: true)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                print("[app] Unregistered Launch at Login")
            } else {
                try service.register()
                print("[app] Registered Launch at Login")
            }
        } catch {
            print("[app] Launch at Login toggle failed: \(error)")
        }
    }

    @objc private func turnOnDuck() {
        AppDelegate.turnOn()
    }

    @objc private func turnOffDuck() {
        AppDelegate.turnOff()
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

    /// Load an SVG from the resource bundle as a 16pt menu item icon.
    private func svgMenuIcon(_ name: String) -> NSImage? {
        guard let url = Resources.bundle.url(forResource: name, withExtension: "svg"),
              let svg = NSImage(contentsOf: url) else { return nil }
        let size = NSSize(width: 16, height: 16)
        let resized = NSImage(size: size, flipped: false) { rect in
            svg.draw(in: rect)
            return true
        }
        resized.isTemplate = true
        return resized
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

// MARK: - Plugin Installer
//
// Two modes:
// - Unsandboxed (dev): shells out to `claude` CLI directly for automatic install
// - Sandboxed (App Store): copies command to clipboard, opens Terminal for user to paste

enum PluginInstaller {
    private static let installCommand = "claude plugin marketplace add ideo/Rubber-Duck && claude plugin install duck-duck-duck"

    /// Install the plugin. Tries automatic install first, falls back to clipboard if sandboxed.
    static func install() {
        // Try automatic install via CLI (works in dev, fails in sandbox)
        if let claude = findClaude() {
            automaticInstall(claude: claude)
        } else {
            Task { @MainActor in
                clipboardInstall()
            }
        }
    }

    // MARK: - Automatic install (unsandboxed)

    private static func findClaude() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/bin/claude",
            "/usr/local/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Fall back to `which claude`
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["which", "claude"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && proc.terminationStatus == 0 {
                return path
            }
        } catch {}
        return nil
    }

    private static func run(_ claudePath: String, args: [String]) -> (Bool, String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: claudePath)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (proc.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private static func automaticInstall(claude: String) {
        print("[plugin] Found claude at \(claude)")
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Remove old install (ignore failures — may not exist)
            print("[plugin] Cleaning previous install...")
            _ = run(claude, args: ["plugin", "uninstall", "duck-duck-duck"])
            _ = run(claude, args: ["plugin", "marketplace", "remove", "duck-duck-duck-marketplace"])

            // 2. Add marketplace (fresh pull from GitHub)
            print("[plugin] Adding marketplace...")
            let (mpOk, mpOut) = run(claude, args: ["plugin", "marketplace", "add", "ideo/Rubber-Duck"])
            print("[plugin] Marketplace add: ok=\(mpOk) output=\(mpOut)")
            if !mpOk {
                Task { @MainActor in
                    showResult(success: false, detail: "Marketplace add failed:\n\(mpOut)")
                }
                return
            }

            // 3. Install plugin
            print("[plugin] Installing plugin...")
            let (installOk, installOut) = run(claude, args: ["plugin", "install", "duck-duck-duck"])
            print("[plugin] Plugin install: ok=\(installOk) output=\(installOut)")
            Task { @MainActor in
                if installOk {
                    showResult(success: true, detail: "Start a new Claude Code session to activate the hooks.")
                } else {
                    showResult(success: false, detail: "Plugin install failed:\n\(installOut)")
                }
            }
        }
    }

    // MARK: - Clipboard install (sandboxed fallback)

    @MainActor
    private static func clipboardInstall() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Install Claude Plugin"
        alert.informativeText = "Paste the following command in Terminal:\n\n\(installCommand)\n\nIt has been copied to your clipboard."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "Copy Only")
        alert.addButton(withTitle: "Cancel")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    @MainActor
    private static func showResult(success: Bool, detail: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = success ? "Plugin Installed" : "Install Failed"
        alert.informativeText = detail
        alert.alertStyle = success ? .informational : .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Gemini Extension Installer

enum GeminiExtensionInstaller {
    private static let installCommand = "gemini extensions install ideo/Rubber-Duck"

    static func install() {
        if let gemini = findGemini() {
            automaticInstall(gemini: gemini)
        } else {
            Task { @MainActor in
                clipboardInstall()
            }
        }
    }

    private static func findGemini() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["which", "gemini"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && proc.terminationStatus == 0 {
                return path
            }
        } catch {}
        return nil
    }

    private static func automaticInstall(gemini: String) {
        print("[gemini-ext] Found gemini at \(gemini)")
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: gemini)
            proc.arguments = ["extensions", "install", "ideo/Rubber-Duck"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let ok = proc.terminationStatus == 0
                print("[gemini-ext] Install: ok=\(ok) output=\(output)")
                Task { @MainActor in
                    showResult(success: ok, detail: ok
                        ? "Experimental — Gemini CLI hooks provide eval scoring and permission notifications, but cannot relay decisions back. You'll need to approve permissions manually in the terminal.\n\nStart a new Gemini CLI session to activate."
                        : "Extension install failed:\n\(output)")
                }
            } catch {
                Task { @MainActor in
                    showResult(success: false, detail: error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private static func clipboardInstall() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Install Gemini Extension"
        alert.informativeText = "Experimental — Gemini CLI hooks provide eval scoring and permission notifications, but cannot relay decisions back. Approve permissions manually in the terminal.\n\nPaste the following command in Terminal:\n\n\(installCommand)\n\nIt has been copied to your clipboard."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "Copy Only")
        alert.addButton(withTitle: "Cancel")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    @MainActor
    private static func showResult(success: Bool, detail: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = success ? "Extension Installed" : "Install Failed"
        alert.informativeText = detail
        alert.alertStyle = success ? .informational : .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - CLI Session Launcher (shared between DuckView + StatusBarManager)

enum CLISession {
    /// Launch Claude Code in a tmux session (needed for voice relay + TmuxBridge).
    static func launch(_ tool: String = "claude") {
        let session = DuckConfig.tmuxSession
        let windowName = DuckConfig.tmuxWindow

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
            do script "cd \(repoRoot.path) && if ! tmux has-session -t \(session) 2>/dev/null; then tmux new-session -d -s \(session) -n \(windowName) '\(tool)'; else tmux kill-window -t \(session):\(windowName) 2>/dev/null; tmux new-window -t \(session) -n \(windowName) '\(tool)'; fi && tmux attach -t \(session):\(windowName)"
        end tell
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            print("[app] Launched \(tool) tmux session in \(session):\(windowName)")
        } catch {
            print("[app] Failed to launch \(tool) session: \(error)")
        }
    }

    /// Launch a tool in a plain Terminal window (no tmux).
    static func launchPlain(_ tool: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(tool)"
        end tell
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            print("[app] Launched \(tool) in Terminal")
        } catch {
            print("[app] Failed to launch \(tool): \(error)")
        }
    }
}
