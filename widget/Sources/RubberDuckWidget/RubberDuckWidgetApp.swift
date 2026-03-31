// Rubber Duck Widget — Floating Desktop Companion
//
// A chromeless, always-on-top yellow cube that reacts
// to Claude Code evaluation scores in real time.
// Embeds its own HTTP+WebSocket eval server (no Python needed).
// Owns speech I/O (STT + TTS) and serial to Teensy.
//
// Always visible as a floating borderless window. Uses SwiftUI's
// .windowStyle(.hiddenTitleBar) + borderless styleMask for liquid glass.
//
// Build: cd widget && make run

import SwiftUI
import ObjectiveC
import ServiceManagement

@main
struct RubberDuckWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var duckServer: DuckServer
    @StateObject private var evalService: EvalService
    @StateObject private var speechService = SpeechService()
    @StateObject private var serialManager = SerialManager()
    @StateObject private var coordinator: DuckCoordinator

    /// Held strongly so the menu bar icon stays alive.
    private static var statusBarManager: StatusBarManager?

    init() {
        // Create server (reads API key lazily from DuckConfig at eval time)
        let server = DuckServer()
        let localTransport = server.localTransport

        // EvalService uses local transport instead of WebSocket
        let eval = EvalService(transport: localTransport)
        let speech = SpeechService()
        let serial = SerialManager()

        _duckServer = StateObject(wrappedValue: server)
        _evalService = StateObject(wrappedValue: eval)
        _speechService = StateObject(wrappedValue: speech)
        _serialManager = StateObject(wrappedValue: serial)
        let coord = DuckCoordinator(
            evalService: eval,
            speechService: speech,
            serialManager: serial
        )
        _coordinator = StateObject(wrappedValue: coord)

        // Wire services eagerly — can't wait for .onAppear because the window
        // starts hidden in dormant mode and SwiftUI may not fire view lifecycle.
        Task { @MainActor in
            RubberDuckWidgetApp.wireServicesOnce(
                server: server, eval: eval, speech: speech,
                serial: serial, coordinator: coord
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            DuckView()
                .environmentObject(coordinator)
                .environmentObject(duckServer)
                .environmentObject(evalService)
                .environmentObject(speechService)
                .environmentObject(serialManager)
                .frame(width: DuckTheme.widgetSize - 8)
                .background(WindowDragArea())
                .tint(Color(red: 0.925, green: 0.725, blue: 0.278))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottomTrailing)
        .commands {
            // Remove default View menu items
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            CommandMenu("Setup") {
                SetupMenuContent()
            }
            CommandGroup(replacing: .help) {
                HelpMenuContent()
            }
        }

        Window("Duck Duck Duck Help", id: "help") {
            HelpView()
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            PreferencesView()
                .environmentObject(speechService)
                .environmentObject(coordinator)
        }
    }

    // MARK: - Service Wiring

    @MainActor
    static func wireServicesOnce(
        server: DuckServer, eval: EvalService, speech: SpeechService,
        serial: SerialManager, coordinator: DuckCoordinator
    ) {
        // Wire services only once
        guard statusBarManager == nil else { return }

        // If Foundation Models isn't available and no API key exists, prompt for one.
        if !server.foundationModelsAvailable && DuckConfig.anthropicAPIKey.isEmpty {
            DuckConfig.evalProvider = .anthropic
            if !DuckConfig.ensureAPIKey() {
                NSApp.terminate(nil)
                return
            }
        }

        // Clean up stale port file from a previous crash/kill -9
        DuckConfig.cleanStalePortFile()

        // Start the embedded HTTP + WebSocket server
        server.start()

        // Request mic permission on launch
        speech.requestPermissions()

        // Voice input → help service (duck questions) or relay to Claude
        let helpService = DuckHelpService()
        speech.onVoiceInput = { [weak eval, weak speech, weak coordinator] text in
            guard let speech else { return }
            // Relay mode → always send to Claude via tmux
            let isRelay = coordinator?.mode == .relay
            if isRelay && eval?.isConnected == true {
                eval?.sendVoiceInput(text)
                return
            }

            // Everything else → duck handles it (help, chat, anything)
            Task {
                await MainActor.run {
                    let turnScope = speech.currentTurnScopeID ?? speech.nextTurnScopeID()
                    speech.scheduleSpeech(
                        ["Hmm...", "Let me think...", "One sec..."].randomElement()!,
                        kind: .filler,
                        lane: .turn,
                        scopeID: turnScope,
                        policy: .replaceScope,
                        interruptibility: .freelyInterruptible,
                        skipChirpWait: true
                    )
                }
                let answer = await helpService.ask(text)
                await MainActor.run {
                    speech.isWakeActive = false
                    let turnScope = speech.currentTurnScopeID ?? speech.nextTurnScopeID()
                    if answer == DuckHelpService.fullStoryReadingSentinel {
                        // Fully shut down conversation state before the long story read
                        speech.exitConversation()
                        let storyChunks = ["Alright. Settle in."] + DuckHelpService.fullStoryText
                            .components(separatedBy: " ... ")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        speech.scheduleScript(texts: storyChunks, scopeID: speech.nextScriptScopeID(prefix: "story"))
                        // Story told — fully reset backstory so next question goes back to normal help
                        Task { await helpService.resetBackstoryCompletely() }
                    } else {
                        speech.scheduleSpeech(
                            answer ?? "Not sure about that one.",
                            kind: .answer,
                            lane: .turn,
                            scopeID: turnScope,
                            policy: .replaceScope,
                            interruptibility: .byCriticalOnly,
                            onFinish: speech.makeListeningCompletionAction(enterConversation: true)
                        )
                    }
                }
            }
        }

        // Permission response → send to service → unblock hook → tell Teensy
        speech.onPermissionResponse = { [weak coordinator] index in
            coordinator?.handlePermissionDecision(index: index)
        }

        // Wake word → duck acknowledges
        speech.onWakeWord = {
            DuckLog.log("[app] Wake word detected")
        }

        // Give SpeechService the serial transport for ESP32 audio
        speech.setSerialTransport(serial.serialTransport)

        // Serial device change → let SpeechService switch audio paths
        // Also auto-turn-on the duck when hardware connects
        serial.onDeviceChange = { [weak speech, weak serial] in
            speech?.handleSerialDeviceChange()
            if serial?.isConnected == true {
                AppDelegate.turnOn()
                // Send persisted volume to firmware on connect
                serial?.sendCommand(String(format: "VOL,%.2f", DuckConfig.volume))
            }
        }

        // Serial → log incoming messages
        serial.onLineReceived = { line in
            DuckLog.log("[serial] \(line)")
        }

        // Mode button → toggle coordinator mode
        serial.onModeToggle = { [weak coordinator] in
            coordinator?.toggleMode()
        }

        // Wire plugin installer voice feedback
        PluginInstaller.onSpeak = { [weak speech] text in
            speech?.scheduleSpeech(
                text,
                kind: .system,
                lane: .manual,
                policy: .latestWins,
                interruptibility: .freelyInterruptible
            )
        }

        // Store service refs so AppDelegate can turn off the companion
        AppDelegate.speechService = speech
        AppDelegate.coordinator = coordinator

        // Menu bar status item (🦆) — settings live here instead of right-click menu
        statusBarManager = StatusBarManager(
            speechService: speech,
            coordinator: coordinator,
            serialManager: serial,
            duckServer: server
        )

        // Update checker — polls GitHub Releases API
        let updateChecker = UpdateChecker()
        statusBarManager?.updateChecker = updateChecker
        server.updateChecker = updateChecker

        updateChecker.onUpdateDetected = { [weak speech, weak coordinator] release in
            coordinator?.isAppUpdateAvailable = true
            coordinator?.appUpdateVersion = release.version
            coordinator?.appUpdateURL = release.dmgURL ?? release.htmlURL
            speech?.scheduleSpeech(
                "Hey, there's a newer version of me on GitHub!",
                kind: .system,
                lane: .ambient,
                policy: .dropIfBusy,
                interruptibility: .freelyInterruptible
            )
        }
        updateChecker.onPluginStale = { [weak speech, weak coordinator] in
            coordinator?.isPluginStale = true
            speech?.scheduleSpeech(
                "My plugin needs updating. Check the menu.",
                kind: .system,
                lane: .ambient,
                policy: .dropIfBusy,
                interruptibility: .freelyInterruptible
            )
        }

        // Detect app version change → check plugin staleness
        if updateChecker.detectAppVersionChange() {
            updateChecker.detectPluginStaleness()
        }

        updateChecker.startPeriodicChecks()

        // Wire lifecycle hooks from DuckServer → coordinator
        let transport = server.localTransport
        transport.onSpeak = { [weak speech] text in
            speech?.scheduleSpeech(
                text,
                kind: .system,
                lane: .ambient,
                policy: .dropIfBusy,
                interruptibility: .freelyInterruptible
            )
        }
        transport.onClearThinking = { [weak coordinator] in coordinator?.clearThinking() }
        transport.onMelodyStart = { [weak coordinator] in coordinator?.startMelody() }
        transport.onMelodyStop = { [weak coordinator] in coordinator?.stopMelody() }

        // TTS greeting when a Claude session connects via /health
        server.onSessionConnect = { [weak speech, weak coordinator] in
            let mode = coordinator?.mode ?? .companion
            speech?.scheduleSpeech(
                LaunchGreeting.sessionConnect(mode: mode),
                kind: .greeting,
                lane: .ambient,
                policy: .dropIfBusy,
                interruptibility: .freelyInterruptible
            )
        }

        // Wait for permissions, then apply saved listen mode + greet
        Task {
            // Check immediately — permissions may already be granted from previous launch
            speech.refreshPermissionStatus()
            if speech.micPermissionGranted && speech.speechPermissionGranted {
                speech.applyListenMode()
                speech.scheduleSpeech(
                    LaunchGreeting.pick(mode: coordinator.mode),
                    kind: .greeting,
                    lane: .ambient,
                    policy: .dropIfBusy,
                    interruptibility: .freelyInterruptible
                )
                return
            }
            // Otherwise poll (waiting for user to grant via dialog)
            for _ in 0..<20 { // Up to 10 seconds
                try? await Task.sleep(nanoseconds: 500_000_000)
                speech.refreshPermissionStatus()
                if speech.micPermissionGranted && speech.speechPermissionGranted {
                    speech.applyListenMode()
                    speech.scheduleSpeech(
                        LaunchGreeting.pick(mode: coordinator.mode),
                        kind: .greeting,
                        lane: .ambient,
                        policy: .dropIfBusy,
                        interruptibility: .freelyInterruptible
                    )
                    return
                }
            }
            DuckLog.log("[app] Permissions not granted after 10s. Set listen mode from menu bar.")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Whether the duck companion is currently active (speech + reactions).
    /// When false, the duck shows a sleeping/off state but the window stays visible.
    static var isDuckActive = true

    /// The duck widget window. Tracked so turnOn/turnOff don't touch other windows.
    static weak var duckWindow: NSWindow?

    /// Service references for turn on/off. Set during wireServices().
    static var speechService: SpeechService?
    static var coordinator: DuckCoordinator?

    // NOTE: applicationDidResignActive removed — it was stealing focus from
    // Settings/Help windows, preventing sidebar clicks. Glass saturation is
    // now handled solely by canBecomeKey override on the duck window.

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When Settings/Help closes, re-key the duck window
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { notif in
            guard let window = notif.object as? NSWindow,
                  window != Self.duckWindow else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let duck = Self.duckWindow, duck.isVisible else { return }
                duck.makeKeyAndOrderFront(nil)
                NSApp.activate()
            }
        }
        // Mark any new windows as non-restorable (Help, Settings created on demand)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { notif in
            (notif.object as? NSWindow)?.isRestorable = false
        }

        // Strip useless default menus — SwiftUI recreates them on window focus,
        // so we observe changes and strip continuously.
        Self.startMenuStripping()

        // Disable state restoration — it recreates windows without our properties.
        // Clear ALL window frame autosaves, not just "main".
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("NSWindow Frame") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.removeObject(forKey: "NSWindowAutosaveFrames")

        // Ensure app is a regular dock app (not background agent)
        NSApp.setActivationPolicy(.regular)

        // Hide windows immediately to prevent one-frame flash of title bar chrome.
        // SwiftUI renders .hiddenTitleBar first; we override to borderless on next tick.
        for window in NSApp.windows {
            window.alphaValue = 0
        }

        DispatchQueue.main.async {
            // At launch there's only one window — the duck.
            // Grab it before Settings or Help can create more.
            let duckWin = NSApp.windows.first
            Self.duckWindow = duckWin

            for window in NSApp.windows {
                // Fully borderless — no titlebar, no chrome
                window.styleMask = [.borderless]
                window.isMovable = true
                window.isMovableByWindowBackground = true
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.hasShadow = true
                window.backgroundColor = .clear
                window.isOpaque = false
                window.isRestorable = false

                // Match content view clip to duck glass corner radius
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = .clear
                window.contentView?.layer?.cornerRadius = DuckTheme.cornerRadius
                window.contentView?.layer?.masksToBounds = true

                // Keep glass tint saturated even when app isn't frontmost
                AlwaysActiveWindowHelper.apply(to: window)
                window.invalidateShadow()

                // Reveal now that chrome is gone
                window.alphaValue = 1
            }
            DuckLog.log("[focus] duckWindow assigned: \(duckWin != nil)")
            NSApp.activate()

            // Menu stripping handled by startMenuStripping()

            // Check for Claude after UI is ready
            self.checkForClaude()
        }
    }

    // MARK: - Claude detection on launch

    private func checkForClaude() {
        // Give the window a moment to render before showing alerts
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let hasCLI = PluginInstaller.findClaude() != nil

            let hasDesktop: Bool = {
                if let urls = LSCopyApplicationURLsForBundleIdentifier(
                    "com.anthropic.claudefordesktop" as CFString, nil
                )?.takeRetainedValue() as? [URL] {
                    return !urls.isEmpty
                }
                return false
            }()

            if !hasCLI && !hasDesktop {
                DuckLog.log("[startup] No Claude CLI or Desktop found — showing install guide")
                PluginInstaller.onSpeak?(
                    "Hey! You'll need Claude installed for me to work. Let me help you set that up."
                )
                PluginInstaller.showClaudeNotFound()
            } else {
                DuckLog.log("[startup] Claude detected — CLI: \(hasCLI), Desktop: \(hasDesktop)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop owned TTS sessions cleanly before shutdown.
        Task { @MainActor in
            Self.speechService?.stopSpeaking(reason: .shutdown)
        }
        // Clean up port file so hooks don't try a stale port
        DuckConfig.removePortFile()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Stay alive as menu bar agent
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false // Prevent state restoration from recreating stale windows
    }

    // MARK: - Window Management

    /// Turn on the duck companion: enable speech and reactions.
    @MainActor
    static func turnOn() {
        guard !isDuckActive else { return }
        isDuckActive = true
        speechService?.applyListenMode()
        DuckLog.log("[app] Duck Duck Duck turned on")
    }

    /// Turn off the duck companion: stop speech, duck stays visible but dormant.
    @MainActor
    static func turnOff() {
        guard isDuckActive else { return }
        isDuckActive = false
        speechService?.stopListening()
        speechService?.stopSpeaking(reason: .userCancelled)
        coordinator?.clearThinking()
        DuckLog.log("[app] Duck Duck Duck turned off")
    }

    // MARK: - Menu Stripping

    private static let unwantedMenus: Set<String> = ["File", "Edit", "View", "Window"]

    /// Strip default menus on launch and when windows change focus.
    /// Uses NSWindow notifications instead of NSMenu.didAddItemNotification
    /// (which fires too aggressively and disrupts eval/speech pipelines).
    static func startMenuStripping() {
        stripMenus()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { stripMenus() }
        }
    }

    private static func stripMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }
        for item in mainMenu.items where unwantedMenus.contains(item.title) {
            mainMenu.removeItem(item)
        }
    }
}

