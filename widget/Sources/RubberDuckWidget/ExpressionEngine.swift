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
    static func reduce(
        scores: EvalScores?,
        permissionPending: Bool,
        evilTakeoverActive: Bool = false
    ) -> DuckExpression {
        // During a takeover flash the main duck glows menacing red regardless
        // of whatever eval just arrived — don't let a concurrent eval wipe it.
        if evilTakeoverActive {
            var expr = DuckExpression()
            expr.glowColor = DuckTheme.evilTakeoverGlow
            expr.glowIntensity = 0.8
            return expr
        }

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
        let sentiment = s.sentiment

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

    /// Evil twin reducer — inverts the emotional valence.
    /// Delights in bad code, sulks at good code. Always menacing.
    static func reduceEvil(
        scores: EvalScores?,
        takeoverActive: Bool
    ) -> DuckExpression {
        guard let s = scores else {
            var neutral = DuckExpression()
            neutral.eyeHeight = 0.55  // narrow by default — always scheming
            if takeoverActive { applyEvilTakeover(&neutral) }
            return neutral
        }

        var expr = DuckExpression()

        // Bad soundness = wide gleeful eyes. Good soundness = narrow scowl.
        expr.eyeHeight = 0.9 - CGFloat(s.soundness) * 0.4  // range 0.5 (good code) to 1.3 (bad code)
        expr.eyeHeight -= CGFloat(s.creativity) * 0.1       // creativity makes it squint harder

        let sentiment = s.sentiment

        // Positive sentiment on main duck = evil twin is angry (bright red glow).
        // Negative sentiment = evil twin is amused (purple sulk).
        if sentiment > 0.2 {
            expr.glowColor = DuckTheme.evilPositiveGlow
            expr.glowIntensity = sentiment
        } else if sentiment < -0.2 {
            expr.glowColor = DuckTheme.evilNegativeGlow
            expr.glowIntensity = abs(sentiment) * 0.8
        }

        // Hue inverts the main duck — where main goes warm, evil goes cold and vice-versa.
        expr.hueShift = sentiment * 25.0

        if takeoverActive { applyEvilTakeover(&expr) }

        return expr
    }

    private static func applyEvilTakeover(_ expr: inout DuckExpression) {
        expr.glowColor = DuckTheme.evilTakeoverGlow
        expr.glowIntensity = 1.0
        expr.eyeHeight = 1.4  // eyes pop wide during takeover
    }
}
