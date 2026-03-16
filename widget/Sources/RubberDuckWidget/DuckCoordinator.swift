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
    @Published var isThinking = false

    private let evalService: EvalService
    private let speechService: SpeechService
    private let serialManager: SerialManager
    private let melodyEngine = MelodyEngine()
    private var thinkingTimeout: DispatchWorkItem?

    // Max thinking duration before auto-clearing (session crash safety net)
    private let thinkingTimeoutSeconds: Double = 120

    init(evalService: EvalService, speechService: SpeechService, serialManager: SerialManager) {
        self.evalService = evalService
        self.speechService = speechService
        self.serialManager = serialManager
    }

    // MARK: - Event Handlers

    /// Called when eval scores change. Drives expression, serial, TTS.
    func handleNewEval() {
        // Duck is off — skip everything
        guard AppDelegate.isDuckActive else { return }

        // Thinking state: user eval means Claude is about to work;
        // Claude eval means Claude is done.
        let isUserEval = evalService.source == "user"
        isThinking = isUserEval

        // Cancel any pending timeout, reset for new thinking cycle
        thinkingTimeout?.cancel()
        thinkingTimeout = nil

        // Stop any melody that was playing (Claude responded)
        melodyEngine.stop()

        // Safety net: auto-clear thinking if Claude eval never arrives (session crash, etc.)
        if isUserEval {
            let timeout = DispatchWorkItem { [weak self] in
                self?.isThinking = false
                self?.melodyEngine.stop()
            }
            thinkingTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + thinkingTimeoutSeconds, execute: timeout)
        }

        // ~10% chance: hum Jeopardy while Claude is thinking
        if isUserEval {
            if Int.random(in: 1...10) == 1 {
                if let teensy = AudioDeviceDiscovery.findTeensy() {
                    melodyEngine.outputDeviceID = teensy.deviceID
                } else {
                    melodyEngine.outputDeviceID = nil
                }
                melodyEngine.start()
            }
        }

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
        let textToSpeak: String
        switch mode {
        case .critic:
            textToSpeak = evalService.reaction
        case .relay:
            textToSpeak = isUserEval ? "" : evalService.summary
        }
        if !textToSpeak.isEmpty {
            // Wildcard mode: AI-picked voice per utterance (fall back to Superstar if no key)
            if speechService.isWildcardMode {
                let voiceKey = evalService.scores?.voice
                let picked = voiceKey.map { DuckVoices.wildcardVoice(for: $0) } ?? DuckVoices.wildcardDefault
                speechService.setVoiceTransient(picked.sayName)
            }
            speechService.speak(textToSpeak)
        }
    }

    /// Toggle between critic and relay mode. Speaks the new mode name as confirmation.
    func toggleMode() {
        setMode(mode == .critic ? .relay : .critic)
    }

    /// Set a specific mode. Speaks confirmation if the mode actually changed.
    func setMode(_ newMode: DuckMode) {
        guard newMode != mode else { return }
        mode = newMode
        let label = mode == .critic ? "Critic mode" : "Relay mode"
        speechService.speak(label)
    }

    /// Called when a new permission request arrives.
    func handlePermissionChange() {
        guard AppDelegate.isDuckActive else { return }
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
