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
    @Published var energy: DuckEnergy = DuckConfig.energy
    @Published var micEnabled: Bool = DuckConfig.micEnabled
    @Published var isThinking = false

    // Update notifications — set by UpdateChecker callbacks
    @Published var isAppUpdateAvailable = false
    @Published var appUpdateVersion: String?
    @Published var appUpdateURL: String?
    @Published var isPluginStale = false

    private let evalService: EvalService
    private let speechService: SpeechService
    private let serialManager: SerialManager
    private let melodyEngine = MelodyEngine()
    private var thinkingTimeout: DispatchWorkItem?

    // Max thinking duration before auto-clearing (session crash safety net)
    private let thinkingTimeoutSeconds: Double = 120

    // Shy energy speech shaping. Three knobs:
    //  - Full reactions: at most one per `shyReactionMinInterval` seconds.
    //  - Extreme reactions (|sentiment| > threshold) bypass the gap.
    //  - Middle reactions inside the gap become a soft non-verbal ack, with
    //    their own shorter sub-gap so the acks don't carpet-bomb either.
    // Permission alerts go through a separate speech path and are unaffected.
    private let shyReactionMinInterval: TimeInterval = 60
    private let shyAckMinInterval: TimeInterval = 20
    private let shyExtremeThreshold: Double = 0.5
    // Mix of non-verbal hums and short verbal acknowledgments. Dropped "uh huh"
    // because the synth phrases it as two soft blips that fade after the chirp.
    // Dropped "mm" / "mmhmm" because macOS voices spell them letter-by-letter.
    private let shyAcks = ["hmm", "ah", "oh", "huh", "ooh", "i see", "sure", "ok", "why not", "interesting"]
    private var lastShyReactionAt: Date?
    private var lastShyAckAt: Date?

    init(evalService: EvalService, speechService: SpeechService, serialManager: SerialManager) {
        self.evalService = evalService
        self.speechService = speechService
        self.serialManager = serialManager

        // Restore mic behavior from persisted (mode + energy + mic) triple.
        // Listen mode is fully derived — see DuckConfig.listenMode.
        speechService.listenMode = DuckConfig.listenMode

        // Yield the Jeopardy melody whenever ANY TTS is about to play —
        // permission prompts, reactions, mode announcements, scripts, etc.
        // Without this, melody frames and TTS frames interleave on the
        // serial audio bus (and mix at the OS output on the local path),
        // producing garbled audio. Melody stays stopped; /compact restarts it.
        speechService.onSpeechWillStart = { [weak self] in
            self?.melodyEngine.stop()
        }
    }

    // MARK: - Event Handlers

    /// Called when eval scores change. Drives expression, serial, TTS.
    func handleNewEval() {
        // Duck is off — skip everything
        guard AppDelegate.isDuckActive else { return }

        // Thinking state: user eval means Claude is about to work;
        // Claude eval means Claude is done.
        // Permissions-only mode: ignore evals entirely
        // Zen energy = permissions-only behavior: ignore evals entirely.
        // Only nudge the permission LED to "resolved" when there's no
        // active permission — otherwise we'd clobber a real pending alert
        // every time a user prompt or claude eval lands.
        if energy == .zen {
            if !evalService.permissionPending {
                serialManager.sendCommand("P,0")
            }
            return
        }

        let isUserEval = evalService.source == "user"
        isThinking = isUserEval

        // Cancel any pending timeout, reset for new thinking cycle
        thinkingTimeout?.cancel()
        thinkingTimeout = nil

        // Stop melody only when Claude responds (not on user evals — those
        // arrive while Claude is still thinking, which is when the melody plays).
        if !isUserEval {
            melodyEngine.stop()
        }

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

        // Permission state is managed by PermissionGate (timeout/resolve).
        // Don't auto-clear here — evals from other sessions would wipe pending permissions.
        serialManager.sendCommand("P,0")

        // Send to duck via serial
        if let scores = evalService.scores {
            serialManager.sendScores(scores, source: evalService.source)
        }

        // Speak based on current mode (Zen energy already exited early above).
        // Walkie-Talkie: only speak Claude's output, not the user's (you know
        // what you said). Companion: speak gut-reaction text.
        // `var` because shy energy may swap the text for a soft ack.
        var textToSpeak: String
        switch mode {
        case .companion:
            textToSpeak = evalService.reaction
        case .walkieTalkie:
            textToSpeak = isUserEval ? "" : evalService.summary
        }
        // Track whether the upcoming utterance is a shy ack — if so, we'll
        // bypass wildcard voice selection (slow/musical voices butcher
        // ultra-short text like "ah" or "ooh" into silence).
        var isShyAck = false

        // Shy energy speech shaping. Full reactions get a `shyReactionMinInterval`
        // gap; extreme reactions (loud signal) bypass the gap; middle reactions
        // inside the gap become a soft ack with its own shorter sub-gap.
        // Permission alerts use a different path — unaffected. Zen already
        // returned above.
        if !textToSpeak.isEmpty && energy == .shy {
            let now = Date()
            let magnitude = abs(evalService.scores?.sentiment ?? 0)
            let isExtreme = magnitude > shyExtremeThreshold
            let inFullGap: Bool = {
                guard let last = lastShyReactionAt else { return false }
                return now.timeIntervalSince(last) < shyReactionMinInterval
            }()

            if isExtreme || !inFullGap {
                // Full reaction speaks. Reset the gap timer.
                lastShyReactionAt = now
                DuckLog.log("[shy] full reaction (extreme=\(isExtreme), |sentiment|=\(String(format: "%.2f", magnitude)))")
            } else {
                // Middle reaction inside the gap — substitute a soft ack
                // unless we're also inside the ack sub-gap.
                let inAckGap: Bool = {
                    guard let last = lastShyAckAt else { return false }
                    return now.timeIntervalSince(last) < shyAckMinInterval
                }()
                if inAckGap {
                    DuckLog.log("[shy] dropped middle reaction (ack sub-gap)")
                    return
                }
                lastShyAckAt = now
                textToSpeak = shyAcks.randomElement() ?? "hmm"
                isShyAck = true
                DuckLog.log("[shy] ack: \(textToSpeak) (|sentiment|=\(String(format: "%.2f", magnitude)))")
            }
        }

        if !textToSpeak.isEmpty {
            // Shy acks always use the reliable default voice — wildcard's slow
            // musical voices (Bells, Pipe Organ, Trinoids) butcher 2-3 char
            // tokens like "ah" or "ooh" into silence.
            if isShyAck {
                speechService.setVoiceTransient(DuckVoices.wildcardDefault.sayName)
                speechService.scheduleSpeech(
                    textToSpeak,
                    kind: .reaction,
                    lane: .ambient,
                    policy: .dropIfBusy,
                    interruptibility: .freelyInterruptible
                )
                return
            }

            // Wildcard mode: AI-picked voice per utterance (fall back to Superstar if no key)
            if speechService.isWildcardMode {
                let voiceKey = evalService.scores?.voice
                var picked = voiceKey.map { DuckVoices.wildcardVoice(for: $0) } ?? DuckVoices.wildcardDefault

                // Slow voices (musical/effect-heavy) sound terrible on long text.
                // Swap to Superstar if text exceeds roughly one sentence.
                if textToSpeak.count > DuckVoices.slowVoiceCharacterLimit,
                   let wk = voiceKey.flatMap({ DuckVoices.WildcardKey(rawValue: $0) }),
                   DuckVoices.slowWildcardKeys.contains(wk) {
                    DuckLog.log("[wildcard] \(wk.rawValue) too slow for \(textToSpeak.count) chars, falling back to superstar")
                    picked = DuckVoices.wildcardDefault
                }

                speechService.setVoiceTransient(picked.sayName)
                speechService.scheduleSpeech(
                    textToSpeak,
                    kind: .reaction,
                    lane: .ambient,
                    policy: .dropIfBusy,
                    interruptibility: .freelyInterruptible
                )
                // Reset to default voice so permissions/greetings don't inherit the wildcard pick
                speechService.setVoiceTransient(DuckVoices.wildcardDefault.sayName)
            } else {
                speechService.scheduleSpeech(
                    textToSpeak,
                    kind: .reaction,
                    lane: .ambient,
                    policy: .dropIfBusy,
                    interruptibility: .freelyInterruptible
                )
            }
        }
    }

    /// Cycle through modes.
    func toggleMode() {
        let allModes = DuckMode.allCases
        if let idx = allModes.firstIndex(of: mode) {
            let next = allModes[(idx + 1) % allModes.count]
            setMode(next)
        } else {
            setMode(.companion)
        }
    }

    /// Set a specific mode. Mode is just companion vs walkie-talkie; mic and
    /// chattiness live in the Energy + Mic toggles.
    /// Switching INTO walkie-talkie auto-launches the tmux'd CLI session.
    func setMode(_ newMode: DuckMode) {
        guard newMode != mode else { return }
        mode = newMode
        DuckConfig.duckMode = newMode

        // Mic behavior is governed by mic+energy, not mode — refresh in case
        // anything implicit changed.
        speechService.listenMode = DuckConfig.listenMode

        // Clear any thinking state when switching modes
        clearThinking()

        speechService.scheduleSpeech(
            mode.spokenLabel,
            kind: .system,
            lane: .manual,
            policy: .latestWins,
            interruptibility: .freelyInterruptible
        )

        // Walkie-Talkie needs a live tmux'd CLI to receive voice input.
        // Auto-launch on mode switch so the user doesn't have to click twice.
        // Existing tmux session is reused (CLISession.launch handles either path).
        // Also force voice control on — WT without a mic is just an empty terminal.
        if newMode == .walkieTalkie {
            if !micEnabled {
                setMicEnabled(true)
            }
            CLISession.launch()
        }
    }

    /// Set the energy level (Normal / Shy / Zen). Resets expression to
    /// neutral when transitioning to Zen since reactions stop firing.
    func setEnergy(_ newEnergy: DuckEnergy) {
        guard newEnergy != energy else { return }
        energy = newEnergy
        DuckConfig.energy = newEnergy

        // Listen mode depends on energy (Zen → permissions-only listen).
        speechService.listenMode = DuckConfig.listenMode

        if newEnergy == .zen {
            withAnimation(.spring(response: DuckTheme.springResponse, dampingFraction: DuckTheme.springDamping)) {
                expression = DuckExpression()
            }
        }

        clearThinking()

        speechService.scheduleSpeech(
            newEnergy.spokenLabel,
            kind: .system,
            lane: .manual,
            policy: .latestWins,
            interruptibility: .freelyInterruptible
        )
    }

    /// Toggle the mic on/off. When off, permissions become click-only
    /// and STT does not run.
    func setMicEnabled(_ enabled: Bool) {
        guard enabled != micEnabled else { return }
        micEnabled = enabled
        DuckConfig.micEnabled = enabled
        speechService.listenMode = DuckConfig.listenMode

        speechService.scheduleSpeech(
            enabled ? "Voice control on" : "Voice control off",
            kind: .system,
            lane: .manual,
            policy: .latestWins,
            interruptibility: .freelyInterruptible
        )
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
        // Prefer serial path when ESP32 hardware is connected
        let transport = serialManager.serialTransport
        if transport.isConnected {
            melodyEngine.serialTransport = transport
        } else {
            melodyEngine.serialTransport = nil
            // Fallback: route local playback to USB audio device if present
            if let duckDevice = AudioDeviceDiscovery.findDuckDevice() {
                melodyEngine.outputDeviceID = duckDevice.deviceID
            } else {
                melodyEngine.outputDeviceID = nil
            }
        }
        melodyEngine.start()
    }

    /// Stop the Jeopardy thinking melody.
    func stopMelody() {
        melodyEngine.stop()
    }

    /// Spoken setup guide — walks the user through getting started.
    func runSetupGuide() {
        let steps: [String]
        if evalService.isConnected {
            // Plugin is working, guide them on modes
            steps = [
                "You're all set up!",
                "Right-click me to switch modes.",
                "Companion mode watches and reacts to your work.",
                "Permissions mode handles allow and deny by voice.",
                "Say ducky to talk to me when wake word is on.",
            ]
        } else {
            // No plugin yet
            steps = [
                "Hey! I'm Duck Duck Duck.",
                "I work with Claude Code and Claude Desktop.",
                "First, install the plugin. Check the menu bar icon for the install button.",
                "Then start a Claude session. I'll watch and react to everything.",
                "Right-click me anytime for settings and modes.",
            ]
        }
        speechService.scheduleScript(texts: steps, scopeID: speechService.nextScriptScopeID(prefix: "setup"))
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

    /// Called by PermissionGate (via onRequestResolved) when the active request
    /// is resolved or times out.
    ///
    /// - Parameter hadPassthrough: true if any concurrent permission requests
    ///   silently passed through to Claude Code's terminal UI during the
    ///   active window. Triggers a one-shot "more waiting in terminal" TTS so
    ///   the user knows to check elsewhere.
    func handlePermissionResolved(hadPassthrough: Bool = false) {
        DuckLog.log("[permission] Gate resolved — clearing UI + voice gate (passthroughs=\(hadPassthrough))")
        evalService.permissionPending = false
        resetOrUpdateExpression()
        serialManager.sendCommand("P,0")
        speechService.clearPermissionGate()

        if hadPassthrough {
            speechService.notifyMorePermissionsWaiting()
        }
    }

    // MARK: - Expression

    /// In Zen energy (permissions-only behavior), reset to neutral. Otherwise rebuild from scores.
    private func resetOrUpdateExpression() {
        if energy == .zen {
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
