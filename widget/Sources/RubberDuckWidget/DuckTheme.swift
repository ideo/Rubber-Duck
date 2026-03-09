// Centralized design tokens for the duck widget.

import SwiftUI

enum DuckTheme {
    // Layout
    static let widgetSize: CGFloat = 120
    static let cornerRadius: CGFloat = 18
    static let eyeSize: CGFloat = 10
    static let eyeSpacing: CGFloat = 30

    // Duck yellow palette
    static let bodyColor = Color(red: 1.0, green: 0.85, blue: 0.2)
    static let bodyColorDark = Color(red: 0.9, green: 0.75, blue: 0.1)
    static let beakColor = Color(red: 1.0, green: 0.55, blue: 0.1)
    static let eyeColor = Color.black
    static let cheekColor = Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.4)

    // Expression colors
    static let positiveGlow = Color(red: 0.4, green: 1.0, blue: 0.4).opacity(0.3)
    static let negativeGlow = Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.3)
    static let permissionGlow = Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.5)

    // Animation
    static let breathingDuration: Double = 3.0
    static let reactionDuration: Double = 0.6
    static let springResponse: Double = 0.5
    static let springDamping: Double = 0.6
}
