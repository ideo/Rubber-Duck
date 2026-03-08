// Eval Service — Manages evaluation state from the duck eval service.
//
// Uses an EvalTransport (default: WebSocketTransport) for communication.
// Publishes scores, reactions, and permission state for the UI and coordinator.
// Message types defined in DuckProtocol.swift.

import Foundation
import Combine

@MainActor
class EvalService: ObservableObject {
    // Current state
    @Published var scores: EvalScores?
    @Published var reaction: String = ""
    @Published var source: String = ""
    @Published var isConnected: Bool = false

    // Permission state
    @Published var permissionPending: Bool = false
    @Published var permissionTool: String = ""
    @Published var permissionOptions: [String] = []
    @Published var permissionRequestId: Int = 0

    // Computed
    @Published var sentiment: Double = 0.0

    private let transport: EvalTransport

    init(transport: EvalTransport = WebSocketTransport()) {
        self.transport = transport

        transport.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleMessage(message)
            }
        }
        transport.connect()
    }

    deinit {
        transport.disconnect()
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: InboundMessage) {
        isConnected = transport.isConnected

        switch message {
        case .eval(let result):
            guard let newScores = result.scores else { return }
            scores = newScores
            reaction = newScores.reaction ?? ""
            source = result.source ?? ""

            sentiment = (
                newScores.soundness * 0.3 +
                newScores.elegance * 0.25 +
                newScores.creativity * 0.2 +
                newScores.ambition * 0.15 -
                newScores.risk * 0.1
            )

        case .permission(let event):
            permissionTool = event.toolName ?? "unknown"
            let isPending = (event.status == "pending")
            permissionPending = isPending
            if isPending {
                permissionOptions = event.optionLabels ?? []
                permissionRequestId += 1
            }

        case .unknown:
            break
        }
    }

    // MARK: - Send

    func sendVoiceInput(_ text: String) {
        transport.send(.voiceInput(VoiceInputCommand(text: text)))
    }

    func sendPermissionDecision(index: Int) {
        let cmd = PermissionResponseCommand(
            decision: index >= 0 ? "allow" : "deny",
            suggestionIndex: index > 0 ? index : nil
        )
        transport.send(.permissionResponse(cmd))
        permissionPending = false
    }
}