// MARK: - Always-Active Window (Glass Tint Fix)

/// Dynamically subclasses the SwiftUI window's actual runtime class so that
/// `isKeyWindow` and `canBecomeKey/Main` always return `true`. This keeps the
/// liquid glass compositor rendering in its saturated/tinted state even when
/// the app isn't frontmost or another window (Settings) has taken key status.
///
/// Borderless windows return `canBecomeKey = false` by default, which prevents
/// the system from returning key status to the duck after Settings closes.
/// By subclassing the real class (not plain NSWindow), all private SwiftUI
/// methods like `setMenuBarHeight:` are preserved.
enum AlwaysActiveWindowHelper {
    private static var appliedClasses: Set<String> = []

    static func apply(to window: NSWindow) {
        let originalClass: AnyClass = type(of: window)
        let className = NSStringFromClass(originalClass)

        // Only create the subclass once per original class
        let subclassName = "AlwaysActive_" + className
        if let existingClass = NSClassFromString(subclassName) {
            object_setClass(window, existingClass)
            return
        }

        // Create dynamic subclass of the window's actual runtime class
        guard let subclass = objc_allocateClassPair(originalClass, subclassName, 0) else {
            return
        }

        let boolBlock: @convention(block) (AnyObject) -> Bool = { _ in true }
        let boolImp = imp_implementationWithBlock(boolBlock)

        // Override canBecomeKey — borderless windows return false by default,
        // which prevents the system from re-keying the window after Settings closes
        if let canKeyMethod = class_getInstanceMethod(originalClass, #selector(getter: NSWindow.canBecomeKey)) {
            class_addMethod(subclass, #selector(getter: NSWindow.canBecomeKey), boolImp, method_getTypeEncoding(canKeyMethod))
        }

        // Override canBecomeMain for the same reason
        if let canMainMethod = class_getInstanceMethod(originalClass, #selector(getter: NSWindow.canBecomeMain)) {
            class_addMethod(subclass, #selector(getter: NSWindow.canBecomeMain), boolImp, method_getTypeEncoding(canMainMethod))
        }

        // NOTE: we do NOT override isKeyWindow. Lying about key status prevents
        // other windows (Settings, Help) from receiving clicks. canBecomeKey +
        // canBecomeMain are enough for the system to return focus to us.
        // Glass saturation is handled by applicationDidResignActive re-activating.

        objc_registerClassPair(subclass)
        object_setClass(window, subclass)
    }
}

// MARK: - Window Drag Support

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableView {
        DraggableView()
    }

    func updateNSView(_ nsView: DraggableView, context: Context) {}
}

class DraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

// MARK: - Setup Menu

struct SetupMenuContent: View {
    @AppStorage("experimentalEnabled") private var experimentalEnabled = false

