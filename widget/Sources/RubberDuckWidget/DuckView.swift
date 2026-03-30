// Duck View — The visual rubber duck widget.
// A yellow rounded cube with eyes, beak, and animated expressions.
// Pure renderer — side effects are handled by DuckCoordinator.

import SwiftUI

struct DuckView: View {
    // NOTE: No @EnvironmentObject here. All observable state is read inside
    // isolated child views. This prevents body re-evaluation from dismissing .contextMenu.

    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Duck body (liquid glass face — isolated)
            DuckFaceView()

            // Wing overlay (isolated — reads isSpeaking internally)
            DuckWingsView(isHovering: isHovering)
                .zIndex(10)

            // Status indicators + popovers (isolated — reads speech/serial/eval state internally)
            DuckStatusOverlay()
        }
        .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .contextMenu { DuckContextMenu() }
    }

}

// MARK: - Context Menu (isolated — reads coordinator/speechService/duckServer internally)

private struct DuckContextMenu: View {
    @EnvironmentObject var coordinator: DuckCoordinator
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var duckServer: DuckServer

    var body: some View {
        // Update notifications (top of menu)
        if coordinator.isAppUpdateAvailable, let version = coordinator.appUpdateVersion {
            Button {
                if let urlStr = coordinator.appUpdateURL, let url = URL(string: urlStr) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Update Available: v\(version)", systemImage: "arrow.down.circle")
            }
        }
        if coordinator.isPluginStale {
            Button {
                PluginInstaller.install()
            } label: {
                Label("Plugin Update Available", systemImage: "puzzlepiece.extension.fill")
            }
        }
        if coordinator.isAppUpdateAvailable || coordinator.isPluginStale {
            Divider()
        }

        // Mode selector
        Menu {
            ForEach(DuckMode.allCases, id: \.rawValue) { mode in
                Button {
                    coordinator.setMode(mode)
                } label: {
                    Label(mode.label, systemImage: mode.iconName)
                }
            }
        } label: {
            Label(coordinator.mode.label, systemImage: coordinator.mode.iconName)
        }

        // Voice picker
        Menu {
            Button {
                speechService.ttsVoice = DuckVoices.wildcardSayName
                speechService.scheduleSpeech(
                    "Wildcard mode. I'll pick a voice each time.",
                    kind: .preview,
                    lane: .manual,
                    policy: .latestWins,
                    interruptibility: .freelyInterruptible,
                    skipChirpWait: true
                )
            } label: {
                let active = speechService.isWildcardMode
                Label(active ? "✓ Wildcard (AI picks)" : "Wildcard (AI picks)", systemImage: "shuffle")
            }

            Divider()

            ForEach([DuckVoices.main, DuckVoices.classic, DuckVoices.specialFX, DuckVoices.british].indices, id: \.self) { groupIdx in
                if groupIdx > 0 { Divider() }
                ForEach([DuckVoices.main, DuckVoices.classic, DuckVoices.specialFX, DuckVoices.british][groupIdx], id: \.sayName) { voice in
                    Button {
                        speechService.ttsVoice = voice.sayName
                        speechService.scheduleSpeech(
                            voice.preview,
                            kind: .preview,
                            lane: .manual,
                            scopeID: "voice-preview",
                            policy: .latestWins,
                            interruptibility: .freelyInterruptible,
                            skipChirpWait: true
                        )
                    } label: {
                        Text(speechService.ttsVoice == voice.sayName && !speechService.isWildcardMode ? "✓ \(voice.label)" : voice.label)
                    }
                }
            }
        } label: {
            let voiceLabel = speechService.isWildcardMode
                ? "Wildcard"
                : (DuckVoices.all.first { $0.sayName == speechService.ttsVoice }?.label ?? speechService.ttsVoice)
            Label("Voice: \(voiceLabel)", systemImage: "waveform")
        }

        // Intelligence picker
        Menu {
            Button {
                DuckConfig.evalProvider = .foundation
            } label: {
                Label(
                    DuckConfig.evalProvider == .foundation ? "✓ Apple Foundation Model" : "Apple Foundation Model",
                    systemImage: "apple.logo"
                )
            }
            Button {
                guard DuckConfig.ensureAPIKey() else { return }
                DuckConfig.evalProvider = .anthropic
            } label: {
                Label(
                    DuckConfig.evalProvider == .anthropic ? "✓ Claude Haiku" : "Claude Haiku",
                    systemImage: "asterisk"
                )
            }
            Button {
                guard DuckConfig.ensureGeminiAPIKey() else { return }
                DuckConfig.evalProvider = .gemini
            } label: {
                Label(
                    DuckConfig.evalProvider == .gemini ? "✓ Gemini" : "Gemini",
                    systemImage: "sparkle"
                )
            }
        } label: {
            Label("Intelligence", systemImage: "brain.fill")
        }

        Divider()

        Button {
            CLISession.launch()
        } label: {
            Label("Launch Claude Code", systemImage: "terminal.fill")
        }

        Divider()

        if AppDelegate.isDuckActive {
            Button {
                AppDelegate.turnOff()
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
        } else {
            Button {
                AppDelegate.turnOn()
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
        }

        Button {
            duckServer.stop()
            NSApp.terminate(nil)
        } label: {
            Label("Quit", systemImage: "xmark")
        }
    }
}

// MARK: - Duck Status Overlay (isolated — reads all frequently-changing state)

/// Owns status indicators, voice command popover, and speech bubble.
/// Isolated from DuckView so rapid @Published changes (lastHeard, currentUtterance,
/// isWakeActive, evalCount) don't re-evaluate the parent body and dismiss .contextMenu.
private struct DuckStatusOverlay: View {
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var evalService: EvalService
    @EnvironmentObject var serialManager: SerialManager
    @EnvironmentObject var coordinator: DuckCoordinator

    // Proper @State bindings for popovers — .constant() with dynamic values
    // causes crashes when the popover animates while the value changes underneath.
    @State private var showVoicePopover = false
    @State private var showSpeechBubble = false

    private var speechBubbleVisible: Bool {
        guard !speechService.currentUtterance.isEmpty else { return false }
        if speechService.isSilent || DuckConfig.volume <= 0 { return true }
        if speechService.audioPath == .local && AudioDeviceDiscovery.isSystemOutputMuted() {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            // Status indicators (top edge)
            // Red: mic hot (wake/conversation, but NOT while duck is speaking — mic is muted then)
            // Orange: hardware connected
            HStack(spacing: 4) {
                if (speechService.isWakeActive || speechService.isInConversation) && !speechService.isSpeaking {
                    Image(systemName: "square.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                } else if serialManager.isConnected {
                    Image(systemName: "square.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DuckTheme.accent)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: speechService.isWakeActive || speechService.isInConversation)
            .popover(isPresented: $showVoicePopover, arrowEdge: .top) {
                VoiceCommandBubbleView(text: speechService.lastHeard)
            }
            .offset(y: -(DuckTheme.widgetSize - 8) / 2 + 10)
        }
        .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
        .popover(isPresented: $showSpeechBubble, arrowEdge: .bottom) {
            SpeechBubbleView(text: speechService.currentUtterance)
                .padding(4)
        }
        .onChange(of: speechService.lastHeard) {
            showVoicePopover = !speechService.lastHeard.isEmpty
        }
        .onChange(of: speechBubbleVisible) {
            showSpeechBubble = speechBubbleVisible
        }
        .allowsHitTesting(false)
        .onChange(of: evalService.evalCount) {
            coordinator.handleNewEval()
        }
        .onChange(of: evalService.permissionRequestId) {
            coordinator.handlePermissionChange()
        }
        .onChange(of: evalService.permissionPending) {
            if !evalService.permissionPending {
                coordinator.handlePermissionResolved()
            }
        }
    }
}

// MARK: - Duck Face (isolated from parent to prevent context menu flicker)

/// Owns ALL face animation state: eyes, beak, thinking eye movement, glow, flash.
/// Uses @EnvironmentObject to observe state directly — parent DuckView never re-renders
/// due to face animations, so context menus stay open.
private struct DuckFaceView: View {
    @EnvironmentObject var coordinator: DuckCoordinator
    @EnvironmentObject var evalService: EvalService
    @EnvironmentObject var speechService: SpeechService

    @State private var thinkingEyeX: CGFloat = 0
    @State private var thinkingEyeY: CGFloat = 0

    // 6-position grid for thinking eye movement
    private static let eyePositions: [(x: CGFloat, y: CGFloat)] = [
        (-4, -3), (0, -3), (4, -3),
        (-4,  0), (0,  0), (4,  0),
    ]

    var body: some View {
        ZStack {
            // Face
            ZStack {
                // Eyes
                DuckEyesView(
                    permissionPending: evalService.permissionPending,
                    eyeHeight: coordinator.expression.eyeHeight,
                    sentiment: evalService.scores?.sentiment ?? 0
                )
                .offset(
                    x: coordinator.isThinking && !evalService.permissionPending
                        ? thinkingEyeX : 0,
                    y: -2 + coordinator.expression.eyeOffsetY
                        + (coordinator.isThinking && !evalService.permissionPending
                           ? thinkingEyeY : 0)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: evalService.permissionPending)
                .animation(.spring(response: 0.12, dampingFraction: 0.5), value: thinkingEyeX)
                .animation(.spring(response: 0.12, dampingFraction: 0.5), value: thinkingEyeY)

                // Beak
                DuckBeakView(
                    isSpeaking: speechService.isSpeaking
                )
                .offset(y: 20)
            }
            .allowsHitTesting(false)

            // Mood tint overlay
            if coordinator.expression.glowIntensity > 0 {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
                    .fill(coordinator.expression.glowColor)
                    .opacity(coordinator.expression.glowIntensity * 0.3)
                    .animation(.easeInOut(duration: 0.5), value: coordinator.expression.glowIntensity)
                    .allowsHitTesting(false)
            }

            // Flash overlay on new eval
            if coordinator.showReaction {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
                    .fill(Color.white.opacity(0.3))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
        .glassEffect(
            .clear.tint(DuckTheme.bodyColor),
            in: RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
        )
        .onChange(of: coordinator.isThinking) {
            if coordinator.isThinking {
                startThinkingAnimation()
            } else {
                thinkingEyeX = 0
                thinkingEyeY = 0
            }
        }
    }

    private func startThinkingAnimation() {
        guard coordinator.isThinking else { return }
        let pos = Self.eyePositions.randomElement()!
        thinkingEyeX = pos.x
        thinkingEyeY = pos.y
        let delay = Double.random(in: 0.3...0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            startThinkingAnimation()
        }
    }
}

// MARK: - Duck Eyes (isolated blink state)

/// Both eyes in one struct so they share a single blink timer and stay in sync.
/// Isolated from parent view to prevent context menu flicker on blink.
/// On negative sentiment, eyes desync for a goofy confused look.
private struct DuckEyesView: View {
    var permissionPending: Bool
    var eyeHeight: Double
    var sentiment: Double

    @State private var leftBlinking = false
    @State private var rightBlinking = false

    /// Whether eyes blink together or independently.
    private var desynced: Bool { sentiment < -0.2 }

    var body: some View {
        HStack(spacing: DuckTheme.eyeSpacing) {
            eye(isBlinking: leftBlinking)
            eye(isBlinking: rightBlinking)
        }
        .onAppear { scheduleBlink() }
    }

    @ViewBuilder
    private func eye(isBlinking: Bool) -> some View {
        if permissionPending {
            Text("!")
                .font(.system(size: DuckTheme.eyeSize * 1.8, weight: .black, design: .rounded))
                .foregroundColor(DuckTheme.eyeColor)
                .frame(width: DuckTheme.eyeSize, height: DuckTheme.eyeSize * 1.5)
                .transition(.scale.combined(with: .opacity))
        } else {
            let scale = isBlinking ? 0.1 : eyeHeight
            Ellipse()
                .fill(DuckTheme.eyeColor)
                .frame(
                    width: DuckTheme.eyeSize,
                    height: DuckTheme.eyeSize * scale
                )
                .frame(width: DuckTheme.eyeSize, height: DuckTheme.eyeSize * 1.5)
                .animation(.spring(response: 0.1, dampingFraction: 0.9), value: isBlinking)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: eyeHeight)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...6.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Both eyes blink together
            leftBlinking = true
            rightBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                leftBlinking = false
                rightBlinking = false

                if desynced {
                    // Extra wink on one eye for the confused look
                    let extraDelay = Double.random(in: 0.3...0.8)
                    DispatchQueue.main.asyncAfter(deadline: .now() + extraDelay) {
                        let useLeft = Bool.random()
                        if useLeft { leftBlinking = true } else { rightBlinking = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            leftBlinking = false
                            rightBlinking = false
                            scheduleBlink()
                        }
                    }
                } else {
                    scheduleBlink()
                }
            }
        }
    }
}

// MARK: - Duck Beak (isolated flutter state)

/// Isolated from parent view to prevent context menu dismissal on mouth animation.
/// Same pattern as DuckEyesView — uses @State for the flutter timer.
private struct DuckBeakView: View {
    var isSpeaking: Bool

    @State private var flutterOpen: CGFloat = 0
    @State private var flutterTimer: Timer?

    private static let cachedBeakImage: Image = {
        if let url = Resources.bundle.url(forResource: "beak", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "oval.fill")
    }()

    var body: some View {
        ZStack {
            Self.cachedBeakImage
                .resizable()
                .interpolation(.high)
                .frame(width: 67, height: 34)

            Ellipse()
                .fill(Color(red: 0.15, green: 0.05, blue: 0.02))
                .frame(width: 20, height: 4 + flutterOpen * 8)
                .offset(x: -1, y: -1 + flutterOpen * 3)
                .opacity(flutterOpen > 0.05 ? 1 : 0)
                .animation(.spring(response: 0.2), value: flutterOpen)
        }
        .onChange(of: isSpeaking) {
            if isSpeaking {
                startFlutter()
            } else {
                stopFlutter()
            }
        }
    }

    private func startFlutter() {
        flutterTimer?.invalidate()
        flutterTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.1)) {
                    flutterOpen = CGFloat.random(in: 0.2...0.8)
                }
            }
        }
    }

    private func stopFlutter() {
        flutterTimer?.invalidate()
        flutterTimer = nil
        withAnimation(.spring(response: 0.2)) {
            flutterOpen = 0
        }
    }
}

// MARK: - Duck Wings (isolated to prevent context menu flicker)

/// Isolated from parent DuckView so isSpeaking changes don't re-render the parent.
private struct DuckWingsView: View {
    var isHovering: Bool
    @EnvironmentObject var speechService: SpeechService

    private var wingsVisible: Bool {
        (isHovering && speechService.isSpeaking) || !AppDelegate.isDuckActive
    }

    var body: some View {
        ZStack {
            // Left wing
            DuckWingShape()
                .fill(.clear)
                .glassEffect(
                    .clear.tint(DuckTheme.bodyColor),
                    in: DuckWingShape()
                )
                .frame(width: 84, height: 62)
                .offset(x: -16, y: wingsVisible ? 32 : 60)
                .opacity(wingsVisible ? 1 : 0)
            // Right wing (mirrored)
            DuckWingShape()
                .fill(.clear)
                .glassEffect(
                    .clear.tint(DuckTheme.bodyColor),
                    in: DuckWingShape()
                )
                .frame(width: 84, height: 62)
                .scaleEffect(x: -1, y: 1)
                .offset(x: 16, y: wingsVisible ? 32 : 60)
                .opacity(wingsVisible ? 1 : 0)
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovering)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: speechService.isSpeaking)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: AppDelegate.isDuckActive)
    }
}

