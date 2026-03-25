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
                    speech.speak(["Hmm...", "Let me think...", "One sec..."].randomElement()!, skipChirpWait: true)
                }
                let answer = await helpService.ask(text)
                await MainActor.run {
                    speech.isWakeActive = false
                    if answer == DuckHelpService.fullStoryReadingSentinel {
                        // Fully shut down conversation state before the long story read
                        speech.exitConversation()
                        // Read the full Moby Duck story via TTS — no LLM, just reading aloud
                        speech.speak("Alright. Settle in. ... " + DuckHelpService.fullStoryText)
                        speech.restartAfterTTS(thenEnterConversation: false)
                        // Story told — fully reset backstory so next question goes back to normal help
                        Task { await helpService.resetBackstoryCompletely() }
                    } else {
                        speech.speak(answer ?? "Not sure about that one.")
                        speech.restartAfterTTS(thenEnterConversation: true)
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
        PluginInstaller.onSpeak = { [weak speech] text in speech?.speak(text) }

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

        // Wire lifecycle hooks from DuckServer → coordinator
        let transport = server.localTransport
        transport.onSpeak = { [weak speech] text in speech?.speak(text) }
        transport.onClearThinking = { [weak coordinator] in coordinator?.clearThinking() }
        transport.onMelodyStart = { [weak coordinator] in coordinator?.startMelody() }
        transport.onMelodyStop = { [weak coordinator] in coordinator?.stopMelody() }

        // TTS greeting when a Claude session connects via /health
        server.onSessionConnect = { [weak speech, weak coordinator] in
            let mode = coordinator?.mode ?? .companion
            speech?.speak(LaunchGreeting.sessionConnect(mode: mode))
        }

        // Poll until permissions are granted, then apply saved listen mode
        Task {
            for _ in 0..<20 { // Up to 10 seconds
                try? await Task.sleep(nanoseconds: 500_000_000)
                if speech.micPermissionGranted && speech.speechPermissionGranted {
                    speech.applyListenMode()
                    speech.speak(LaunchGreeting.pick(mode: coordinator.mode))
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

    func applicationDidResignActive(_ notification: Notification) {
        // When another app takes focus, re-activate so glass stays saturated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let duck = Self.duckWindow, duck.isVisible else { return }
            NSApp.activate()
            duck.makeKeyAndOrderFront(nil)
        }
    }

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
        // Strip useless default menus (View, Edit) — no SwiftUI API for this.
        // Delayed because SwiftUI rebuilds menus after applicationDidFinishLaunching.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let mainMenu = NSApp.mainMenu {
                let removeNames: Set<String> = ["View", "Edit"]
                for item in mainMenu.items where removeNames.contains(item.title) {
                    mainMenu.removeItem(item)
                }
            }
        }

        // Disable state restoration — it recreates windows without our properties
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame main")
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

            // Strip default File/Edit/View/Window menus — they're useless for a widget
            if let mainMenu = NSApp.mainMenu {
                for title in ["File", "Edit", "View", "Window"] {
                    if let item = mainMenu.items.first(where: { $0.title == title }) {
                        mainMenu.removeItem(item)
                    }
                }
            }

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
        // Kill any lingering TTS — say process outlives the app
        Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["say"])
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
        speechService?.stopSpeaking()
        coordinator?.clearThinking()
        DuckLog.log("[app] Duck Duck Duck turned off")
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

        // Override isKeyWindow getter to always return true
        let selector = #selector(getter: NSWindow.isKeyWindow)
        guard let method = class_getInstanceMethod(originalClass, selector) else {
            return
        }
        let types = method_getTypeEncoding(method)
        let block: @convention(block) (AnyObject) -> Bool = { _ in true }
        let imp = imp_implementationWithBlock(block)
        class_addMethod(subclass, selector, imp, types)

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
