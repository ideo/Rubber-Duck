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
    @Published var permissionWobble = false

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

        // Send to Teensy via serial
        if let scores = evalService.scores {
            serialManager.sendScores(scores, source: evalService.source)
        }

        // Speak the reaction
        if !evalService.reaction.isEmpty {
            speechService.speak(evalService.reaction)
        }
    }

    /// Called when permission state changes.
    func handlePermissionChange() {
        updateExpression()
        if evalService.permissionPending {
            triggerPermissionWobble()
            speechService.askPermission(toolName: evalService.permissionTool,
                                        options: evalService.permissionOptions)
        }
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

    private func triggerPermissionWobble() {
        withAnimation(
            .easeInOut(duration: 0.15)
            .repeatCount(6, autoreverses: true)
        ) {
            permissionWobble.toggle()
        }
    }
}
