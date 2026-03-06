// Expression Engine — Reducer mapping eval dimensions to visual state.
// This is the widget's equivalent of ServoControl.ino / LEDControl.ino.

import SwiftUI

struct DuckExpression {
    // Eye
    var eyeHeight: CGFloat = 1.0       // 1.0 = round, 0.3 = squint, 1.5 = wide
    var eyeOffsetY: CGFloat = 0.0      // Vertical eye position shift

    // Body
    var scaleAmount: CGFloat = 1.0     // Breathing / pulse
    var rotationAngle: Double = 0.0    // Shake / tilt
    var hueShift: Double = 0.0         // Color temperature shift

    // Glow
    var glowColor: Color = .clear
    var glowIntensity: Double = 0.0

    // Beak
    var beakOpen: CGFloat = 0.0        // 0 = closed, 1 = open
}

enum ExpressionEngine {
    /// Map evaluation scores to a duck expression.
    static func reduce(scores: EvalScores?, permissionPending: Bool) -> DuckExpression {
        guard let s = scores else {
            return DuckExpression() // neutral
        }

        var expr = DuckExpression()

        // --- Soundness → Eye Shape ---
        // Good soundness = round happy eyes, bad = squint
        expr.eyeHeight = 1.0 + CGFloat(s.soundness) * 0.4  // 0.6 to 1.4

        // --- Elegance → Transition smoothness (handled by animation, not state) ---
        // (DuckView uses elegance to pick spring damping)

        // --- Creativity → Hue shift ---
        // High creativity = warmer/saturated, low = duller
        expr.hueShift = s.creativity * 15.0  // ±15 degrees

        // --- Ambition → Scale/breathing intensity ---
        // Higher ambition = bigger presence
        expr.scaleAmount = 1.0 + CGFloat(abs(s.ambition)) * 0.08  // 1.0 to 1.08

        // --- Risk → Shake/wobble ---
        if s.risk > 0.3 {
            expr.rotationAngle = Double(s.risk) * 5.0  // Up to ±5 degrees
        }

        // --- Beak opens when reaction exists ---
        if let reaction = s.reaction, !reaction.isEmpty {
            expr.beakOpen = 0.3
        }

        // --- Glow based on overall sentiment ---
        let sentiment = (
            s.soundness * 0.3 +
            s.elegance * 0.25 +
            s.creativity * 0.2 +
            s.ambition * 0.15 -
            s.risk * 0.1
        )

        if sentiment > 0.2 {
            expr.glowColor = DuckTheme.positiveGlow
            expr.glowIntensity = sentiment
        } else if sentiment < -0.2 {
            expr.glowColor = DuckTheme.negativeGlow
            expr.glowIntensity = abs(sentiment)
        }

        // --- Permission override ---
        if permissionPending {
            expr.eyeHeight = 1.5  // Wide eyes
            expr.rotationAngle = 3.0  // Nervous tilt
            expr.glowColor = DuckTheme.permissionGlow
            expr.glowIntensity = 0.8
            expr.scaleAmount = 1.02
        }

        return expr
    }
}
