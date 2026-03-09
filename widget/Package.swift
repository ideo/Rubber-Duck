// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RubberDuckWidget",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RubberDuckWidget",
            path: "Sources/RubberDuckWidget",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
