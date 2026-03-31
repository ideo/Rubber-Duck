// Permission Gate — Voice-gated permission approval for Claude Code actions.
//
// Uses a FIFO queue so concurrent permission requests each block independently.
// The duck asks about the head of the queue; when resolved, the next one
// becomes active and the duck asks about it.
//
// Timeout uses DispatchQueue instead of Task.sleep to avoid the
// swift_task_dealloc crash that occurs with Task.sleep(for:) in
// certain actor/continuation contexts.

import Foundation

actor PermissionGate {

    private struct PendingRequest {
        let id: UUID
        let continuation: CheckedContinuation<(String, Int?), Never>
        let timeoutWorkItem: DispatchWorkItem
    }

    private var queue: [PendingRequest] = []

    /// Called when a request becomes the active (head) request and needs voice-asking.
    /// Fires both for the first request and when the queue advances.
    private var onBecameActive: ((PermissionEvent) -> Void)?

    func setOnBecameActive(_ handler: @escaping (PermissionEvent) -> Void) {
        onBecameActive = handler
    }

    /// Stored permission events, keyed by request ID, for delivery when active.
    private var pendingEvents: [UUID: PermissionEvent] = [:]

    // MARK: - Wait / Resolve

    /// Block until this request is resolved or times out.
    /// Requests are queued FIFO — each caller blocks independently.
    /// When this request is first in queue, `onBecameActive` fires immediately
    /// to trigger the duck's voice prompt. Otherwise it fires when the queue advances.
    func waitForDecision(timeoutSeconds: Double = 30.0, event: PermissionEvent) async -> (String, Int?) {
        let requestID = UUID()
        let isFirst = queue.isEmpty

        pendingEvents[requestID] = event

        // If first in queue, trigger the voice prompt immediately
        if isFirst {
            onBecameActive?(event)
        }

        let result = await withCheckedContinuation { (cont: CheckedContinuation<(String, Int?), Never>) in
            let workItem = DispatchWorkItem { [weak self] in
                Task { await self?.handleTimeout(requestID: requestID) }
            }
            let pending = PendingRequest(id: requestID, continuation: cont, timeoutWorkItem: workItem)
            queue.append(pending)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: workItem)
        }

        pendingEvents.removeValue(forKey: requestID)
        return result
    }

    /// Called when the widget sends a permission response via WebSocket or local transport.
    /// Resolves the head of the queue (the currently active request).
    func resolve(decision: String, suggestionIndex: Int? = nil) {
        guard !queue.isEmpty else { return }

        let validDecision = (decision == "allow" || decision == "deny") ? decision : "deny"
        DuckLog.log("[permission] Resolved: \(validDecision), suggestion_index=\(String(describing: suggestionIndex))")

        let head = queue.removeFirst()
        head.timeoutWorkItem.cancel()
        head.continuation.resume(returning: (validDecision, suggestionIndex))

        activateNextIfNeeded()
    }

    private func handleTimeout(requestID: UUID) {
        guard let idx = queue.firstIndex(where: { $0.id == requestID }) else { return }

        let wasHead = (idx == 0)
        let entry = queue.remove(at: idx)
        pendingEvents.removeValue(forKey: requestID)

        DuckLog.log("[permission] Timeout for request \(requestID.uuidString.prefix(8))")
        entry.continuation.resume(returning: ("timeout", nil))

        if wasHead { activateNextIfNeeded() }
    }

    private func activateNextIfNeeded() {
        guard let nextRequest = queue.first,
              let event = pendingEvents[nextRequest.id] else { return }
        DuckLog.log("[permission] Activating next in queue — \(queue.count) remaining")
        onBecameActive?(event)
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
