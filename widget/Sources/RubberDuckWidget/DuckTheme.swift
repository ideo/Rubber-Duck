// Centralized design tokens for the duck widget.

import SwiftUI

enum DuckTheme {
    // Layout
    static let widgetSize: CGFloat = 120
static let cornerRadius: CGFloat = 18
    static let eyeSize: CGFloat = 10
    static let eyeSpacing: CGFloat = 46

    // Duck palette — accent #ECB947, background #ECEA6E, eyes #4C2016
    /// The duck orange — official app accent color #E69F24.
    static let accent = Color(red: 0.902, green: 0.624, blue: 0.141)
    /// Widget background tint — lighter yellow #ECEA6E
    static let backgroundColor = Color(red: 0.926, green: 0.918, blue: 0.431)
    static let bodyColor = backgroundColor
    static let bodyColorDark = Color(red: 0.895, green: 0.695, blue: 0.248) // subtle shade only
    static let bodyOpacity: Double = 0.75  // Yellow tint over glass — lets desktop bleed through
    static let eyeColor = Color.black
    static let cheekColor = Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.4)

    // Expression colors
    static let positiveGlow = Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.3)   // warm amber
    static let negativeGlow = Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.3)  // cool blue
    static let permissionGlow = Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.5)

    // Animation
    static let reactionDuration: Double = 0.6
    static let springResponse: Double = 0.5
    static let springDamping: Double = 0.6
}
