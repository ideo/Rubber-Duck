// Permission Gate — Voice-gated permission approval for Claude Code actions.
//
// Single-slot model: at most ONE permission can be voice-prompted at a time.
// Concurrent requests (e.g., from agent teams firing in parallel, or two
// Claude sessions hitting permissions at once) return ("passthrough", nil)
// immediately so their hooks unblock and Claude Code's terminal UI handles
// them. This prevents one Claude session from being starved waiting on the
// duck's voice slot while another session has it.
//
// When the active request resolves (voice or timeout), if any concurrent
// requests passed through during that window, the resolved callback fires
// with hadPassthrough=true — the speech service then says "more waiting in
// terminal" once so the user knows to check elsewhere.
//
// Timeout uses DispatchQueue (not Task.sleep) to avoid the swift_task_dealloc
// crash that occurs with Task.sleep(for:) in certain actor/continuation contexts.

import Foundation

actor PermissionGate {

    private struct PendingRequest {
        let id: UUID
        let continuation: CheckedContinuation<(String, Int?), Never>
        let timeoutWorkItem: DispatchWorkItem
    }

    /// The single active request. nil = slot free, voice prompt available.
    /// non-nil = slot busy, concurrent requests will passthrough.
    private var activeRequest: PendingRequest?

    /// Set to true when a concurrent request comes in while activeRequest is set.
    /// Reset whenever a new active request begins. Drives the tail-end TTS
    /// "more waiting in terminal" announcement.
    private var passthroughHappenedDuringActive = false

    /// Fires when a request becomes the active (voice-prompted) request.
    /// Used by DuckServer to deliver the permission event to EvalService/SpeechService.
    private var onBecameActive: ((PermissionEvent) -> Void)?

    /// Fires when the active request is resolved (voice, timeout, or external).
    /// Bool param: true if any concurrent passthroughs happened during the
    /// active window — caller should announce "more waiting in terminal".
    private var onRequestResolved: ((Bool) -> Void)?

    func setOnBecameActive(_ handler: @escaping (PermissionEvent) -> Void) {
        onBecameActive = handler
    }

    func setOnRequestResolved(_ handler: @escaping (Bool) -> Void) {
        onRequestResolved = handler
    }

    // MARK: - Wait / Resolve

    /// Block until this request is resolved or times out.
    /// If another request is already active, returns ("passthrough", nil)
    /// IMMEDIATELY — caller (DuckServer) should respond `{}` so Claude UI
    /// handles it, and we mark that a passthrough happened.
    func waitForDecision(timeoutSeconds: Double = 30.0, event: PermissionEvent) async -> (String, Int?) {
        // Slot busy — silent passthrough to Claude UI.
        if activeRequest != nil {
            passthroughHappenedDuringActive = true
            DuckLog.log("[permission] Concurrent — passing through to Claude UI")
            return ("passthrough", nil)
        }

        // Slot free — claim it and run the voice flow.
        let requestID = UUID()
        onBecameActive?(event)

        let result = await withCheckedContinuation { (cont: CheckedContinuation<(String, Int?), Never>) in
            let workItem = DispatchWorkItem { [weak self] in
                Task { await self?.handleTimeout(requestID: requestID) }
            }
            activeRequest = PendingRequest(id: requestID, continuation: cont, timeoutWorkItem: workItem)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: workItem)
        }

        // Resolution complete — capture and reset state, then notify.
        let hadPassthrough = passthroughHappenedDuringActive
        passthroughHappenedDuringActive = false
        activeRequest = nil

        let resolved = onRequestResolved
        DispatchQueue.main.async {
            resolved?(hadPassthrough)
        }

        return result
    }

    /// Called when the widget sends a permission response via voice or WebSocket.
    /// Resolves the active request (if any).
    func resolve(decision: String, suggestionIndex: Int? = nil) {
        guard let active = activeRequest else { return }

        let validDecision = (decision == "allow" || decision == "deny") ? decision : "deny"
        DuckLog.log("[permission] Resolved: \(validDecision), suggestion_index=\(String(describing: suggestionIndex))")

        active.timeoutWorkItem.cancel()
        active.continuation.resume(returning: (validDecision, suggestionIndex))
        // Cleanup happens in waitForDecision after the continuation returns.
    }

    private func handleTimeout(requestID: UUID) {
        guard let active = activeRequest, active.id == requestID else { return }

        DuckLog.log("[permission] Timeout for request \(requestID.uuidString.prefix(8))")
        active.continuation.resume(returning: ("timeout", nil))
        // Cleanup happens in waitForDecision after the continuation returns.
    }

    // MARK: - Suggestion Labels

    /// Generate a short, TTS-friendly label for a permission suggestion.
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
