// Local Eval Transport — In-process eval delivery, bypassing WebSocket.
//
// Replaces WebSocketTransport as the default transport when the eval server
// runs inside the widget. Eval results are delivered directly from DuckServer
// to EvalService without a network round-trip.

import Foundation

class LocalEvalTransport: EvalTransport {
    var isConnected: Bool = true  // Always "connected" — we're in-process
    var onMessage: ((InboundMessage) -> Void)?

    // Outbound routing (set by DuckServer during wiring)
    var onVoiceInput: ((String) -> Void)?
    var onPermissionResponse: ((String, Int?) -> Void)?

    // Lifecycle hooks (set by DuckCoordinator during wiring)
    var onSpeak: ((String) -> Void)?
    var onMelodyStart: (() -> Void)?
    var onMelodyStop: (() -> Void)?
    var onClearThinking: (() -> Void)?
    /// Bool param: true if any concurrent passthroughs happened during the
    /// active window — coordinator should announce "more waiting in terminal".
    var onPermissionResolved: ((Bool) -> Void)?

    func connect() { /* no-op — always connected */ }
    func disconnect() { /* no-op */ }

    func send(_ message: OutboundMessage) {
        switch message {
        case .voiceInput(let cmd):
            onVoiceInput?(cmd.text)
        case .permissionResponse(let cmd):
            onPermissionResponse?(cmd.decision, cmd.suggestionIndex)
        }
    }

    // MARK: - Local Delivery (called by DuckServer)

    /// Deliver an eval result directly to EvalService.
    func deliver(_ result: EvalResult) {
        onMessage?(.eval(result))
    }

    /// Deliver a permission event directly to EvalService.
    func deliverPermission(_ event: PermissionEvent) {
        onMessage?(.permission(event))
    }
}
