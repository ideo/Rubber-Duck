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
    @Published var mode: DuckMode = DuckConfig.duckMode
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

        // Restore permissions-only side effects if that mode was persisted
        if mode == .permissionsOnly {
            speechService.listenMode = .permissionsOnly
        }
    }

    // MARK: - Event Handlers

    /// Called when eval scores change. Drives expression, serial, TTS.
    func handleNewEval() {
        // Duck is off — skip everything
        guard AppDelegate.isDuckActive else { return }

        // Thinking state: user eval means Claude is about to work;
        // Claude eval means Claude is done.
        // Permissions-only mode: ignore evals entirely — just resolve any stale permission
        if mode == .permissionsOnly {
            if evalService.permissionPending {
                evalService.permissionPending = false
            }
            serialManager.sendCommand("P,0")
            return
        }

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

        // Melody now triggered by /compact hook (PreCompact), not random chance.

        updateExpression()
        flashReaction()

        // Any new eval means the session moved on — resolve permission if pending
        // (Belt and suspenders: Teensy firmware also auto-resolves on new eval)
        if evalService.permissionPending {
            evalService.permissionPending = false
        }
        serialManager.sendCommand("P,0")

        // Send to duck via serial
        if let scores = evalService.scores {
            serialManager.sendScores(scores, source: evalService.source)
        }

        // Speak based on current mode (permissionsOnly exits early above)
        // Relay mode: only speak Claude's output, not the user's (you know what you said)
        let textToSpeak: String
        switch mode {
        case .critic:
            textToSpeak = evalService.reaction
        case .relay:
            textToSpeak = isUserEval ? "" : evalService.summary
        case .permissionsOnly:
            textToSpeak = ""  // unreachable — early return above; kept for exhaustive switch
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

    /// Cycle through modes: permissionsOnly → critic → relay → permissionsOnly.
    func toggleMode() {
        switch mode {
        case .permissionsOnly: setMode(.critic)
        case .critic: setMode(.relay)
        case .relay: setMode(.permissionsOnly)
        }
    }

    /// Set a specific mode. Speaks confirmation if the mode actually changed.
    func setMode(_ newMode: DuckMode) {
        guard newMode != mode else { return }
        mode = newMode
        DuckConfig.duckMode = newMode

        // In permissions-only, force mic to permissionsOnly listen mode + reset face to neutral
        if mode == .permissionsOnly {
            speechService.listenMode = .permissionsOnly
            withAnimation(.spring(response: DuckTheme.springResponse, dampingFraction: DuckTheme.springDamping)) {
                expression = DuckExpression()
            }
        }

        // Clear any thinking state when switching modes
        clearThinking()

        speechService.speak(mode.spokenLabel)
    }

    /// Clean up thinking state (called on turn-off).
    func clearThinking() {
        isThinking = false
        thinkingTimeout?.cancel()
        thinkingTimeout = nil
        melodyEngine.stop()
    }

    /// Start the Jeopardy thinking melody (called from /compact endpoint).
    func startMelody() {
        if let duckDevice = AudioDeviceDiscovery.findDuckDevice() {
            melodyEngine.outputDeviceID = duckDevice.deviceID
        } else {
            melodyEngine.outputDeviceID = nil
        }
        melodyEngine.start()
    }

    /// Stop the Jeopardy thinking melody.
    func stopMelody() {
        melodyEngine.stop()
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
        resetOrUpdateExpression()
    }

    /// Called when permission resolves (pending → false) via onChange.
    /// Backup path in case decision comes from outside the widget (CLI, timeout).
    func handlePermissionResolved() {
        DuckLog.log("[permission] Widget expression reset — permission resolved")
        resetOrUpdateExpression()
        serialManager.sendCommand("P,0")
        speechService.clearPermissionGate()
    }

    // MARK: - Expression

    /// In permissions-only mode, reset to neutral. Otherwise rebuild from scores.
    private func resetOrUpdateExpression() {
        if mode == .permissionsOnly {
            withAnimation(.spring(response: DuckTheme.springResponse, dampingFraction: DuckTheme.springDamping)) {
                expression = DuckExpression()
            }
        } else {
            updateExpression()
        }
    }

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
