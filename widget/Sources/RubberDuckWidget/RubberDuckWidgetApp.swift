// Rubber Duck Widget — Floating Desktop Companion
//
// A chromeless, always-on-top yellow cube that reacts
// to Claude Code evaluation scores in real time.
// Embeds its own HTTP+WebSocket eval server (no Python needed).
// Owns speech I/O (STT + TTS) and serial to Teensy.
//
// Starts dormant (menu bar icon only). The full duck widget
// activates when the user clicks "Show Duck" in the menu or
// when a duck USB device is detected via serial.
//
// Build: cd widget && make run

import SwiftUI

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
                .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
                .background(WindowDragArea())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottomTrailing)
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

        // Voice input → send to service → tmux → Claude Code
        speech.onVoiceInput = { [weak eval] text in
            eval?.sendVoiceInput(text)
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

        // TTS greeting when a Claude session connects via /health
        server.onSessionConnect = { [weak speech, weak coordinator] in
            let mode = coordinator?.mode ?? .critic
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
    /// Whether the duck companion is currently active (window + services).
    static var isDuckActive = false

    /// Service references for turn on/off. Set during wireServices().
    /// Strong refs — these live for the entire app lifetime (owned by @StateObject).
    static var speechService: SpeechService?
    static var coordinator: DuckCoordinator?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set accessory policy BEFORE any windows appear — prevents flicker
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the window that SwiftUI auto-creates — we'll show it on demand
        for window in NSApp.windows {
            window.orderOut(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Stay alive as menu bar agent
    }

    // MARK: - Window Management

    /// Configure a window as the borderless floating duck widget.
    static func configureDuckWindow(_ window: NSWindow) {
        window.styleMask = [.borderless]
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
        window.backgroundColor = .clear
        window.isOpaque = false

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = .clear
        window.contentView?.layer?.cornerRadius = DuckTheme.cornerRadius
        window.contentView?.layer?.masksToBounds = true
    }

    /// Turn on the duck companion: show window, enable speech.
    /// Server stays running across on/off cycles so hooks always work.
    @MainActor
    static func turnOn() {
        guard !isDuckActive else { return }
        isDuckActive = true

        speechService?.applyListenMode()

        // Show app in dock while duck is active
        NSApp.setActivationPolicy(.regular)

        for window in NSApp.windows where window.contentView != nil {
            configureDuckWindow(window)
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate()
        DuckLog.log("[app] Duck Duck Duck turned on")
    }

    /// Turn off the duck companion: hide window, stop speech.
    /// Server keeps running so Claude hooks stay connected.
    @MainActor
    static func turnOff() {
        guard isDuckActive else { return }
        isDuckActive = false

        speechService?.stopListening()
        speechService?.stopSpeaking()

        for window in NSApp.windows {
            window.orderOut(nil)
        }

        // Return to accessory (menu bar only, no dock icon)
        NSApp.setActivationPolicy(.accessory)
        DuckLog.log("[app] Duck Duck Duck turned off")
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
