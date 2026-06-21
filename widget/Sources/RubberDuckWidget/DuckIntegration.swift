// Duck Integrations — the set of coding tools the duck can watch.
//
// The widget's eval server (localhost:3333) is shared, so the duck can be wired
// into several tools at once: a Claude Code session, a Cursor agent, and a
// Gemini CLI session all POST to the same /evaluate and /permission endpoints.
// What differs per tool is only the install mechanism (Claude = marketplace
// plugin, Cursor = ~/.cursor/hooks.json, Gemini = CLI extension) and the
// fidelity of the connection.
//
// This file unifies those behind one protocol so the Coding Tools preferences
// pane can render them as a single checklist. Each conformer is a thin wrapper
// over the existing installer (PluginInstaller / CursorInstaller /
// GeminiExtensionInstaller); adding a new tool later (Windsurf, Copilot, …) is
// one new conformer plus a line in `all`.

import Foundation

/// How completely a tool can talk to the duck. Not all integrations are equal —
/// the checklist should say so rather than imply parity.
enum IntegrationFidelity {
    /// Scores prompts/responses AND relays permission decisions (voice yes/no
    /// actually gates the action). Claude Code.
    case full
    /// Scores prompts/responses and NOTIFIES when the tool is waiting on you,
    /// but never gates — the tool owns approval, the duck only chirps. Cursor.
    case notify
    /// Scores prompts/responses only; can't gate or reliably notify. Gemini CLI.
    case observeOnly
}

// NOTE: the detection members are deliberately NOT @MainActor. They shell out
// (`which claude`, Launch Services lookups, filesystem scans) and MUST be called
// off the main thread — calling them during a SwiftUI view render spins the main
// runloop via Process.waitUntilExit and re-enters AttributeGraph, which aborts.
// Only connect()/disconnect() are @MainActor (they speak / show alerts).
// Sendable: conformers are immutable value types, so they cross threads safely
// (ToolsModel reads their detection off a background queue).
protocol DuckIntegration: Sendable {
    /// Stable identifier (used for SwiftUI list identity).
    var id: String { get }
    /// Display name, e.g. "Claude Code".
    var displayName: String { get }
    /// SF Symbol for the row.
    var iconSystemName: String { get }
    /// Is the underlying tool installed on this Mac? (Blocking — call off-main.)
    var isToolInstalled: Bool { get }
    /// Are the duck's hooks currently wired into it? (Blocking — call off-main.)
    var isConnected: Bool { get }
    /// What the duck can and can't do through this tool.
    var fidelity: IntegrationFidelity { get }
    /// One-line caveat shown under the row when relevant (nil = nothing to say).
    var capabilityNote: String? { get }
    /// Where to send the user if the tool itself isn't installed (nil = no link).
    var installToolURL: URL? { get }

    /// Wire the duck's hooks into this tool.
    @MainActor func connect()
    /// Remove the duck's hooks (best-effort).
    @MainActor func disconnect()
}

extension DuckIntegration {
    var fidelityLabel: String {
        switch fidelity {
        case .full: return "Scores + voice permissions"
        case .notify: return "Scores + waiting-for-you alerts"
        case .observeOnly: return "Scores only (approve in the tool)"
        }
    }
}

// MARK: - Claude Code

struct ClaudeCodeIntegration: DuckIntegration {
    let id = "claude-code"
    let displayName = "Claude Code"
    let iconSystemName = "terminal.fill"
    let fidelity: IntegrationFidelity = .full
    var isToolInstalled: Bool { PluginInstaller.isClaudeAvailable() }
    var isConnected: Bool { PluginInstaller.isPluginInstalled() }
    var capabilityNote: String? { nil }
    var installToolURL: URL? { URL(string: "https://claude.com/download") }

    @MainActor func connect() { PluginInstaller.install() }
    @MainActor func disconnect() { PluginInstaller.uninstall() }
}

// MARK: - Cursor

struct CursorIntegration: DuckIntegration {
    let id = "cursor"
    let displayName = "Cursor"
    let iconSystemName = "cursorarrow.rays"
    let fidelity: IntegrationFidelity = .notify
    var isToolInstalled: Bool { CursorInstaller.isCursorInstalled() }
    var isConnected: Bool { CursorInstaller.areHooksInstalled() }
    var capabilityNote: String? {
        "Cursor owns approvals; the duck just chirps when Cursor's waiting on you. Never blocks or decides."
    }
    var installToolURL: URL? { URL(string: "https://cursor.com") }

    @MainActor func connect() { CursorInstaller.install() }
    @MainActor func disconnect() { CursorInstaller.uninstall() }
}

// MARK: - Gemini CLI (experimental)

struct GeminiIntegration: DuckIntegration {
    let id = "gemini-cli"
    let displayName = "Gemini CLI"
    let iconSystemName = "sparkle"
    let fidelity: IntegrationFidelity = .observeOnly
    var isToolInstalled: Bool { GeminiExtensionInstaller.isGeminiAvailable() }
    var isConnected: Bool { GeminiExtensionInstaller.isInstalled() }
    var capabilityNote: String? {
        "Experimental. Gemini hooks can't relay decisions, so you approve permissions in the terminal."
    }
    var installToolURL: URL? { URL(string: "https://github.com/google-gemini/gemini-cli") }

    @MainActor func connect() { GeminiExtensionInstaller.install() }
    @MainActor func disconnect() { GeminiExtensionInstaller.uninstall() }
}

// MARK: - Registry

enum DuckIntegrations {
    /// All tools the duck knows how to connect to, in display order.
    static var all: [any DuckIntegration] {
        [ClaudeCodeIntegration(), CursorIntegration(), GeminiIntegration()]
    }
}
