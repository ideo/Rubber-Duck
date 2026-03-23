// Duck View — The visual rubber duck widget.
// A yellow rounded cube with eyes, beak, and animated expressions.
// Pure renderer — side effects are handled by DuckCoordinator.

import SwiftUI

struct DuckView: View {
    @EnvironmentObject var coordinator: DuckCoordinator
    @EnvironmentObject var duckServer: DuckServer
    @EnvironmentObject var evalService: EvalService
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var serialManager: SerialManager

    @State private var thinkingEyeX: CGFloat = 0
    @State private var thinkingEyeY: CGFloat = 0

    var body: some View {
        ZStack {
            // Duck body (liquid glass — no rotation/scale; transforms break glass refraction)
            duckBody

            // Voice command text — forehead, below status dots
            if !speechService.lastHeard.isEmpty {
                Text(speechService.lastHeard)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(DuckTheme.eyeColor)
                    .lineLimit(1)
                    .offset(y: -(DuckTheme.widgetSize - 8) / 2 + 22)
                    .transition(.opacity)
            }

            // Status indicators (top edge of duck body)
            HStack(spacing: 4) {
                if serialManager.isConnected {
                    Circle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
                if !evalService.isConnected {
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
            }
            .offset(y: -(DuckTheme.widgetSize - 8) / 2 + 10)
        }
        .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
        .contentShape(Rectangle())
        .contextMenu { duckContextMenu }
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
        .onChange(of: coordinator.isThinking) {
            if coordinator.isThinking {
                startThinkingAnimation()
            } else {
                thinkingEyeX = 0
                thinkingEyeY = 0
            }
        }
    }

    // MARK: - Duck Body

    private var duckBody: some View {
        ZStack {
            // Face — positioned from center (on top of glass)
            ZStack {
                // Eyes — on the vertical center line
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

                // Beak — large, below eyes
                duckBeak
                    .offset(y: 20)

                // Cheek blush (visible when happy — flanking the beak)
                if let s = evalService.scores, s.soundness > 0.3 {
                    HStack(spacing: 72) {
                        Ellipse()
                            .fill(DuckTheme.cheekColor)
                            .frame(width: 14, height: 10)
                        Ellipse()
                            .fill(DuckTheme.cheekColor)
                            .frame(width: 14, height: 10)
                    }
                    .offset(y: 18)
                    .opacity(Double(s.soundness) * 0.5)
                }
            }
            .allowsHitTesting(false)

            // Mood tint overlay — on top of glass
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
        // Liquid Glass — real refraction + lensing, tinted duck yellow
        .glassEffect(
            .clear.tint(DuckTheme.bodyColor),
            in: RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
        )
    }

    // MARK: - Beak

    private var beakImage: Image {
        if let url = Resources.bundle.url(forResource: "beak", withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        // Fallback — orange ellipse if PNG missing
        return Image(systemName: "oval.fill")
    }

    private var duckBeak: some View {
        ZStack {
            // Beak PNG — 60% of body width
            beakImage
                .resizable()
                .interpolation(.high)
                .frame(width: 67, height: 34)

            // Mouth gap (visible when speaking/reacting)
            Ellipse()
                .fill(Color(red: 0.15, green: 0.05, blue: 0.02))
                .frame(width: 20, height: 3 + coordinator.expression.beakOpen * 8)
                .offset(y: 4 + coordinator.expression.beakOpen * 3)
                .opacity(coordinator.expression.beakOpen > 0.05 ? 1 : 0)
                .animation(.spring(response: 0.2), value: coordinator.expression.beakOpen)

            // "X" over mouth when duck is turned off
            if !AppDelegate.isDuckActive {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DuckTheme.eyeColor.opacity(0.6))
                    .offset(y: 4)
            }
        }
    }

    // MARK: - Context Menu (lean — settings live in menu bar 🦆)

    @ViewBuilder
    private var duckContextMenu: some View {
        // Mode selector — mic behavior is baked into each mode
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
                speechService.speak("Wildcard mode. I'll pick a voice each time.", skipChirpWait: true)
            } label: {
                let active = speechService.isWildcardMode
                Label(active ? "✓ Wildcard (AI picks)" : "Wildcard (AI picks)", systemImage: "shuffle")
            }

            Divider()

            ForEach(DuckVoices.main, id: \.sayName) { voice in
                Button {
                    speechService.ttsVoice = voice.sayName
                    speechService.speak(voice.preview, skipChirpWait: true)
                } label: {
                    Text(speechService.ttsVoice == voice.sayName && !speechService.isWildcardMode ? "✓ \(voice.label)" : voice.label)
                }
            }

            Divider()

            ForEach(DuckVoices.classic, id: \.sayName) { voice in
                Button {
                    speechService.ttsVoice = voice.sayName
                    speechService.speak(voice.preview, skipChirpWait: true)
                } label: {
                    Text(speechService.ttsVoice == voice.sayName && !speechService.isWildcardMode ? "✓ \(voice.label)" : voice.label)
                }
            }

            Divider()

            ForEach(DuckVoices.specialFX, id: \.sayName) { voice in
                Button {
                    speechService.ttsVoice = voice.sayName
                    speechService.speak(voice.preview, skipChirpWait: true)
                } label: {
                    Text(speechService.ttsVoice == voice.sayName && !speechService.isWildcardMode ? "✓ \(voice.label)" : voice.label)
                }
            }

            Divider()

            ForEach(DuckVoices.british, id: \.sayName) { voice in
                Button {
                    speechService.ttsVoice = voice.sayName
                    speechService.speak(voice.preview, skipChirpWait: true)
                } label: {
                    Text(speechService.ttsVoice == voice.sayName && !speechService.isWildcardMode ? "✓ \(voice.label)" : voice.label)
                }
            }
        } label: {
            let voiceLabel = speechService.isWildcardMode
                ? "Wildcard"
                : (DuckVoices.all.first { $0.sayName == speechService.ttsVoice }?.label ?? speechService.ttsVoice)
            Label("Voice: \(voiceLabel)", systemImage: "waveform")
        }

        Divider()

        // Get Started — always available, guides setup
        Button {
            coordinator.runSetupGuide()
        } label: {
            Label("Get Started", systemImage: "sparkles")
        }

        if !duckServer.pluginConnected {
            Button {
                PluginInstaller.install()
            } label: {
                Label("Install Claude Plugin", systemImage: "puzzlepiece.extension.fill")
            }
        }

        Button {
            CLISession.launch()
        } label: {
            Label("Launch Claude Code", systemImage: "terminal.fill")
        }

        Divider()

        Button {
            duckServer.stop()
            NSApp.terminate(nil)
        } label: {
            Label("Quit Duck, Duck, Duck", systemImage: "xmark.square.fill")
        }
    }

    // Blink logic moved to DuckEyesView (isolated @State prevents menu flicker)

    // 6-position grid: 3 top row, 3 bottom row. Bottom-center is home.
    private static let eyePositions: [(x: CGFloat, y: CGFloat)] = [
        (-4, -3), (0, -3), (4, -3),   // top row
        (-4,  0), (0,  0), (4,  0),   // bottom row (center = home)
    ]

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

