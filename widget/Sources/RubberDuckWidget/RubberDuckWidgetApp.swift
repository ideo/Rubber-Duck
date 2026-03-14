// Rubber Duck Widget — Floating Desktop Companion
//
// A chromeless, always-on-top yellow cube that reacts
// to Claude Code evaluation scores in real time.
// Embeds its own HTTP+WebSocket eval server (no Python needed).
// Owns speech I/O (STT + TTS) and serial to Teensy.
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
        _coordinator = StateObject(wrappedValue: DuckCoordinator(
            evalService: eval,
            speechService: speech,
            serialManager: serial
        ))
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
                .onAppear { wireServices() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottomTrailing)
    }

    // MARK: - Service Wiring

    private func wireServices() {
        // If Foundation Models isn't available and no API key exists, prompt for one.
        // This is the only case where the API key prompt appears on startup.
        if !duckServer.foundationModelsAvailable && DuckConfig.anthropicAPIKey.isEmpty {
            DuckConfig.evalProvider = .anthropic
            if !DuckConfig.ensureAPIKey() {
                NSApp.terminate(nil)
                return
            }
        }

        // Start the embedded HTTP + WebSocket server
        duckServer.start()

        // Request mic permission on launch
        speechService.requestPermissions()

        // Voice input → send to service → tmux → Claude Code
        speechService.onVoiceInput = { [weak evalService] text in
            evalService?.sendVoiceInput(text)
        }

        // Permission response → send to service → unblock hook → tell Teensy
        speechService.onPermissionResponse = { [weak coordinator] index in
            coordinator?.handlePermissionDecision(index: index)
        }

        // Wake word → duck acknowledges
        speechService.onWakeWord = { [weak speechService] in
            DuckLog.log("[app] Wake word detected")
            _ = speechService // retain
        }

        // Give SpeechService the serial transport for ESP32 audio
        speechService.setSerialTransport(serialManager.serialTransport)

        // Serial device change → let SpeechService switch audio paths
        serialManager.onDeviceChange = { [weak speechService] in
            speechService?.handleSerialDeviceChange()
        }

        // Serial → log incoming messages
        serialManager.onLineReceived = { line in
            DuckLog.log("[serial] \(line)")
        }

        // Mode button → toggle coordinator mode
        serialManager.onModeToggle = { [weak coordinator] in
            coordinator?.toggleMode()
        }

        // Menu bar status item (🦆) — settings live here instead of right-click menu
        RubberDuckWidgetApp.statusBarManager = StatusBarManager(
            speechService: speechService,
            coordinator: coordinator,
            serialManager: serialManager,
            duckServer: duckServer
        )

        // TTS greeting when a Claude session connects via /health
        duckServer.onSessionConnect = { [weak speechService, weak coordinator] in
            let mode = coordinator?.mode ?? .critic
            speechService?.speak(LaunchGreeting.sessionConnect(mode: mode))
        }

        // Poll until permissions are granted, then apply saved listen mode
        Task {
            for _ in 0..<20 { // Up to 10 seconds
                try? await Task.sleep(nanoseconds: 500_000_000)
                if speechService.micPermissionGranted && speechService.speechPermissionGranted {
                    speechService.applyListenMode()
                    speechService.speak(LaunchGreeting.pick(mode: coordinator.mode))
                    return
                }
            }
            DuckLog.log("[app] Permissions not granted after 10s. Set listen mode from menu bar.")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                // Fully borderless — no titlebar, no glass, no chrome
                window.styleMask = [.borderless]
                window.isMovable = true
                window.isMovableByWindowBackground = true
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.hasShadow = true
                window.backgroundColor = .clear
                window.isOpaque = false

                // Match content view clip to duck glass corner radius
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = .clear
                window.contentView?.layer?.cornerRadius = DuckTheme.cornerRadius
                window.contentView?.layer?.masksToBounds = true
            }
        }

        // Cmd+Q handled automatically by menu bar
        // App icon is loaded from duckIcon.icon in Resources via CFBundleIconFile
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
