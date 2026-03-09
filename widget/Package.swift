// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RubberDuckWidget",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "RubberDuckWidget",
            path: "Sources/RubberDuckWidget",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
