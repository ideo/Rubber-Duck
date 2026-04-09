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
    var updateChecker: UpdateChecker?

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
        statusItem?.autosaveName = "com.duckduckduck.statusitem"
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

    /// Load a duck SVG from the resource bundle as a menu bar image.
    /// - Parameters:
    ///   - named: SVG filename without extension (e.g. "duck-symbol", "duck-symbol-alert")
    ///   - isTemplate: true for monochrome (adapts to light/dark), false for color (alert icon)
    private static func menuBarIcon(named: String = "duck-symbol", isTemplate: Bool = true) -> NSImage? {
        guard let url = Resources.bundle.url(forResource: named, withExtension: "svg"),
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
        resized.isTemplate = isTemplate
        return resized
    }

    // MARK: - Status Icon

    /// Swap the menu bar icon between normal duck and alert duck based on permission state.
    private func updateStatusIcon() {
        let hasIssues = !speechService.micPermissionGranted || !speechService.speechPermissionGranted
        let iconName = hasIssues ? "duck-symbol-alert" : "duck-symbol"
        // duck-symbol-alert has color (yellow triangle) → NOT template
        // duck-symbol is monochrome → template (adapts to light/dark)
        if let icon = Self.menuBarIcon(named: iconName, isTemplate: !hasIssues) {
            statusItem?.button?.image = icon
            statusItem?.button?.title = ""
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        speechService.refreshPermissionStatus()
        updateStatusIcon()
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // --- Update notifications (top of menu for visibility) ---
        if let checker = updateChecker {
            if checker.isUpdateAvailable, let release = checker.latestRelease {
                let updateItem = NSMenuItem(
                    title: "Update Available: v\(release.version)",
                    action: #selector(openUpdatePage),
                    keyEquivalent: ""
                )
                updateItem.target = self
                updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Update")
                updateItem.subtitle = "Download from GitHub"
                menu.addItem(updateItem)
            }
            if checker.isPluginStale {
                let pluginItem = NSMenuItem(
                    title: "Plugin Update Available",
                    action: #selector(updatePlugin),
                    keyEquivalent: ""
                )
                pluginItem.target = self
                pluginItem.image = NSImage(systemSymbolName: "puzzlepiece.extension.fill", accessibilityDescription: "Plugin")
                pluginItem.subtitle = "Reinstall to get latest hooks"
                menu.addItem(pluginItem)
            }
            if checker.isUpdateAvailable || checker.isPluginStale {
                menu.addItem(.separator())
            }
        }

        // --- Volume slider ---
        menu.addItem(volumeSliderItem())

        // --- Subtitles toggle ---
        let subtitleItem = NSMenuItem(title: "Show Subtitles", action: #selector(toggleSubtitles), keyEquivalent: "")
        subtitleItem.target = self
        subtitleItem.image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "Subtitles")
        subtitleItem.subtitle = "Show speech bubbles with audio"
        subtitleItem.state = DuckConfig.subtitlesEnabled ? .on : .off
        menu.addItem(subtitleItem)

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

        // --- Intelligence submenu ---
        let currentProvider = DuckConfig.evalProvider
        let providerLabel: String
        switch currentProvider {
        case .foundation: providerLabel = "Foundation"
        case .anthropic: providerLabel = "Haiku"
        case .gemini: providerLabel = "Gemini"
        }
        let intellItem = NSMenuItem(title: "Intelligence: \(providerLabel)", action: nil, keyEquivalent: "")
        intellItem.image = NSImage(systemSymbolName: "brain.fill", accessibilityDescription: "Intelligence")
        let intellMenu = NSMenu()

        let foundationItem = NSMenuItem(title: "Apple Foundation Model", action: #selector(setProviderFoundation), keyEquivalent: "")
        foundationItem.target = self
        foundationItem.image = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: "Apple")
        foundationItem.subtitle = DuckConfig.isOlderAppleSilicon
            ? "Private, free — slow on this Mac (designed for M3+)"
            : "Private to your machine, free"
        foundationItem.state = currentProvider == .foundation ? .on : .off
        intellMenu.addItem(foundationItem)

        let haikuItem = NSMenuItem(title: "Claude Haiku", action: #selector(setProviderAnthropic), keyEquivalent: "")
        haikuItem.target = self
        haikuItem.image = NSImage(systemSymbolName: "asterisk", accessibilityDescription: "Claude")
        haikuItem.subtitle = "Anthropic API — requires key"
        haikuItem.state = currentProvider == .anthropic ? .on : .off
        intellMenu.addItem(haikuItem)

        let geminiItem = NSMenuItem(title: "Gemini", action: #selector(setProviderGemini), keyEquivalent: "")
        geminiItem.target = self
        geminiItem.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Gemini")
        geminiItem.subtitle = "Google API — requires key"
        geminiItem.state = currentProvider == .gemini ? .on : .off
        intellMenu.addItem(geminiItem)

        intellItem.submenu = intellMenu
        menu.addItem(intellItem)

        menu.addItem(.separator())

        // --- Launch sessions ---
        let claudeSession = NSMenuItem(title: "Launch Claude Code", action: #selector(startClaudeSession), keyEquivalent: "")
        claudeSession.target = self
        claudeSession.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Terminal")
        menu.addItem(claudeSession)

        // --- Permission warnings (only if something is wrong) ---
        let micOK = speechService.micPermissionGranted
        let speechOK = speechService.speechPermissionGranted
        if !micOK || !speechOK {
            menu.addItem(.separator())
            if !micOK {
                let item = NSMenuItem(title: "Microphone: Not Granted", action: nil, keyEquivalent: "")
                item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
                item.isEnabled = false
                menu.addItem(item)
                let fix = NSMenuItem(title: "Open Microphone Settings…", action: #selector(openMicSettings), keyEquivalent: "")
                fix.target = self
                fix.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
                menu.addItem(fix)
            }
            if !speechOK {
                let item = NSMenuItem(title: "Speech Recognition: Not Granted", action: nil, keyEquivalent: "")
                item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
                item.isEnabled = false
                menu.addItem(item)
                let fix = NSMenuItem(title: "Open Speech Recognition Settings…", action: #selector(openSpeechSettings), keyEquivalent: "")
                fix.target = self
                fix.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings")
                menu.addItem(fix)
            }
        }

        // --- Hardware status ---
        menu.addItem(.separator())
        if serialManager.isConnected {
            let hwItem = disabledItem("Ducky connected · \(serialManager.portName)")
            hwItem.image = NSImage(systemSymbolName: "cable.connector", accessibilityDescription: "Hardware")
            menu.addItem(hwItem)
        } else {
            let hwItem = disabledItem("No hardware connected")
            hwItem.image = NSImage(systemSymbolName: "cable.connector.slash", accessibilityDescription: "No hardware")
            menu.addItem(hwItem)
        }

        menu.addItem(.separator())

        // --- Pause / Resume ---
        if AppDelegate.isDuckActive {
            let pauseItem = NSMenuItem(title: "Pause", action: #selector(turnOffDuck), keyEquivalent: "")
            pauseItem.target = self
            if let icon = svgMenuIcon("no-duck-symbol") {
                pauseItem.image = icon
            }
            menu.addItem(pauseItem)
        } else {
            let resumeItem = NSMenuItem(title: "Resume", action: #selector(turnOnDuck), keyEquivalent: "")
            resumeItem.target = self
            if let icon = svgMenuIcon("duck-symbol") {
                resumeItem.image = icon
            }
            menu.addItem(resumeItem)
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Quit")
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

    @objc private func toggleSubtitles() {
        DuckConfig.subtitlesEnabled.toggle()
    }

    @objc private func startClaudeSession() {
        CLISession.launch()
    }

    @objc private func openUpdatePage() {
        guard let release = updateChecker?.latestRelease else { return }
        let urlString = release.dmgURL ?? release.htmlURL
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func updatePlugin() {
        PluginInstaller.install()
    }

    @objc private func installClaudeCLI() {
        Self.installClaudeCLIAction()
    }

    /// Install Claude Code CLI via Terminal — callable from both NSMenu and SwiftUI.
    /// Uses a .command file instead of osascript so no Automation permission is needed.
    @MainActor
    static func installClaudeCLIAction() {
        PluginInstaller.onSpeak?("Installing Claude Code. Watch the Terminal.")
        let script = """
            #!/bin/bash
            RC="$HOME/.$(basename "$SHELL")rc"
            grep -qF '.local/bin' "$RC" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC" 2>/dev/null
            export PATH="$HOME/.local/bin:$PATH"
            curl -fsSL https://claude.ai/install.sh | bash
            echo ''
            echo '✅ Claude Code installed! You can close this window.'
            echo 'Go back to Duck Duck Duck and click Install Plugin.'
            read -p 'Press Enter to close...'
            """
        let tmpPath = "/tmp/install-claude.command"
        do {
            try script.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpPath)
            NSWorkspace.shared.open(URL(fileURLWithPath: tmpPath))
        } catch {
            // Fallback: open download page
            NSWorkspace.shared.open(URL(string: "https://claude.com/download")!)
        }
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
        speechService.scheduleSpeech(
            "Wildcard mode.",
            kind: .preview,
            lane: .manual,
            scopeID: "voice-preview",
            policy: .latestWins,
            interruptibility: .freelyInterruptible,
            skipChirpWait: true
        )
    }

    @objc private func selectSilent() {
        speechService.ttsVoice = DuckVoices.silentSayName
        // This triggers the speech bubble since isSilent is now true
        speechService.scheduleSpeech(
            "Silent mode. I'll use speech bubbles instead.",
            kind: .preview,
            lane: .manual,
            scopeID: "voice-preview",
            policy: .latestWins,
            interruptibility: .freelyInterruptible
        )
    }

    @objc private func selectVoice(_ sender: NSMenuItem) {
        guard let sayName = sender.representedObject as? String else { return }
        speechService.ttsVoice = sayName
        let voice = DuckVoices.all.first { $0.sayName == sayName }
        speechService.scheduleSpeech(
            voice?.preview ?? "This is how I sound.",
            kind: .preview,
            lane: .manual,
            scopeID: "voice-preview",
            policy: .latestWins,
            interruptibility: .freelyInterruptible,
            skipChirpWait: true
        )
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

    @objc private func openMicSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSpeechSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
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

    /// Minimum Claude version that supports plugin hooks.
    static let minimumClaudeVersion = [1, 1, 9669]
    static var minimumClaudeVersionString: String { minimumClaudeVersion.map(String.init).joined(separator: ".") }

    /// Callback for voice feedback during install. Set by the app on launch.
    @MainActor static var onSpeak: ((String) -> Void)?

    /// Check if the Claude CLI version is new enough for plugin hooks.
    /// Returns (ok, versionString). If version can't be determined, returns (true, "unknown") to avoid blocking.
    private static func checkClaudeVersion(_ claudePath: String) -> (ok: Bool, version: String) {
        let (success, output) = run(claudePath, args: ["--version"])
        guard success else { return (true, "unknown") }

        // Output format: "2.1.83 (Claude Code)" — grab first word
        let versionStr = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").first ?? ""
        let parts = versionStr.components(separatedBy: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return (true, versionStr.isEmpty ? "unknown" : versionStr) }

        // Compare component-wise against minimum
        for (actual, required) in zip(parts, minimumClaudeVersion) {
            if actual > required { return (true, versionStr) }
            if actual < required { return (false, versionStr) }
        }
        // If we get here, all compared components are equal.
        // If actual has fewer components, treat as less than (e.g. "1.1" < "1.1.7714")
        return (parts.count >= minimumClaudeVersion.count, versionStr)
    }

    /// Show a warning that Claude is too old.
    @MainActor
    private static func showVersionWarning(found: String) {
        let alert = NSAlert()
        alert.messageText = "Claude Version Too Old"
        alert.informativeText = """
            Found Claude \(found), but Duck Duck Duck requires \(minimumClaudeVersionString) or newer.

            Update Claude Code:
            claude update

            Or reinstall from claude.ai/download.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Install the plugin. Prefers CLI install (properly registers with Claude Desktop),
    /// falls back to direct file copy if CLI isn't available.
    static func install() {
        if let claude = findClaude() {
            // CLI found — use it to properly register the plugin with Claude Desktop
            let (versionOK, foundVersion) = checkClaudeVersion(claude)
            if !versionOK {
                Task { @MainActor in
                    onSpeak?("Your Claude version is too old for plugins. Please update.")
                    showVersionWarning(found: foundVersion)
                }
                return
            }
            Task { @MainActor in onSpeak?("Installing the plugin. One moment.") }
            automaticInstall(claude: claude)
        } else if claudeConfigExists() {
            // No CLI but ~/.claude/plugins exists — direct file copy as best effort
            Task { @MainActor in onSpeak?("Installing the plugin. One moment.") }
            directInstall()
        } else {
            Task { @MainActor in
                onSpeak?("Claude Code isn't installed yet. I'll show you how.")
                showSetupChecklist(hasClaude: false, hasPlugin: DuckConfig.lastInstalledPluginVersion != nil)
            }
        }
    }

    /// Check if Claude is installed (Desktop or CLI has been run).
    /// Checks for ~/.claude/ (not just ~/.claude/plugins/ — Desktop may not create
    /// the plugins subdirectory until a plugin is first installed).
    private static func claudeConfigExists() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let claudeDir = "\(home)/.claude"
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: claudeDir, isDirectory: &isDir) && isDir.boolValue
    }

    /// Install plugin by copying files directly to ~/.claude/plugins/ (no CLI needed)
    private static func directInstall() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let bundledPath = findBundledPlugin() else {
                Task { @MainActor in
                    onSpeak?("Couldn't find the plugin files.")
                    showResult(success: false, detail: "Bundled plugin not found in app bundle.")
                }
                return
            }

            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser.path
            let pluginsBase = "\(home)/.claude/plugins"
            let version = "direct-\(Int(Date().timeIntervalSince1970))"
            let installDir = "\(pluginsBase)/cache/duck-duck-duck-marketplace/duck-duck-duck/\(version)"

            do {
                // Create install directory and copy plugin files
                try fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)
                let bundledURL = URL(fileURLWithPath: bundledPath)
                for item in try fm.contentsOfDirectory(at: bundledURL, includingPropertiesForKeys: nil).map(\.lastPathComponent) {
                    let src = "\(bundledPath)/\(item)"
                    let dst = "\(installDir)/\(item)"
                    try fm.copyItem(atPath: src, toPath: dst)
                }
                // Make hook scripts executable
                let hooksDir = "\(installDir)/hooks"
                if fm.fileExists(atPath: hooksDir) {
                    for file in (try? fm.contentsOfDirectory(atPath: hooksDir)) ?? [] where file.hasSuffix(".sh") {
                        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: "\(hooksDir)/\(file)")
                    }
                }
                print("[plugin] Copied plugin to \(installDir)")

                // Update installed_plugins.json (atomic write to prevent corruption)
                let installedFile = "\(pluginsBase)/installed_plugins.json"
                let installedURL = URL(fileURLWithPath: installedFile)
                var manifest: [String: Any] = ["version": 2, "plugins": [:] as [String: Any]]
                if let data = fm.contents(atPath: installedFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["version"] != nil, json["plugins"] is [String: Any] {
                    // Existing file is valid — use it
                    manifest = json
                } else if fm.fileExists(atPath: installedFile) {
                    // File exists but is corrupt — back it up and start fresh
                    let backup = installedFile + ".bak"
                    try? fm.removeItem(atPath: backup)
                    try? fm.copyItem(atPath: installedFile, toPath: backup)
                    print("[plugin] Backed up corrupt installed_plugins.json")
                }
                var plugins = manifest["plugins"] as? [String: Any] ?? [:]
                let now = ISO8601DateFormatter().string(from: Date())
                plugins["duck-duck-duck@duck-duck-duck-marketplace"] = [[
                    "scope": "user",
                    "installPath": installDir,
                    "version": version,
                    "installedAt": now,
                    "lastUpdated": now,
                ]]
                manifest["plugins"] = plugins
                let jsonData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
                try jsonData.write(to: installedURL, options: .atomic)
                print("[plugin] Updated installed_plugins.json")

                // Update known_marketplaces.json (atomic write)
                let marketplacesFile = "\(pluginsBase)/known_marketplaces.json"
                let marketplacesURL = URL(fileURLWithPath: marketplacesFile)
                var marketplaces: [String: Any] = [:]
                if let data = fm.contents(atPath: marketplacesFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    marketplaces = json
                }
                if marketplaces["duck-duck-duck-marketplace"] == nil {
                    let mpDir = "\(pluginsBase)/marketplaces/duck-duck-duck-marketplace"
                    try fm.createDirectory(atPath: mpDir, withIntermediateDirectories: true)
                    marketplaces["duck-duck-duck-marketplace"] = [
                        "source": ["source": "github", "repo": "ideo/Rubber-Duck"],
                        "installLocation": mpDir,
                        "lastUpdated": now,
                    ]
                    let mpData = try JSONSerialization.data(withJSONObject: marketplaces, options: [.prettyPrinted, .sortedKeys])
                    try mpData.write(to: marketplacesURL, options: .atomic)
                    print("[plugin] Updated known_marketplaces.json")
                }

                // Enable the plugin in settings.json — without this, Claude Desktop
                // shows a red dot (installed but not activated).
                let settingsFile = "\(home)/.claude/settings.json"
                let settingsURL = URL(fileURLWithPath: settingsFile)
                let pluginKey = "duck-duck-duck@duck-duck-duck-marketplace"
                var settings: [String: Any] = [:]
                if let data = fm.contents(atPath: settingsFile),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    settings = json
                }
                var enabled = settings["enabledPlugins"] as? [String: Any] ?? [:]
                if enabled[pluginKey] == nil || !(enabled[pluginKey] as? Bool ?? false) {
                    enabled[pluginKey] = true
                    settings["enabledPlugins"] = enabled
                    // Also add marketplace source so Claude knows where to look for updates
                    var extraMPs = settings["extraKnownMarketplaces"] as? [String: Any] ?? [:]
                    if extraMPs["duck-duck-duck-marketplace"] == nil {
                        extraMPs["duck-duck-duck-marketplace"] = [
                            "source": ["source": "github", "repo": "ideo/Rubber-Duck"]
                        ]
                        settings["extraKnownMarketplaces"] = extraMPs
                    }
                    let settingsData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
                    try settingsData.write(to: settingsURL, options: .atomic)
                    print("[plugin] Enabled plugin in settings.json")
                }

                // If CLI is available, also run plugin install for full registration
                if let claude = findClaude() {
                    let (activateOk, _) = run(claude, args: ["plugin", "install", "duck-duck-duck"])
                    print("[plugin] CLI activation: \(activateOk ? "succeeded" : "skipped")")
                }

                Task { @MainActor in
                    onSpeak?("Plugin installed. Restart Claude to activate.")
                    showResult(success: true, detail: "Plugin installed and enabled. Restart Claude Desktop to load the hooks.")
                }
            } catch {
                print("[plugin] Direct install failed: \(error)")
                Task { @MainActor in
                    onSpeak?("Something went wrong with the install.")
                    showResult(success: false, detail: "Direct install failed:\n\(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Automatic install (unsandboxed)

    static func findClaude() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return findTool("claude", extraPaths: [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
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
                            showResult(success: true, detail: "Installed from bundled plugin. Close and reopen Claude Code to activate the hooks.")
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
                // GitHub clone failed (no git / no xcode-select) — direct file copy
                print("[plugin] GitHub marketplace failed, falling back to direct file copy...")
                directInstall()
                return
            }

            print("[plugin] Installing plugin...")
            let (installOk, installOut) = run(claude, args: ["plugin", "install", "duck-duck-duck"])
            print("[plugin] Plugin install: ok=\(installOk) output=\(installOut)")
            if installOk {
                Task { @MainActor in
                    onSpeak?("Plugin installed. Start a Claude session and I'll be watching.")
                    showResult(success: true, detail: "Close and reopen Claude Code to activate the hooks.")
                }
                return
            }

            // CLI install command failed — direct file copy as last resort
            print("[plugin] CLI install failed, falling back to direct file copy...")
            directInstall()
        }
    }

    // MARK: - Claude not found

    @MainActor
    static func showSetupChecklist(hasClaude: Bool, hasPlugin: Bool) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Get Started with Duck Duck Duck"

        let claudeCheck = hasClaude ? "☑" : "☐"
        let pluginCheck = hasPlugin ? "☑" : "☐"

        alert.informativeText = """
            \(claudeCheck)  Step 1 — Install Claude
            Duck Duck Duck watches your Claude sessions and reacts. \
            Install Claude Code (terminal) or Claude Desktop (app).

            \(pluginCheck)  Step 2 — Install the Plugin
            Connect your duck to Claude so it can watch your sessions. \
            Use Setup → Install Plugin from the menu bar.
            """
        alert.alertStyle = .informational

        // Duck reacts to the setup state
        if hasClaude && hasPlugin {
            onSpeak?("You're all set! Everything's installed.")
        } else if hasClaude {
            onSpeak?("Almost there! Just need the plugin.")
        } else {
            onSpeak?("Let's get you set up.")
        }

        if !hasClaude {
            alert.addButton(withTitle: "Install Claude Code")
            alert.addButton(withTitle: "Download Claude Desktop")
            alert.addButton(withTitle: "Skip for Now")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                showCLIInstallHelper()
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://claude.com/download")!)
            }
        } else if !hasPlugin {
            alert.addButton(withTitle: "Install Plugin Now")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                install()
            }
        } else {
            // Everything installed — offer maintenance actions
            alert.addButton(withTitle: "Update Plugin")
            alert.addButton(withTitle: "Done")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                install()
            }
        }
    }

    // MARK: - CLI install helper

    private static let cliInstallCommand = """
        curl -fsSL https://claude.ai/install.sh | bash && \
        RC="$HOME/.$(basename "$SHELL")rc" && \
        grep -qF '.local/bin' "$RC" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC" && \
        source "$RC"
        """

    @MainActor
    static func showCLIInstallHelper() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cliInstallCommand, forType: .string)

        let alert = NSAlert()
        alert.messageText = "Install Claude Code (CLI)"
        alert.informativeText = """
            Paste this in Terminal — it installs Claude Code and sets up your PATH:

            curl -fsSL https://claude.ai/install.sh | bash

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
    static func exportPluginZip() {
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

    static let pluginDidInstallNotification = Notification.Name("PluginDidInstall")

    @MainActor
    private static func showResult(success: Bool, detail: String) {
        if success {
            UpdateChecker.recordPluginInstalled()
            NotificationCenter.default.post(name: pluginDidInstallNotification, object: nil)
        }
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
