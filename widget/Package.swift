// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RubberDuckWidget",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "RubberDuckWidget",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
            ],
            path: "Sources/RubberDuckWidget",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
