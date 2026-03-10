// Expression Engine — Reducer mapping eval dimensions to visual state.
// This is the widget's equivalent of ServoControl.ino / LEDControl.ino.

import SwiftUI

struct DuckExpression {
    // Eye
    var eyeHeight: CGFloat = 1.0       // 1.0 = round, 0.3 = squint, 1.5 = wide
    var eyeOffsetY: CGFloat = 0.0      // Vertical eye position shift

    // Body (no rotation/scale — transforms break liquid glass refraction)
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

        // --- Creativity → Eye widening ---
        // High creativity = wide curious eyes
        expr.eyeHeight += CGFloat(s.creativity) * 0.2  // adds up to ±0.2

        // --- Beak opens when reaction exists ---
        if let reaction = s.reaction, !reaction.isEmpty {
            expr.beakOpen = 0.3
        }

        // --- Sentiment → body warmth + glow ---
        let sentiment = (
            s.soundness * 0.3 +
            s.elegance * 0.25 +
            s.creativity * 0.2 +
            s.ambition * 0.15 -
            s.risk * 0.1
        )

        // Positive = warmer (toward orange), negative = cooler (toward green)
        // Negate because hueRotation positive = green, negative = orange
        expr.hueShift = sentiment * -15.0  // ±15 degrees

        if sentiment > 0.2 {
            expr.glowColor = DuckTheme.positiveGlow  // warm
            expr.glowIntensity = sentiment
        } else if sentiment < -0.2 {
            expr.glowColor = DuckTheme.negativeGlow  // cool
            expr.glowIntensity = abs(sentiment)
        }

        // --- Permission override ---
        // Eyes become "!" in DuckView; just add a subtle warm glow here
        if permissionPending {
            expr.glowColor = DuckTheme.permissionGlow
            expr.glowIntensity = 0.4
        }

        return expr
    }
}
