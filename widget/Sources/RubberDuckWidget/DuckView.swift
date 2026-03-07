// Duck View — The visual rubber duck widget.
// A yellow rounded cube with eyes, beak, and animated expressions.

import SwiftUI

struct DuckView: View {
    @EnvironmentObject var serviceProcess: ServiceProcess
    @EnvironmentObject var evalService: EvalService
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var serialManager: SerialManager

    @State private var isBreathing = false
    @State private var expression = DuckExpression()
    @State private var showReaction = false
    @State private var permissionWobble = false

    var body: some View {
        ZStack {
            // Glow background
            if expression.glowIntensity > 0 {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius + 4)
                    .fill(expression.glowColor)
                    .blur(radius: 20)
                    .opacity(expression.glowIntensity * 0.6)
            }

            // Duck body
            duckBody
                .scaleEffect(isBreathing ? 1.02 : 0.98)
                .scaleEffect(expression.scaleAmount)
                .rotationEffect(.degrees(
                    permissionWobble
                        ? expression.rotationAngle
                        : -expression.rotationAngle
                ))
                .animation(
                    .easeInOut(duration: DuckTheme.breathingDuration)
                    .repeatForever(autoreverses: true),
                    value: isBreathing
                )
                .animation(
                    .spring(
                        response: DuckTheme.springResponse,
                        dampingFraction: DuckTheme.springDamping
                    ),
                    value: expression.scaleAmount
                )

            // "Heard you" overlay when wake word detected
            if !speechService.lastHeard.isEmpty {
                VStack {
                    Text(speechService.lastHeard)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .lineLimit(1)
                        .padding(.top, 4)
                    Spacer()
                }
                .transition(.opacity)
            }

            // Status indicators (bottom edge)
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    // Listening indicator
                    if speechService.isListening {
                        Circle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                    // Serial indicator
                    if serialManager.isConnected {
                        Circle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                    // Disconnected indicator
                    if !evalService.isConnected {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(width: DuckTheme.widgetSize, height: DuckTheme.widgetSize)
        .contextMenu { duckContextMenu }
        .onAppear {
            isBreathing = true
        }
        .onChange(of: evalService.scores?.reaction) {
            onNewEval()
        }
        .onChange(of: evalService.permissionRequestId) {
            updateExpression()
            if evalService.permissionPending {
                startPermissionWobble()
                speechService.askPermission(toolName: evalService.permissionTool,
                                            options: evalService.permissionOptions)
            }
        }
    }

    // MARK: - Duck Body

    private var duckBody: some View {
        ZStack {
            // Body shape — rounded yellow cube
            RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [DuckTheme.bodyColor, DuckTheme.bodyColorDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .hueRotation(.degrees(expression.hueShift))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 3)

            // Face
            VStack(spacing: 4) {
                // Eyes
                HStack(spacing: DuckTheme.eyeSpacing) {
                    duckEye
                    duckEye
                }
                .offset(y: expression.eyeOffsetY)
                .padding(.top, 28)

                // Beak
                duckBeak
                    .padding(.top, 2)

                Spacer()
            }

            // Cheek blush (visible when happy)
            if let s = evalService.scores, s.soundness > 0.3 {
                HStack(spacing: 36) {
                    Circle()
                        .fill(DuckTheme.cheekColor)
                        .frame(width: 14, height: 10)
                    Circle()
                        .fill(DuckTheme.cheekColor)
                        .frame(width: 14, height: 10)
                }
                .offset(y: 6)
                .opacity(Double(s.soundness) * 0.5)
            }

            // Flash overlay on new eval
            if showReaction {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
                    .fill(Color.white.opacity(0.3))
                    .transition(.opacity)
            }
        }
        .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
    }

    // MARK: - Eyes

    private var duckEye: some View {
        Ellipse()
            .fill(DuckTheme.eyeColor)
            .frame(
                width: DuckTheme.eyeSize,
                height: DuckTheme.eyeSize * expression.eyeHeight
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: expression.eyeHeight
            )
    }

    // MARK: - Beak

    private var duckBeak: some View {
        ZStack {
            // Top beak
            Ellipse()
                .fill(DuckTheme.beakColor)
                .frame(width: 20, height: 10)

            // Bottom beak (opens with expression)
            Ellipse()
                .fill(DuckTheme.beakColor.opacity(0.8))
                .frame(width: 16, height: 6)
                .offset(y: 4 + expression.beakOpen * 6)
                .animation(.spring(response: 0.2), value: expression.beakOpen)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var duckContextMenu: some View {
        if speechService.isListening {
            Button("Stop Listening") { speechService.stopListening() }
        } else {
            Button("Start Listening") { speechService.startListening() }
        }

        Divider()

        Text("Mic: \(speechService.selectedMicName.isEmpty ? "None" : speechService.selectedMicName)")

        if serialManager.isConnected {
            Text("Teensy: \(serialManager.portName)")
        } else {
            Text("Teensy: Disconnected")
        }

        Text("Service: \(serviceProcess.isRunning ? "Running" : "Stopped")")
        Text("WebSocket: \(evalService.isConnected ? "Connected" : "Disconnected")")

        if !serviceProcess.isRunning {
            Button("Start Service") { serviceProcess.startService() }
        }

        Divider()

        Button("Start Claude Session") { serviceProcess.startClaudeSession() }

        Divider()

        Button("Quit Duck") {
            serviceProcess.stopService()
            NSApp.terminate(nil)
        }
    }

    // MARK: - Eval Reaction

    private func onNewEval() {
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

    // MARK: - Expression Updates

    private func updateExpression() {
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
                showReaction = false
            }
        }

        // Open beak briefly when speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.2)) {
                expression.beakOpen = 0.0
            }
        }
    }

    private func startPermissionWobble() {
        withAnimation(
            .easeInOut(duration: 0.15)
            .repeatCount(6, autoreverses: true)
        ) {
            permissionWobble.toggle()
        }
    }
}
