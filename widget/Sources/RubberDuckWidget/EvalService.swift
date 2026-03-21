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
    @Published var summary: String = ""
    @Published var source: String = ""
    @Published var isConnected: Bool = false

    // Permission state
    @Published var permissionPending: Bool = false
    @Published var permissionTool: String = ""
    @Published var permissionSummary: String = ""
    @Published var permissionOptions: [String] = []
    @Published var permissionRequestId: Int = 0

    // Eval counter — increments on every eval so onChange always fires
    @Published var evalCount: Int = 0

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
        isConnected = transport.isConnected
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
            summary = newScores.summary ?? ""
            source = result.source ?? ""
            evalCount += 1
            sentiment = newScores.sentiment

        case .permission(let event):
            permissionTool = event.toolName ?? "unknown"
            permissionSummary = event.actionSummary ?? ""
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
        // Bounds check: suggestion index must be within available options (1-based)
        let clampedIndex: Int
        if index > 0 && index > permissionOptions.count {
            DuckLog.log("[eval] Warning: suggestion index \(index) out of bounds (\(permissionOptions.count) options), clamping to allow")
            clampedIndex = 0  // Fall back to simple allow
        } else {
            clampedIndex = index
        }

        let cmd = PermissionResponseCommand(
            decision: clampedIndex >= 0 ? "allow" : "deny",
            suggestionIndex: clampedIndex > 0 ? clampedIndex : nil
        )
        transport.send(.permissionResponse(cmd))
        permissionPending = false
    }
}