// MARK: - Duck Wing Shape

/// SwiftUI Shape converted from left-wing-stroke.svg (viewBox 0 0 80 59).
/// Originates from bottom-left, sweeps up-right with a feathered curve.
private struct DuckWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 80.0
        let sy = rect.height / 59.0
        var p = Path()
        p.move(to: CGPoint(x: 71.678 * sx, y: 0.967 * sy))
        p.addLine(to: CGPoint(x: 0.750 * sx, y: 50.207 * sy))
        p.addLine(to: CGPoint(x: 0.750 * sx, y: 58.066 * sy))
        p.addLine(to: CGPoint(x: 70.218 * sx, y: 58.085 * sy))
        p.addCurve(
            to: CGPoint(x: 71.111 * sx, y: 31.745 * sy),
            control1: CGPoint(x: 86.955 * sx, y: 45.524 * sy),
            control2: CGPoint(x: 71.111 * sx, y: 31.745 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 71.678 * sx, y: 0.967 * sy),
            control1: CGPoint(x: 71.111 * sx, y: 31.745 * sy),
            control2: CGPoint(x: 87.572 * sx, y: 16.373 * sy)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Speech Bubble

/// Shows the duck's current utterance as a visual transcript above the face.
/// Appears when the duck speaks, fades when speech ends.
private struct SpeechBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: 200)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .allowsHitTesting(false)
    }
}

// MARK: - Voice Command Popover

/// Shows voice command text in a popover beside the duck, updating live as STT streams in.
/// Uses `.trailing` arrowEdge so it appears to the side, not covering the face.
private struct VoiceCommandBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: 280)
            .padding(8)
    }
}

