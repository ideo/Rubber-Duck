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

    // Update notifications — set by UpdateChecker callbacks
    @Published var isAppUpdateAvailable = false
    @Published var appUpdateVersion: String?
    @Published var appUpdateURL: String?
    @Published var isPluginStale = false

    // Evil twin — the doppelganger that tries to take over
    @Published var evilTwinSummoned = false
    @Published var evilExpression = DuckExpression(eyeHeight: 0.55)
    @Published var evilTakeoverActive = false
    private var evilPhysicsTimer: Timer?
    private var evilVelocity = CGPoint(x: 0, y: 0)
    private var mainVelocity = CGPoint(x: 0, y: 0)
    private var lastCollisionAt: Date = .distantPast
    /// On collision we dismiss any active popover so the window kick can land
    /// safely, then queue the "Get back!" speech. This flag is fired in
    /// physicsStep once the window has settled AND no popover is re-attached.
    private var pendingTakeoverSpeech = false
    /// Tracks popover attached-state across physicsStep ticks so we can detect
    /// the detached → attached transition and zero any residual velocity
    /// exactly then — otherwise sub-threshold residuals leak out as a tiny
    /// window shift when the popover later closes.
    private var mainPopoverAttachedLastTick = false

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

        // Restore mic behavior for persisted mode
        speechService.listenMode = mode.requiredListenMode
    }

    // MARK: - Event Handlers

    /// Called when eval scores change. Drives expression, serial, TTS.
    func handleNewEval() {
        // Duck is off — skip everything
        guard AppDelegate.isDuckActive else { return }

        // Thinking state: user eval means Claude is about to work;
        // Claude eval means Claude is done.
        // Permissions-only mode: ignore evals entirely
        if mode == .permissionsOnly {
            serialManager.sendCommand("P,0")
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

        // Speak based on current mode (permissionsOnly exits early above)
        // Relay mode: only speak Claude's output, not the user's (you know what you said)
        let textToSpeak: String
        switch mode {
        case .companion, .companionNoMic:
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

    /// Set a specific mode. Mic behavior is baked in — no separate toggle.
    func setMode(_ newMode: DuckMode) {
        guard newMode != mode else { return }
        mode = newMode
        DuckConfig.duckMode = newMode

        // Auto-set mic based on mode
        speechService.listenMode = newMode.requiredListenMode

        // Reset face to neutral in non-reaction modes
        if !newMode.speaksReactions {
            withAnimation(.spring(response: DuckTheme.springResponse, dampingFraction: DuckTheme.springDamping)) {
                expression = DuckExpression()
            }
        }

        // Clear any thinking state when switching modes
        clearThinking()

        speechService.scheduleSpeech(
            mode.spokenLabel,
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
    /// is resolved or times out. Safe to clear voice gate here — the gate
    /// guarantees this fires before onBecameActive for the next request
    /// (DispatchQueue.main.async FIFO ordering).
    func handlePermissionResolved() {
        DuckLog.log("[permission] Gate resolved — clearing UI + voice gate")
        evalService.permissionPending = false
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
                permissionPending: evalService.permissionPending,
                evilTakeoverActive: evilTakeoverActive
            )
            evilExpression = ExpressionEngine.reduceEvil(
                scores: evalService.scores,
                takeoverActive: evilTakeoverActive
            )
        }
    }

    // MARK: - Evil Twin

    /// Summon the evil duck. The window is opened by the caller (needs SwiftUI openWindow).
    func summonEvilTwin() {
        guard !evilTwinSummoned else { return }
        evilTwinSummoned = true
        DuckLog.log("[evil] Summoned")
        startEvilCreep()
        speechService.scheduleSpeech(
            "Don't look now... but there's two of us.",
            kind: .system,
            lane: .manual,
            policy: .latestWins,
            interruptibility: .freelyInterruptible
        )
    }

    /// Banish the evil duck. The window is closed by the caller.
    func banishEvilTwin() {
        guard evilTwinSummoned else { return }
        evilTwinSummoned = false
        evilTakeoverActive = false
        stopEvilCreep()
        DuckLog.log("[evil] Banished")
        speechService.scheduleSpeech(
            "Good. Stay gone.",
            kind: .system,
            lane: .manual,
            policy: .latestWins,
            interruptibility: .freelyInterruptible
        )
    }

    private func startEvilCreep() {
        stopEvilCreep()
        // Kick off physics after the window has a chance to appear. SwiftUI opens
        // the window and AppDelegate tags it via applicationWillUpdate — if we
        // seed before that races to completion, evilDuckWindow is still nil and
        // the twin would spawn at SwiftUI's default position with zero velocity.
        seedEvilPhysicsWhenReady(attempt: 0)
        // 60Hz physics tick
        evilPhysicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.physicsStep() }
        }
    }

    private func seedEvilPhysicsWhenReady(attempt: Int) {
        guard evilTwinSummoned else { return }
        if AppDelegate.duckWindow != nil && AppDelegate.evilDuckWindow != nil {
            seedEvilPhysics()
            return
        }
        guard attempt < 20 else {
            DuckLog.log("[evil] Gave up seeding physics — windows never assigned after 20 tries")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.seedEvilPhysicsWhenReady(attempt: attempt + 1)
        }
    }

    private func stopEvilCreep() {
        evilPhysicsTimer?.invalidate()
        evilPhysicsTimer = nil
        evilVelocity = .zero
        mainVelocity = .zero
        pendingTakeoverSpeech = false
        mainPopoverAttachedLastTick = false
    }

    private func seedEvilPhysics() {
        guard let main = AppDelegate.duckWindow,
              let evil = AppDelegate.evilDuckWindow,
              let screen = main.screen ?? NSScreen.main else { return }

        // Spawn at a random on-screen location, at least 300pt from the main duck
        let visible = screen.visibleFrame
        let size = evil.frame.size
        var origin = NSPoint.zero
        for _ in 0..<20 {
            origin = NSPoint(
                x: CGFloat.random(in: visible.minX...(visible.maxX - size.width)),
                y: CGFloat.random(in: visible.minY...(visible.maxY - size.height))
            )
            let cx = origin.x + size.width / 2
            let cy = origin.y + size.height / 2
            let dx = cx - main.frame.midX
            let dy = cy - main.frame.midY
            if sqrt(dx * dx + dy * dy) > 300 { break }
        }
        evil.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)

        // Random initial velocity — px per tick (1/60s)
        let angle = Double.random(in: 0..<(2 * .pi))
        let speed: CGFloat = CGFloat.random(in: 6...10)
        evilVelocity = CGPoint(x: CGFloat(cos(angle)) * speed, y: CGFloat(sin(angle)) * speed)
        mainVelocity = .zero
    }

    /// Physics tick: evil duck careens around the screen, kicks the main duck on impact.
    private func physicsStep() {
        guard evilTwinSummoned,
              let main = AppDelegate.duckWindow,
              let evil = AppDelegate.evilDuckWindow,
              let screen = evil.screen ?? NSScreen.main else { return }

        let bounds = screen.visibleFrame

        // --- Evil duck: jitter + movement + wall bounce ---
        evilVelocity.x += CGFloat.random(in: -0.6...0.6)
        evilVelocity.y += CGFloat.random(in: -0.6...0.6)
        let evilMax: CGFloat = 14
        let speed = hypot(evilVelocity.x, evilVelocity.y)
        if speed > evilMax {
            evilVelocity.x *= evilMax / speed
            evilVelocity.y *= evilMax / speed
        } else if speed < 3 {
            // Keep it energetic
            let a = Double.random(in: 0..<(2 * .pi))
            evilVelocity.x += CGFloat(cos(a)) * 0.8
            evilVelocity.y += CGFloat(sin(a)) * 0.8
        }

        var eFrame = evil.frame
        eFrame.origin.x += evilVelocity.x
        eFrame.origin.y += evilVelocity.y

        if eFrame.minX < bounds.minX {
            eFrame.origin.x = bounds.minX
            evilVelocity.x = abs(evilVelocity.x)
        } else if eFrame.maxX > bounds.maxX {
            eFrame.origin.x = bounds.maxX - eFrame.width
            evilVelocity.x = -abs(evilVelocity.x)
        }
        if eFrame.minY < bounds.minY {
            eFrame.origin.y = bounds.minY
            evilVelocity.y = abs(evilVelocity.y)
        } else if eFrame.maxY > bounds.maxY {
            eFrame.origin.y = bounds.maxY - eFrame.height
            evilVelocity.y = -abs(evilVelocity.y)
        }
        evil.setFrameOrigin(NSPoint(x: eFrame.origin.x.rounded(), y: eFrame.origin.y.rounded()))

        // --- Main duck: apply velocity, friction, wall bounce ---
        // Skip window-frame updates while any popover is attached as a child —
        // moving the host mid-popover-animation crashes NSPopover internals.
        // BUT we still decay velocity during the pause: if we held it, a long
        // popover period would store up "potential energy" that dumps into the
        // window in a single jump the moment the popover closes (e.g. snapping
        // the duck out from under the user's cursor mid-drag).
        var mFrame = main.frame
        let mainHasPopover = (main.childWindows?.isEmpty == false)

        // On the tick a popover transitions detached → attached, zero any
        // residual velocity outright. Decay alone can leave a sub-pixel tail
        // that survives the pause and leaks out as a tiny shift the moment
        // the popover closes (most visibly after a horizontal kick).
        if mainHasPopover && !mainPopoverAttachedLastTick {
            mainVelocity = .zero
        }
        mainPopoverAttachedLastTick = mainHasPopover

        if mainVelocity.x != 0 || mainVelocity.y != 0 {
            if !mainHasPopover {
                mFrame.origin.x += mainVelocity.x
                mFrame.origin.y += mainVelocity.y
            }
            mainVelocity.x *= 0.93
            mainVelocity.y *= 0.93
            if abs(mainVelocity.x) < 0.15 { mainVelocity.x = 0 }
            if abs(mainVelocity.y) < 0.15 { mainVelocity.y = 0 }

            if !mainHasPopover {
                if mFrame.minX < bounds.minX {
                    mFrame.origin.x = bounds.minX
                    mainVelocity.x = abs(mainVelocity.x) * 0.6
                } else if mFrame.maxX > bounds.maxX {
                    mFrame.origin.x = bounds.maxX - mFrame.width
                    mainVelocity.x = -abs(mainVelocity.x) * 0.6
                }
                if mFrame.minY < bounds.minY {
                    mFrame.origin.y = bounds.minY
                    mainVelocity.y = abs(mainVelocity.y) * 0.6
                } else if mFrame.maxY > bounds.maxY {
                    mFrame.origin.y = bounds.maxY - mFrame.height
                    mainVelocity.y = -abs(mainVelocity.y) * 0.6
                }
                // Round to integer coords — fractional origins get normalized
                // later by AppKit layout passes (e.g. when a popover closes),
                // producing a ~1pt visual jump that's particularly noticeable
                // after a horizontal kick lands at a half-pixel stopping point.
                main.setFrameOrigin(NSPoint(
                    x: mFrame.origin.x.rounded(),
                    y: mFrame.origin.y.rounded()
                ))
            }
        }

        // Fire the queued takeover speech once the duck has settled and no popover
        // is attached — guarantees the new bubble opens against a stable window.
        if pendingTakeoverSpeech && !mainHasPopover &&
           abs(mainVelocity.x) < 0.5 && abs(mainVelocity.y) < 0.5 {
            pendingTakeoverSpeech = false
            speechService.scheduleSpeech(
                ["Get back!", "Not today, clone!", "Away with you!"].randomElement()!,
                kind: .system,
                lane: .manual,
                policy: .latestWins,
                interruptibility: .freelyInterruptible
            )
        }

        // --- Collision: radius-based check on window centers ---
        let mc = CGPoint(x: mFrame.midX, y: mFrame.midY)
        let ec = CGPoint(x: eFrame.midX, y: eFrame.midY)
        let dx = mc.x - ec.x
        let dy = mc.y - ec.y
        let dist = max(hypot(dx, dy), 0.001)
        let hitRadius = (mFrame.width + eFrame.width) * 0.45  // slightly less than sum of half-widths

        if dist < hitRadius {
            // Normal from evil → main
            let nx = dx / dist
            let ny = dy / dist

            // Kick main duck away with a meaty impulse
            let kick: CGFloat = 22
            mainVelocity.x += nx * kick
            mainVelocity.y += ny * kick

            // Evil duck rebounds off the main duck
            let vdotn = evilVelocity.x * nx + evilVelocity.y * ny
            if vdotn > 0 {
                evilVelocity.x -= 2 * vdotn * nx
                evilVelocity.y -= 2 * vdotn * ny
            }
            // Add some chaos to the rebound
            evilVelocity.x += CGFloat.random(in: -2...2)
            evilVelocity.y += CGFloat.random(in: -2...2)

            // Separate so they don't stick
            let overlap = hitRadius - dist + 1
            let separated = NSPoint(x: eFrame.origin.x - nx * overlap, y: eFrame.origin.y - ny * overlap)
            evil.setFrameOrigin(NSPoint(x: separated.x.rounded(), y: separated.y.rounded()))

            // Throttled reaction
            if Date().timeIntervalSince(lastCollisionAt) > 1.1 {
                lastCollisionAt = Date()
                triggerTakeover()
            }
        }
    }

    private func triggerTakeover() {
        evilTakeoverActive = true
        showReaction = true
        DuckLog.log("[evil] Takeover attempt — main duck repels")

        // Dismiss any in-flight speech so its popover closes and the kick can
        // actually move the window. The new "Get back!" bubble is queued via
        // pendingTakeoverSpeech and fires once the duck has settled — see
        // physicsStep. clearQueues: false preserves other scheduled speech.
        speechService.stopSpeaking(reason: .replaced, clearQueues: false)
        pendingTakeoverSpeech = true

        // Flash + inverted main duck expression via the reducer — guarantees a
        // concurrent eval can't wipe the glow during the 1.2s flash.
        withAnimation(.easeInOut(duration: 0.4)) {
            updateExpression()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.evilTakeoverActive = false
            withAnimation(.easeOut(duration: 0.5)) {
                self.showReaction = false
                self.updateExpression()
            }
        }
    }

    private func flashReaction() {
        // Don't stomp on an active takeover flash — it owns showReaction/glow for 1.2s.
        guard !evilTakeoverActive else { return }

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
