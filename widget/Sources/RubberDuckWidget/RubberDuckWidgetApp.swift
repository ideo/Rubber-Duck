// Rubber Duck Widget — Floating Desktop Companion
//
// A chromeless, always-on-top yellow cube that reacts
// to Claude Code evaluation scores via WebSocket.
// Owns speech I/O (STT + TTS) and serial to Teensy.
//
// Build: cd widget && make run

import SwiftUI

@main
struct RubberDuckWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serviceProcess = ServiceProcess()
    @StateObject private var evalService = EvalService()
    @StateObject private var speechService = SpeechService()
    @StateObject private var serialManager = SerialManager()

    init() {
        // Regular app — shows in Dock, has menu bar, Cmd+Q works
        // User can launch from Finder, close normally
    }

    var body: some Scene {
        WindowGroup {
            DuckView()
                .environmentObject(serviceProcess)
                .environmentObject(evalService)
                .environmentObject(speechService)
                .environmentObject(serialManager)
                .frame(width: DuckTheme.widgetSize, height: DuckTheme.widgetSize)
                .background(WindowDragArea())
                .onAppear { wireServices() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottomTrailing)
    }

    // MARK: - Service Wiring

    private func wireServices() {
        // Request mic permission on launch
        speechService.requestPermissions()

        // Voice input → send to service → tmux → Claude Code
        speechService.onVoiceInput = { [weak evalService] text in
            evalService?.sendVoiceInput(text)
        }

        // Permission response → send to service → unblock hook
        speechService.onPermissionResponse = { [weak evalService] index in
            evalService?.sendPermissionDecision(index: index)
        }

        // Wake word → duck acknowledges
        speechService.onWakeWord = { [weak speechService] in
            print("[app] Wake word detected")
            _ = speechService // retain
        }

        // Teensy serial → log incoming messages
        serialManager.onLineReceived = { line in
            // Debug output from Teensy — just log it
            print("[serial] \(line)")
        }

        // Poll until permissions are granted, then start listening
        Task {
            for _ in 0..<20 { // Up to 10 seconds
                try? await Task.sleep(nanoseconds: 500_000_000)
                if speechService.micPermissionGranted && speechService.speechPermissionGranted {
                    speechService.startListening()
                    speechService.speak("What are we up to?")
                    return
                }
            }
            print("[app] Permissions not granted after 10s. Use right-click → Start Listening.")
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.isMovableByWindowBackground = true
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.hasShadow = true
                window.backgroundColor = .clear
                window.isOpaque = false
            }
        }

        // Cmd+Q handled automatically by menu bar
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