    var body: some View {
        if PluginInstaller.findClaude() == nil {
            Button {
                StatusBarManager.installClaudeCLIAction()
            } label: {
                Label("Install Claude Code...", systemImage: "arrow.down.circle.fill")
            }
        } else {
            Button {} label: {
                Label("Claude Code Installed", systemImage: "checkmark.circle.fill")
            }
            .disabled(true)
        }

        Button {
            PluginInstaller.install()
        } label: {
            Label("Install / Update Plugin", systemImage: "puzzlepiece.extension.fill")
        }

        Button {
            PluginInstaller.exportPluginZip()
        } label: {
            Label("Export Plugin Zip...", systemImage: "square.and.arrow.up")
        }

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("[app] Launch at Login toggle failed: \(error)")
                }
            }
        ))

        Divider()

        Toggle(isOn: $experimentalEnabled) {
            Label("Experimental Features", systemImage: "flask.fill")
        }

        if experimentalEnabled {
            Button {
                GeminiExtensionInstaller.install()
            } label: {
                Label("Install Gemini Extension", systemImage: "puzzlepiece.extension.fill")
            }
            Button {
                CLISession.launchPlain("gemini")
            } label: {
                Label("Launch Gemini CLI", systemImage: "terminal.fill")
            }
        }
    }
}

// MARK: - Help Menu

struct HelpMenuContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            AppDelegate.coordinator?.runSetupGuide()
        } label: {
            Label("Get Started", systemImage: "sparkles")
        }

        Button {
            NSWorkspace.shared.open(URL(string: "http://localhost:\(DuckConfig.activePort)")!)
        } label: {
            Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
        }

        Divider()

        Button {
            NSApp.activate()
            openWindow(id: "help")
        } label: {
            Label("User Manual", systemImage: "book.fill")
        }
    }
}
