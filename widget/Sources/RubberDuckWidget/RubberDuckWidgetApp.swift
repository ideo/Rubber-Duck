// Rubber Duck Widget — Floating Desktop Companion
//
// A chromeless, always-on-top yellow cube that reacts
// to Claude Code evaluation scores via WebSocket.
//
// Build: cd widget && make run

import SwiftUI

@main
struct RubberDuckWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var evalService = EvalService()

    init() {
        // When launched from CLI, ensure we activate properly
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory) // No dock icon
        }
    }

    var body: some Scene {
        WindowGroup {
            DuckView()
                .environmentObject(evalService)
                .frame(width: DuckTheme.widgetSize, height: DuckTheme.widgetSize)
                .background(WindowDragArea())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.bottomTrailing)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure windows to be floating and draggable
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Window Drag Support

/// Makes the background draggable in a chromeless window.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableView {
        DraggableView()
    }

    func updateNSView(_ nsView: DraggableView, context: Context) {}
}

class DraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
