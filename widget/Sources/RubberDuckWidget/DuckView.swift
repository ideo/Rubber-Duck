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

    @State private var isBreathing = false
    @State private var isBlinking = false

    var body: some View {
        ZStack {
            // Duck body (liquid glass)
            duckBody
                .rotationEffect(.degrees(
                    coordinator.permissionWobble
                        ? coordinator.expression.rotationAngle
                        : -coordinator.expression.rotationAngle
                ))

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
                    Spacer()
                }
                .frame(width: DuckTheme.widgetSize - 8, height: DuckTheme.widgetSize - 8)
                .transition(.opacity)
            }

            // Status indicators (bottom edge of duck body)
            HStack(spacing: 4) {
                if speechService.isListening {
                    Circle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 6, height: 6)
                }
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
            .offset(y: (DuckTheme.widgetSize - 8) / 2 + 6)
        }
        .frame(width: DuckTheme.widgetSize + 64, height: DuckTheme.widgetSize + 64)
        .contextMenu { duckContextMenu }
        .onAppear {
            isBreathing = true
            scheduleBlink()
        }
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

    // MARK: - Duck Body

    private var duckBody: some View {
        ZStack {
            // Face — positioned from center (on top of glass)
            ZStack {
                // Eyes — on the vertical center line
                HStack(spacing: DuckTheme.eyeSpacing) {
                    duckEye
                    duckEye
                }
                .offset(y: -2 + coordinator.expression.eyeOffsetY)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: evalService.permissionPending)

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
            .regular.tint(DuckTheme.bodyColor),
            in: RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
        )
    }

    // MARK: - Eyes

    @ViewBuilder
    private var duckEye: some View {
        if evalService.permissionPending {
            // Exclamation mark eyes during permission requests
            Text("!")
                .font(.system(size: DuckTheme.eyeSize * 1.8, weight: .black, design: .rounded))
                .foregroundColor(DuckTheme.eyeColor)
                .frame(width: DuckTheme.eyeSize, height: DuckTheme.eyeSize * 1.5)
                .transition(.scale.combined(with: .opacity))
        } else {
            let eyeScale = isBlinking ? 0.1 : coordinator.expression.eyeHeight
            Ellipse()
                .fill(DuckTheme.eyeColor)
                .frame(
                    width: DuckTheme.eyeSize,
                    height: DuckTheme.eyeSize * eyeScale
                )
                .frame(width: DuckTheme.eyeSize, height: DuckTheme.eyeSize * 1.5)
                .animation(
                    .spring(response: 0.1, dampingFraction: 0.9),
                    value: isBlinking
                )
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.7),
                    value: coordinator.expression.eyeHeight
                )
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Beak

    private var beakImage: Image {
        if let url = Bundle.module.url(forResource: "beak", withExtension: "png"),
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
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var duckContextMenu: some View {
        Button("Start Claude Session") { startClaudeSession() }

        Divider()

        if speechService.isListening {
            Button("Stop Listening") { speechService.stopListening() }
        } else {
            Button("Start Listening") { speechService.startListening() }
        }

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

        Text("Server: \(duckServer.isRunning ? "Running" : "Stopped")")

        if !duckServer.isRunning {
            Button("Start Server") { duckServer.start() }
        }

        Divider()

        Button("Quit Duck") {
            duckServer.stop()
            NSApp.terminate(nil)
        }
    }

    // MARK: - Claude Session

    /// Launch Claude Code in Terminal.app inside a tmux session named "duck".
    private func startClaudeSession() {
        let session = DuckConfig.tmuxSession
        let window = DuckConfig.tmuxWindow

        // Try to find repo root by walking up from binary
        var repoRoot = Bundle.main.bundleURL
        for _ in 0..<10 {
            repoRoot = repoRoot.deletingLastPathComponent()
            let serverPath = repoRoot.appendingPathComponent("service/server.py")
            if FileManager.default.fileExists(atPath: serverPath.path) {
                break
            }
        }

        let script = """
        tell application "Terminal"
            activate
            do script "cd \(repoRoot.path) && if ! tmux has-session -t \(session) 2>/dev/null; then tmux new-session -d -s \(session) -n \(window) 'claude'; fi && tmux set-option -t \(session) -w allow-rename off 2>/dev/null && tmux rename-window -t \(session) \(window) 2>/dev/null && tmux attach -t \(session)"
        end tell
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            print("[app] Launched Claude terminal session")
        } catch {
            print("[app] Failed to launch Claude session: \(error)")
        }
    }

    // MARK: - Blink

    private func scheduleBlink() {
        let delay = Double.random(in: 2.5...6.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
                scheduleBlink()
            }
        }
    }
}

