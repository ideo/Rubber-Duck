// Evil Duck View — The doppelganger that stalks the real duck.
//
// Smaller, darker, menacing. Reads the same eval state but the
// ExpressionEngine inverts its reactions: delighted at bad code,
// sulks at good code. Slowly creeps toward the main duck until
// the main duck repels it.

import SwiftUI

struct EvilDuckView: View {
    @EnvironmentObject var coordinator: DuckCoordinator

    var body: some View {
        ZStack {
            EvilDuckFaceView()

            if coordinator.evilTakeoverActive {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
                    .stroke(DuckTheme.evilAccent, lineWidth: 3)
                    .blur(radius: 2)
                    .transition(.opacity)
            }
        }
        .frame(width: DuckTheme.evilWidgetSize - 8, height: DuckTheme.evilWidgetSize - 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                AppDelegate.banishEvilTwin()
            } label: {
                Label("Leave Tiange's Hollow", systemImage: "xmark.seal.fill")
            }
        }
    }
}

private struct EvilDuckFaceView: View {
    @EnvironmentObject var coordinator: DuckCoordinator

    var body: some View {
        ZStack {
            // Eyes — narrower, angled inward for a menacing scowl
            HStack(spacing: 26) {
                EvilEye(eyeHeight: coordinator.evilExpression.eyeHeight, rotation: -12)
                EvilEye(eyeHeight: coordinator.evilExpression.eyeHeight, rotation: 12)
            }
            .offset(y: -2)

            // Jagged beak (simple triangle for the evil mirror)
            EvilBeakShape()
                .fill(DuckTheme.evilAccent)
                .frame(width: 28, height: 14)
                .offset(y: 18)

            // Mood tint overlay
            if coordinator.evilExpression.glowIntensity > 0 {
                RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
                    .fill(coordinator.evilExpression.glowColor)
                    .opacity(coordinator.evilExpression.glowIntensity * 0.45)
                    .animation(.easeInOut(duration: 0.5), value: coordinator.evilExpression.glowIntensity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: DuckTheme.evilWidgetSize - 8, height: DuckTheme.evilWidgetSize - 8)
        .glassEffect(
            .clear.tint(DuckTheme.evilBodyColor),
            in: RoundedRectangle(cornerRadius: DuckTheme.cornerRadius)
        )
    }
}

private struct EvilEye: View {
    var eyeHeight: Double
    var rotation: Double

    var body: some View {
        Ellipse()
            .fill(DuckTheme.evilEyeColor)
            .frame(width: 9, height: 9 * CGFloat(max(0.2, eyeHeight)))
            .rotationEffect(.degrees(rotation))
            .shadow(color: DuckTheme.evilEyeColor.opacity(0.8), radius: 3)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: eyeHeight)
    }
}

private struct EvilBeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + 4, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 3))
        p.addLine(to: CGPoint(x: rect.midX - 4, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Window Content wrapper (registers window tag like the main duck)

struct EvilDuckWindowContent: View {
    var body: some View {
        EvilDuckView()
            .frame(width: DuckTheme.evilWidgetSize - 8)
            .background(WindowDragArea())
            .background(WindowTagger(tag: AppDelegate.evilDuckWindowTag))
    }
}
