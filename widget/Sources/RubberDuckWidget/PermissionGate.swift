// Permission Gate — Voice-gated permission approval for Claude Code actions.
//
// Port of service/permission.py. Uses CheckedContinuation for async blocking
// until the widget sends a voice response (allow/deny).

import Foundation

actor PermissionGate {

    private var continuation: CheckedContinuation<(String, Int?), Never>?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Wait / Resolve

    /// Block until the widget sends a permission response, or timeout.
    /// Returns (decision, suggestionIndex) where decision is "allow", "deny", or "timeout".
    func waitForDecision(timeout: Duration = .seconds(30)) async -> (String, Int?) {
        // Cancel any stale pending request
        timeoutTask?.cancel()
        timeoutTask = nil
        if let old = continuation {
            continuation = nil
            old.resume(returning: ("timeout", nil))
        }

        let result = await withCheckedContinuation { (cont: CheckedContinuation<(String, Int?), Never>) in
            self.storeContinuationAndStartTimeout(cont, timeout: timeout)
        }

        return result
    }

    /// Called when the widget sends a permission response via WebSocket or local transport.
    func resolve(decision: String, suggestionIndex: Int? = nil) {
        let validDecision = (decision == "allow" || decision == "deny") ? decision : "deny"
        print("[permission] Resolved: \(validDecision), suggestion_index=\(String(describing: suggestionIndex))")

        timeoutTask?.cancel()
        timeoutTask = nil

        if let cont = continuation {
            continuation = nil
            cont.resume(returning: (validDecision, suggestionIndex))
        }
    }

    /// Store continuation and launch a detached timeout task.
    /// Using Task.detached avoids inheriting the suspended parent task context,
    /// which prevents the swift_task_dealloc crash that occurs with Task { }.
    private func storeContinuationAndStartTimeout(
        _ cont: CheckedContinuation<(String, Int?), Never>,
        timeout: Duration
    ) {
        continuation = cont
        timeoutTask = Task.detached { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            await self?.handleTimeout()
        }
    }

    private func handleTimeout() {
        guard let cont = continuation else { return }
        print("[permission] Timeout — no response from widget")
        continuation = nil
        timeoutTask = nil
        cont.resume(returning: ("timeout", nil))
    }

    // MARK: - Suggestion Labels

    /// Generate a short, TTS-friendly label for a permission suggestion.
    static func describeSuggestion(_ suggestion: [String: Any]) -> String {
        let stype = suggestion["type"] as? String ?? ""
        let dest = suggestion["destination"] as? String ?? "session"
        let scope = dest == "session" ? "for this session" : "permanently"

        switch stype {
        case "addRules":
            if let rules = suggestion["rules"] as? [[String: Any]],
               let first = rules.first,
               let tool = first["toolName"] as? String {
                return "always allow \(tool) \(scope)"
            }
            return "add a rule \(scope)"
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
            return "allow all file edits"
        default:
            return "apply a permission rule"
        }
    }
}
