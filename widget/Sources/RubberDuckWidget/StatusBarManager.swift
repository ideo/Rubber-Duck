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

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // --- Volume slider ---
        menu.addItem(volumeSliderItem())

        // --- Pause / Resume ---
        if AppDelegate.isDuckActive {
            let pauseItem = NSMenuItem(title: "Pause Duck, Duck, Duck", action: #selector(turnOffDuck), keyEquivalent: "")
            pauseItem.target = self
            if let icon = svgMenuIcon("no-duck-symbol") {
                pauseItem.image = icon
            }
            menu.addItem(pauseItem)
        } else {
            let resumeItem = NSMenuItem(title: "Resume Duck, Duck, Duck", action: #selector(turnOnDuck), keyEquivalent: "")
            resumeItem.target = self
            if let icon = svgMenuIcon("duck-symbol") {
                resumeItem.image = icon
            }
            menu.addItem(resumeItem)
        }

        menu.addItem(.separator())

        // --- Mode submenu ---
        let currentMode = coordinator.mode
        let modeItem = NSMenuItem(title: currentMode.label, action: nil, keyEquivalent: "")
        modeItem.image = NSImage(systemSymbolName: currentMode.iconName, accessibilityDescription: currentMode.label)
        let modeMenu = NSMenu()

        let modeActions: [(DuckMode, Selector)] = [
            (.permissionsOnly, #selector(setModePermissions)),
            (.companion, #selector(setModeCompanion)),
            (.companionNoMic, #selector(setModeCompanionNoMic)),
            (.relay, #selector(setModeRelay)),
        ]
        for (mode, action) in modeActions {
            let item = NSMenuItem(title: mode.label, action: action, keyEquivalent: "")
            item.target = self
            item.state = currentMode == mode ? .on : .off
            item.image = NSImage(systemSymbolName: mode.iconName, accessibilityDescription: mode.label)
            item.subtitle = mode.subtitle
            modeMenu.addItem(item)
        }

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
        intelligenceItem.image = NSImage(systemSymbolName: "brain.fill", accessibilityDescription: "Intelligence")
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
        let isSilentVoice = speechService.isSilent
        let voiceLabel = isSilentVoice ? "Silent" : isWildcard ? "Wildcard" : (DuckVoices.all.first { $0.sayName == speechService.ttsVoice }?.label ?? speechService.ttsVoice)
        let voiceItem = NSMenuItem(title: "Voice: \(voiceLabel)", action: nil, keyEquivalent: "")
        voiceItem.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice")
        let voiceMenu = NSMenu()

        let isSilent = speechService.isSilent
        let silentItem = NSMenuItem(title: "Silent Voice", action: #selector(selectSilent), keyEquivalent: "")
        silentItem.target = self
        silentItem.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Speech bubble only")
        silentItem.subtitle = "Subtitles and quacks, no voice"
        silentItem.state = isSilent ? .on : .off
        voiceMenu.addItem(silentItem)

        let wildcardItem = NSMenuItem(title: "Wildcard", action: #selector(selectWildcard), keyEquivalent: "")
        wildcardItem.target = self
        wildcardItem.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle voices")
        wildcardItem.subtitle = "AI picks a voice to match the mood"
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

        menu.addItem(.separator())

        // --- Status ---
        let currentListenMode = speechService.listenMode

        // Hardware / mic device — Ducky first, then mic status below
        if serialManager.isConnected {
            let duckItem = disabledItem("Ducky connected")
            duckItem.image = NSImage(systemSymbolName: "duck.fill", accessibilityDescription: "Ducky")
            let micSubtext: String
            switch currentListenMode {
            case .active: micSubtext = "Listening for wake word \"Ducky\""
            case .permissionsOnly: micSubtext = "Listening for permissions"
            case .off: micSubtext = "Mic off"
            }
            duckItem.subtitle = micSubtext
            menu.addItem(duckItem)
        } else if currentListenMode != .off {
            let micName = speechService.selectedMicName.isEmpty ? "Default microphone" : speechService.selectedMicName
            let item = disabledItem(micName)
            item.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Microphone")
            let micSubtext: String
            switch currentListenMode {
            case .active: micSubtext = "Listening for wake word \"Ducky\""
            case .permissionsOnly: micSubtext = "Listening for permissions"
            case .off: micSubtext = ""
            }
            item.subtitle = micSubtext
            menu.addItem(item)
        }

        if duckServer.pluginConnected {
            menu.addItem(disabledItem("Plugin connected"))
        }

        menu.addItem(.separator())

        // --- Setup ---
        let claudeSession = NSMenuItem(title: "Launch Claude Code", action: #selector(startClaudeSession), keyEquivalent: "")
        claudeSession.target = self
        claudeSession.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Terminal")
        menu.addItem(claudeSession)

        let pluginTitle = duckServer.pluginConnected ? "Update Claude Plugin" : "Install Claude Plugin"
        let pluginItem = NSMenuItem(title: pluginTitle, action: #selector(installPlugin), keyEquivalent: "")
        pluginItem.target = self
        pluginItem.image = NSImage(systemSymbolName: "puzzlepiece.extension.fill", accessibilityDescription: "Plugin")
        menu.addItem(pluginItem)

        // --- Startup selector ---
        let isLoginEnabled = SMAppService.mainApp.status == .enabled
        let startupLabel = isLoginEnabled ? "Launch at Login" : "Manual"
        let startupIcon = isLoginEnabled ? "play.fill" : "hand.point.up.fill"
        let startupItem = NSMenuItem(title: startupLabel, action: nil, keyEquivalent: "")
        startupItem.image = NSImage(systemSymbolName: startupIcon, accessibilityDescription: startupLabel)
        let startupMenu = NSMenu()

        let loginOption = NSMenuItem(title: "Launch at Login", action: #selector(setLaunchAtLogin), keyEquivalent: "")
        loginOption.target = self
        loginOption.state = isLoginEnabled ? .on : .off
        loginOption.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Auto")
        startupMenu.addItem(loginOption)

        let manualOption = NSMenuItem(title: "Manual", action: #selector(setManualLaunch), keyEquivalent: "")
        manualOption.target = self
        manualOption.state = isLoginEnabled ? .off : .on
        manualOption.image = NSImage(systemSymbolName: "hand.point.up.fill", accessibilityDescription: "Manual")
        startupMenu.addItem(manualOption)

        startupItem.submenu = startupMenu
        menu.addItem(startupItem)

        // --- Experimental ---
        let experimentalItem = NSMenuItem(title: "Experimental", action: nil, keyEquivalent: "")
        experimentalItem.image = NSImage(systemSymbolName: "flask", accessibilityDescription: "Experimental")
        let experimentalMenu = NSMenu()

        let geminiInstall = NSMenuItem(title: "Install Gemini Extension", action: #selector(installGeminiExtension), keyEquivalent: "")
        geminiInstall.target = self
        geminiInstall.image = NSImage(systemSymbolName: "puzzlepiece.extension.fill", accessibilityDescription: "Extension")
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

        let quitItem = NSMenuItem(title: "Quit Duck, Duck, Duck", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark.square.fill", accessibilityDescription: "Quit")
        menu.addItem(quitItem)
    }

    // MARK: - Volume Slider

    /// Speaker SF Symbol name for a given volume level.
    private static func speakerIcon(for volume: Float) -> String {
        switch volume {
        case 0:              return "speaker.slash.fill"
        case ..<0.33:        return "speaker.wave.1.fill"
        case ..<0.66:        return "speaker.wave.2.fill"
        default:             return "speaker.wave.3.fill"
        }
    }

    /// Render speaker SF Symbol into a fixed-size bitmap to prevent vertical jitter.
    /// Different speaker symbols have slightly different intrinsic metrics even at the
    /// same point size — stamping them into a uniform canvas eliminates the shift.
    private static func speakerImage(for volume: Float) -> NSImage? {
        let name = speakerIcon(for: volume)
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "Volume")?
            .withSymbolConfiguration(config) else { return nil }

        // Fixed canvas — symbol drawn centered vertically, left-aligned
        let canvas = NSSize(width: 20, height: 18)
        let result = NSImage(size: canvas, flipped: false) { rect in
            let symbolSize = symbol.size
            let y = (canvas.height - symbolSize.height) / 2
            symbol.draw(in: NSRect(x: 0, y: y, width: symbolSize.width, height: symbolSize.height))
            return true
        }
        result.isTemplate = true  // Adapts to light/dark menu appearance
        return result
    }

    private static let volumeIconTag = 998
    private static let volumeLabelTag = 999

    private func volumeSliderItem() -> NSMenuItem {
        let item = NSMenuItem()

        // Container view: icon + slider + percentage label
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))

        let vol = DuckConfig.volume
        let icon = NSImageView(frame: NSRect(x: 14, y: 5, width: 20, height: 18))
        icon.image = Self.speakerImage(for: vol)
        icon.imageScaling = .scaleNone
        icon.imageAlignment = .alignCenter
        icon.contentTintColor = .labelColor
        icon.tag = Self.volumeIconTag
        container.addSubview(icon)

        let slider = NSSlider(frame: NSRect(x: 39, y: 5, width: 165, height: 20))
        slider.minValue = 0
        slider.maxValue = 1
        slider.floatValue = vol
        slider.isContinuous = true
        slider.trackFillColor = NSColor(red: 0.925, green: 0.725, blue: 0.278, alpha: 1.0)
        slider.target = self
        slider.action = #selector(volumeChanged(_:))
        container.addSubview(slider)

        let label = NSTextField(labelWithString: "\(Int(vol * 100))%")
        label.frame = NSRect(x: 208, y: 6, width: 36, height: 16)
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.tag = Self.volumeLabelTag
        container.addSubview(label)

        item.view = container
        return item
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        let vol = sender.floatValue
        DuckConfig.volume = vol

        if let container = sender.superview {
            // Update percentage label
            if let label = container.viewWithTag(Self.volumeLabelTag) as? NSTextField {
                label.stringValue = "\(Int(vol * 100))%"
            }
            // Update speaker icon to match volume level
            if let icon = container.viewWithTag(Self.volumeIconTag) as? NSImageView {
                icon.image = Self.speakerImage(for: vol)
            }
        }

        // Push volume to TTS engines + firmware
        speechService.setVolume(vol)
        serialManager.sendCommand(String(format: "VOL,%.2f", vol))
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

    @objc private func setModeCompanion() {
        coordinator.setMode(.companion)
    }

    @objc private func setModeCompanionNoMic() {
        coordinator.setMode(.companionNoMic)
    }

    @objc private func setModeRelay() {
        coordinator.setMode(.relay)
    }

    @objc private func setModePermissions() {
        coordinator.setMode(.permissionsOnly)
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

    @objc private func selectSilent() {
        speechService.ttsVoice = DuckVoices.silentSayName
        // This triggers the speech bubble since isSilent is now true
        speechService.speak("Silent mode. I'll use speech bubbles instead.")
    }

    @objc private func selectVoice(_ sender: NSMenuItem) {
        guard let sayName = sender.representedObject as? String else { return }
        speechService.ttsVoice = sayName
        let voice = DuckVoices.all.first { $0.sayName == sayName }
        speechService.speak(voice?.preview ?? "This is how I sound.", skipChirpWait: true)
    }

    @objc private func setLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
            print("[app] Registered Launch at Login")
        } catch {
            print("[app] Launch at Login register failed: \(error)")
        }
    }

    @objc private func setManualLaunch() {
        do {
            try SMAppService.mainApp.unregister()
            print("[app] Unregistered Launch at Login")
        } catch {
            print("[app] Launch at Login unregister failed: \(error)")
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

    /// Callback for voice feedback during install. Set by the app on launch.
    @MainActor static var onSpeak: ((String) -> Void)?

    /// Install the plugin. Tries automatic install first, falls back to clipboard if sandboxed.
    static func install() {
        // Try automatic install via CLI (works in dev, fails in sandbox)
        if let claude = findClaude() {
            Task { @MainActor in onSpeak?("Installing the plugin. One moment.") }
            automaticInstall(claude: claude)
        } else {
            Task { @MainActor in
                onSpeak?("Claude Code isn't installed yet. I'll show you how.")
                showClaudeNotFound()
            }
        }
    }

    // MARK: - Automatic install (unsandboxed)

    private static func findClaude() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return findTool("claude", extraPaths: [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/bin/claude",
            "/usr/local/bin/claude",
        ])
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

    /// Find the bundled plugin folder — inside app bundle Resources, or next to the .app during dev.
    private static func findBundledPlugin() -> String? {
        // Check inside app bundle (survives drag to Applications)
        if let resourcePath = Bundle.main.resourcePath {
            let bundledPlugin = (resourcePath as NSString).appendingPathComponent("plugin")
            if FileManager.default.fileExists(atPath: (bundledPlugin as NSString).appendingPathComponent(".claude-plugin/plugin.json")) {
                return bundledPlugin
            }
        }
        // Fallback: check next to the running app (dev layout)
        let appDir = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        let siblingPlugin = (appDir as NSString).appendingPathComponent("plugin")
        if FileManager.default.fileExists(atPath: (siblingPlugin as NSString).appendingPathComponent(".claude-plugin/plugin.json")) {
            return siblingPlugin
        }
        return nil
    }

    private static func automaticInstall(claude: String) {
        print("[plugin] Found claude at \(claude)")
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Remove old install (ignore failures — may not exist)
            print("[plugin] Cleaning previous install...")
            _ = run(claude, args: ["plugin", "uninstall", "duck-duck-duck"])

            // 2. Try bundled plugin first (works offline, no GitHub needed)
            if let bundledPath = findBundledPlugin() {
                print("[plugin] Found bundled plugin at \(bundledPath)")
                // Add bundled folder as a local marketplace, then install from it
                _ = run(claude, args: ["plugin", "marketplace", "remove", "duck-duck-duck-marketplace"])
                let (mpOk, mpOut) = run(claude, args: ["plugin", "marketplace", "add", bundledPath])
                print("[plugin] Bundled marketplace add: ok=\(mpOk) output=\(mpOut)")
                if mpOk {
                    let (installOk, installOut) = run(claude, args: ["plugin", "install", "duck-duck-duck"])
                    print("[plugin] Bundled install: ok=\(installOk) output=\(installOut)")
                    if installOk {
                        Task { @MainActor in
                            onSpeak?("Plugin installed. Start a Claude session and I'll be watching.")
                            showResult(success: true, detail: "Installed from bundled plugin. Start a new Claude Code session to activate the hooks.")
                        }
                        return
                    }
                }
                print("[plugin] Bundled install failed, falling back to GitHub marketplace...")
            }

            // 3. Fall back to GitHub marketplace (requires repo access)
            _ = run(claude, args: ["plugin", "marketplace", "remove", "duck-duck-duck-marketplace"])
            print("[plugin] Adding marketplace...")
            let (mpOk, mpOut) = run(claude, args: ["plugin", "marketplace", "add", "ideo/Rubber-Duck"])
            print("[plugin] Marketplace add: ok=\(mpOk) output=\(mpOut)")
            if !mpOk {
                Task { @MainActor in
                    onSpeak?("Something went wrong with the install.")
                    showResult(success: false, detail: "Marketplace add failed:\n\(mpOut)")
                }
                return
            }

            print("[plugin] Installing plugin...")
            let (installOk, installOut) = run(claude, args: ["plugin", "install", "duck-duck-duck"])
            print("[plugin] Plugin install: ok=\(installOk) output=\(installOut)")
            Task { @MainActor in
                if installOk {
                    onSpeak?("Plugin installed. Start a Claude session and I'll be watching.")
                    showResult(success: true, detail: "Start a new Claude Code session to activate the hooks.")
                } else {
                    onSpeak?("Something went wrong with the install.")
                    showResult(success: false, detail: "Plugin install failed:\n\(installOut)")
                }
            }
        }
    }

    // MARK: - Claude not found

    @MainActor
    private static func showClaudeNotFound() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Claude Code Not Found"
        alert.informativeText = """
            Duck Duck Duck works with Claude Code (CLI) or Claude Desktop.

            If you have Claude Desktop, you can install the plugin as a zip file — \
            go to Settings → Plugins → Upload local plugin.

            If you need Claude Code (CLI), grab it from claude.com/download.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export Plugin Zip")
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "I Have CLI (Copy Command)")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            exportPluginZip()
        } else if response == .alertSecondButtonReturn {
            showCLIInstallHelper()
        } else if response == .alertThirdButtonReturn {
            clipboardInstall()
        }
    }

    // MARK: - CLI install helper

    private static let cliInstallCommand = """
        curl -fsSL https://claude.ai/install.sh | bash && \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && \
        source ~/.zshrc
        """

    @MainActor
    private static func showCLIInstallHelper() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cliInstallCommand, forType: .string)

        let alert = NSAlert()
        alert.messageText = "Install Claude Code (CLI)"
        alert.informativeText = """
            Paste this in Terminal — it installs Claude Code and sets up your PATH:

            curl -fsSL https://claude.ai/install.sh | bash
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
            source ~/.zshrc

            The command has been copied to your clipboard.

            After installing, come back and click Install Plugin again.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "OK")

        onSpeak?("I copied the install command. Paste it in Terminal.")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    // MARK: - Plugin zip export (for Claude Desktop upload)

    @MainActor
    private static func exportPluginZip() {
        guard let pluginDir = findBundledPlugin() else {
            onSpeak?("Couldn't find the bundled plugin. That's weird.")
            let alert = NSAlert()
            alert.messageText = "Plugin Not Found"
            alert.informativeText = "Couldn't find the bundled plugin directory inside the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "duck-duck-duck-plugin.zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destURL = panel.url else { return }

        // Build zip from the plugin directory
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-c", "-k", "--keepParent", pluginDir, destURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                onSpeak?("Plugin zip saved. Drag it into Claude Desktop's plugin uploader.")
                // Reveal in Finder
                NSWorkspace.shared.activateFileViewerSelecting([destURL])
            } else {
                onSpeak?("Something went wrong creating the zip.")
            }
        } catch {
            print("[plugin] Zip export error: \(error)")
            onSpeak?("Something went wrong creating the zip.")
        }
    }

    // MARK: - Clipboard install (sandboxed fallback)

    @MainActor
    private static func clipboardInstall() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)

        let alert = NSAlert()
        alert.messageText = "Install Command Copied"
        alert.informativeText = "Paste this in Terminal:\n\n\(installCommand)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Terminal")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    @MainActor
    private static func showResult(success: Bool, detail: String) {
        showInstallResult(title: "Plugin Installed", success: success, detail: detail)
    }
}

// MARK: - Shared Install Helpers

/// Find a CLI tool by checking common paths then falling back to `which`.
func findTool(_ name: String, extraPaths: [String] = []) -> String? {
    for path in extraPaths {
        if FileManager.default.isExecutableFile(atPath: path) { return path }
    }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["which", name]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty && proc.terminationStatus == 0 { return path }
    } catch {}
    return nil
}

/// Show a simple result alert.
@MainActor
func showInstallResult(title: String, success: Bool, detail: String) {
    NSApp.activate()
    let alert = NSAlert()
    alert.messageText = success ? title : "Install Failed"
    alert.informativeText = detail
    alert.alertStyle = success ? .informational : .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

// MARK: - Gemini Extension Installer

enum GeminiExtensionInstaller {
    private static let installCommand = "gemini extensions install ideo/Rubber-Duck"
    private static let experimentalNote = "Experimental — Gemini CLI hooks provide eval scoring and permission notifications, but cannot relay decisions back. You'll need to approve permissions manually in the terminal."

    static func install() {
        if let gemini = findTool("gemini") {
            automaticInstall(gemini: gemini)
        } else {
            Task { @MainActor in clipboardInstall() }
        }
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
                    showInstallResult(
                        title: "Extension Installed",
                        success: ok,
                        detail: ok ? "\(experimentalNote)\n\nStart a new Gemini CLI session to activate." : "Extension install failed:\n\(output)")
                }
            } catch {
                Task { @MainActor in
                    showInstallResult(title: "Extension Installed", success: false, detail: error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private static func clipboardInstall() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Install Gemini Extension"
        alert.informativeText = "\(experimentalNote)\n\nPaste the following command in Terminal:\n\n\(installCommand)\n\nIt has been copied to your clipboard."
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
}

// MARK: - CLI Session Launcher (shared between DuckView + StatusBarManager)

enum CLISession {
    /// Launch Claude Code in a tmux session (needed for voice relay + TmuxBridge).
    static func launch(_ tool: String = "claude") {
        let session = DuckConfig.tmuxSession
        let windowName = DuckConfig.tmuxWindow

        // Walk up from binary to find repo root (look for Package.swift as marker).
        // When launched from DMG/Applications, the repo won't be found — fall back to ~.
        var repoRoot: URL? = nil
        var candidate = Bundle.main.bundleURL
        for _ in 0..<10 {
            candidate = candidate.deletingLastPathComponent()
            let marker = candidate.appendingPathComponent("widget/Package.swift")
            if FileManager.default.fileExists(atPath: marker.path) {
                repoRoot = candidate
                break
            }
        }

        let cdPart = repoRoot.map { "cd \($0.path) && " } ?? ""
        let script = """
        tell application "Terminal"
            activate
            do script "\(cdPart)if ! tmux has-session -t \(session) 2>/dev/null; then tmux new-session -d -s \(session) -n \(windowName) '\(tool)'; else tmux kill-window -t \(session):\(windowName) 2>/dev/null; tmux new-window -t \(session) -n \(windowName) '\(tool)'; fi && tmux attach -t \(session):\(windowName)"
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
