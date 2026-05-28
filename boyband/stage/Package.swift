// swift-tools-version: 6.2
import PackageDescription

// Boy Band — Stage app.
//
// Headless WebSocket server that impersonates the Bambu relay locally for
// the live boy-band performance. Mirrors the widget's zero-dep stack:
// Network.framework for HTTP/WS, CryptoKit for handshake. No external
// dependencies on purpose — show-day reliability beats clever libraries.
//
// Week 1 deliverable: this builds, runs, opens ws://0.0.0.0:3334/duck/{D1..D4},
// and can stream a sine wave to any connected duck for verification.

let package = Package(
    name: "BoyBandStage",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "BoyBandStage",
            path: "Sources/BoyBandStage",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
