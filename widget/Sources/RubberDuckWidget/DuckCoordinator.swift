// Duck Coordinator — Orchestrates side effects in response to eval events.
//
// Owns the duck's visual expression state and drives serial + TTS
// when evaluations arrive. DuckView becomes a pure renderer of
// the coordinator's published state.

import SwiftUI

@MainActor
class DuckCoordinator: ObservableObject {
    @Published var expression = DuckExpression()
    @Published var showReaction = false
    @Published var mode: DuckMode = .critic

    private let evalService: EvalService
    private let speechService: SpeechService
    private let serialManager: SerialManager

    init(evalService: EvalService, speechService: SpeechService, serialManager: SerialManager) {
        self.evalService = evalService
        self.speechService = speechService
        self.serialManager = serialManager
    }

    // MARK: - Event Handlers

    /// Called when eval scores change. Drives expression, serial, TTS.
    func handleNewEval() {
        updateExpression()
        flashReaction()

        // Any new eval means the session moved on — resolve permission if pending
        // (Belt and suspenders: Teensy firmware also auto-resolves on new eval)
        if evalService.permissionPending {
            evalService.permissionPending = false
        }
        serialManager.sendCommand("P,0")

        // Send to Teensy via serial
        if let scores = evalService.scores {
            serialManager.sendScores(scores, source: evalService.source)
        }

        // Speak based on current mode
        // Relay mode: only speak Claude's output, not the user's (you know what you said)
        let isUserEval = evalService.source == "user"
        let textToSpeak: String
        switch mode {
        case .critic:
            textToSpeak = evalService.reaction
        case .relay:
            textToSpeak = isUserEval ? "" : evalService.summary
        }
        if !textToSpeak.isEmpty {
            speechService.speak(textToSpeak)
        }
    }

    /// Toggle between critic and relay mode. Speaks the new mode name as confirmation.
    func toggleMode() {
        mode = (mode == .critic) ? .relay : .critic
        let label = mode == .critic ? "Critic mode" : "Relay mode"
        speechService.speak(label)
    }

    /// Called when a new permission request arrives.
    func handlePermissionChange() {
        updateExpression()
        if evalService.permissionPending {
            serialManager.sendCommand("P,1")
            speechService.askPermission(toolName: evalService.permissionTool,
                                        summary: evalService.permissionSummary,
                                        options: evalService.permissionOptions)
        }
    }

    /// Called when user approves/denies permission (voice or UI).
    /// Direct path — doesn't depend on SwiftUI onChange.
    func handlePermissionDecision(index: Int) {
        evalService.sendPermissionDecision(index: index)
        serialManager.sendCommand("P,0")
        updateExpression()
    }

    /// Called when permission resolves (pending → false) via onChange.
    /// Backup path in case decision comes from outside the widget (CLI, timeout).
    func handlePermissionResolved() {
        updateExpression()
        serialManager.sendCommand("P,0")
        speechService.clearPermissionGate()
    }

    // MARK: - Expression

    func updateExpression() {
        withAnimation(.spring(response: DuckTheme.springResponse, dampingFraction: DuckTheme.springDamping)) {
            expression = ExpressionEngine.reduce(
                scores: evalService.scores,
                permissionPending: evalService.permissionPending
            )
        }
    }

    private func flashReaction() {
        showReaction = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                self.showReaction = false
            }
        }

        // Open beak briefly when speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.2)) {
                self.expression.beakOpen = 0.0
            }
        }
    }

}
