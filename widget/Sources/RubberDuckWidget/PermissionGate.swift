// Permission Gate — Voice-gated permission approval for Claude Code actions.
//
// Uses CheckedContinuation for async blocking until the widget sends a
// voice response (allow/deny). Timeout after 30s if no response.
//
// Timeout uses DispatchQueue instead of Task.sleep to avoid the
// swift_task_dealloc crash that occurs with Task.sleep(for:) in
// certain actor/continuation contexts.

import Foundation

actor PermissionGate {

    private var continuation: CheckedContinuation<(String, Int?), Never>?
    private var timeoutWorkItem: DispatchWorkItem?

    // MARK: - Wait / Resolve

    /// Block until the widget sends a permission response, or timeout.
    /// Returns (decision, suggestionIndex) where decision is "allow", "deny", or "timeout".
    func waitForDecision(timeoutSeconds: Double = 30.0) async -> (String, Int?) {
        // Cancel any stale pending request
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        if let old = continuation {
            continuation = nil
            old.resume(returning: ("timeout", nil))
        }

        let result = await withCheckedContinuation { (cont: CheckedContinuation<(String, Int?), Never>) in
            continuation = cont

            // Use GCD for timeout — avoids swift_task_dealloc crash from Task.sleep
            let workItem = DispatchWorkItem { [weak self] in
                Task { await self?.handleTimeout() }
            }
            timeoutWorkItem = workItem
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: workItem)
        }

        return result
    }

    /// Called when the widget sends a permission response via WebSocket or local transport.
    func resolve(decision: String, suggestionIndex: Int? = nil) {
        let validDecision = (decision == "allow" || decision == "deny") ? decision : "deny"
        DuckLog.log("[permission] Resolved: \(validDecision), suggestion_index=\(String(describing: suggestionIndex))")

        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        if let cont = continuation {
            continuation = nil
            cont.resume(returning: (validDecision, suggestionIndex))
        }
    }

    private func handleTimeout() {
        guard let cont = continuation else { return }
        DuckLog.log("[permission] Timeout — no response from widget")
        continuation = nil
        timeoutWorkItem = nil
        cont.resume(returning: ("timeout", nil))
    }

    // MARK: - Suggestion Labels

    /// Generate a short, TTS-friendly label for a permission suggestion.
    /// Labels are designed for natural voice interaction:
    /// "Say always allow to [label]" or "Got it. [Label]."
    static func describeSuggestion(_ suggestion: [String: Any]) -> String {
        let stype = suggestion["type"] as? String ?? ""
        let dest = suggestion["destination"] as? String ?? "session"
        let scope = dest == "session" ? "for this session" : "for this project"

        switch stype {
        case "addRules":
            if let rules = suggestion["rules"] as? [[String: Any]],
               let first = rules.first,
               let tool = first["toolName"] as? String {
                return "always allow \(tool) \(scope)"
            }
            return "add a permission rule \(scope)"
        case "addDirectories":
            return "allow this directory \(scope)"
        case "setMode":
            if let mode = suggestion["mode"] as? String, !mode.isEmpty {
                return "switch to \(mode) mode"
            }
            return "change the permission mode"
        case "toolAlwaysAllow":
            let tool = suggestion["toolName"] as? String ?? "this tool"
            return "always allow \(tool)"
        case "acceptEdits":
            return "allow all file edits \(scope)"
        default:
            return "apply a permission rule"
        }
    }
}
