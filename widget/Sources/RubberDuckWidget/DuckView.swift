// Duck View — The visual rubber duck widget.
// A yellow rounded cube with eyes, beak, and animated expressions.
// Pure renderer — side effects are handled by DuckCoordinator.

import SwiftUI

struct DuckView: View {
    @EnvironmentObject var coordinator: DuckCoordinator
    @EnvironmentObject var serviceProcess: ServiceProcess
    @EnvironmentObject var evalService: EvalService
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var serialManager: SerialManager

    @State private var isBreathing = false

    var body: some View {
        ZStack {
            // Glow background
            if coordinator.expression.glowIntensity > 0 {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius + 4)
                    .fill(coordinator.expression.glowColor)
                    .blur(radius: 20)
                    .opacity(coordinator.expression.glowIntensity * 0.6)
            }

            // Duck body
            duckBody
                .scaleEffect(isBreathing ? 1.02 : 0.98)
                .scaleEffect(coordinator.expression.scaleAmount)
                .rotationEffect(.degrees(
                    coordinator.permissionWobble
                        ? coordinator.expression.rotationAngle
                        : -coordinator.expression.rotationAngle
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
                    value: coordinator.expression.scaleAmount
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
        .onChange(of: evalService.evalCount) {
            coordinator.handleNewEval()
        }
        .onChange(of: evalService.permissionRequestId) {
            coordinator.handlePermissionChange()
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
                .hueRotation(.degrees(coordinator.expression.hueShift))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 3)

            // Face
            VStack(spacing: 4) {
                // Eyes
                HStack(spacing: DuckTheme.eyeSpacing) {
                    duckEye
                    duckEye
                }
                .offset(y: coordinator.expression.eyeOffsetY)
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
            if coordinator.showReaction {
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
                height: DuckTheme.eyeSize * coordinator.expression.eyeHeight
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: coordinator.expression.eyeHeight
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
                .offset(y: 4 + coordinator.expression.beakOpen * 6)
                .animation(.spring(response: 0.2), value: coordinator.expression.beakOpen)
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

        Button(coordinator.mode == .critic ? "Switch to Relay Mode" : "Switch to Critic Mode") {
            coordinator.toggleMode()
        }
        Text("Mode: \(coordinator.mode == .critic ? "Critic" : "Relay")")

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
}
