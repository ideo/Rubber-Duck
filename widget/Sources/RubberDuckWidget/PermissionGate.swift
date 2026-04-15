// Permission Gate — Voice-gated permission approval for Claude Code actions.
//
// Single source of truth for permission state. Uses a FIFO queue so
// concurrent requests block independently. Callbacks notify the UI layer
// directly — no SwiftUI onChange bounce.
//
// Callbacks use DispatchQueue.main.async (FIFO-ordered) to guarantee
// onRequestResolved fires before onBecameActive for the next request.
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

    /// Fires when a request becomes the active (head) request.
    /// Used by DuckServer to deliver the permission event to EvalService/SpeechService.
    private var onBecameActive: ((PermissionEvent) -> Void)?

    /// Fires when the active request is resolved (voice, timeout, or external).
    /// Used by DuckServer to tell the coordinator to clear UI + voice gate.
    private var onRequestResolved: (() -> Void)?

    func setOnBecameActive(_ handler: @escaping (PermissionEvent) -> Void) {
        onBecameActive = handler
    }

    func setOnRequestResolved(_ handler: @escaping () -> Void) {
        onRequestResolved = handler
    }

    /// Stored permission events, keyed by request ID, for delivery when active.
    private var pendingEvents: [UUID: PermissionEvent] = [:]

    // MARK: - Wait / Resolve

    /// Block until this request is resolved or times out.
    /// Requests are queued FIFO — each caller blocks independently.
    /// When this request is first in queue, `onBecameActive` fires immediately.
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

    /// Called when the widget sends a permission response via voice or WebSocket.
    /// Resolves the head of the queue (the currently active request).
    func resolve(decision: String, suggestionIndex: Int? = nil) {
        guard !queue.isEmpty else { return }

        let validDecision = (decision == "allow" || decision == "deny") ? decision : "deny"
        DuckLog.log("[permission] Resolved: \(validDecision), suggestion_index=\(String(describing: suggestionIndex))")

        let head = queue.removeFirst()
        head.timeoutWorkItem.cancel()
        head.continuation.resume(returning: (validDecision, suggestionIndex))

        // Notify UI, then activate next — DispatchQueue.main.async is FIFO,
        // so resolved fires before becameActive for the next request.
        notifyResolvedThenAdvance()
    }

    private func handleTimeout(requestID: UUID) {
        guard let idx = queue.firstIndex(where: { $0.id == requestID }) else { return }

        let wasHead = (idx == 0)
        let entry = queue.remove(at: idx)
        pendingEvents.removeValue(forKey: requestID)

        DuckLog.log("[permission] Timeout for request \(requestID.uuidString.prefix(8))")
        entry.continuation.resume(returning: ("timeout", nil))

        if wasHead { notifyResolvedThenAdvance() }
    }

    /// Notify resolution, then activate the next queued request if any.
    /// Uses DispatchQueue.main.async for both to guarantee FIFO ordering on MainActor.
    private func notifyResolvedThenAdvance() {
        // 1. Tell UI to clear permission state
        let resolved = onRequestResolved
        DispatchQueue.main.async {
            resolved?()
        }

        // 2. If there's a next request, activate it (fires after resolved due to FIFO)
        if let nextRequest = queue.first, let event = pendingEvents[nextRequest.id] {
            DuckLog.log("[permission] Activating next in queue — \(queue.count) remaining")
            let activate = onBecameActive
            DispatchQueue.main.async {
                activate?(event)
            }
        }
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
