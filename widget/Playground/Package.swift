// swift-tools-version: 6.2
import PackageDescription

// Isolated playground package for testing Foundation Models eval prompts.
// Open THIS Package.swift in Xcode — #Playground blocks work in library targets
// without needing ENABLE_DEBUG_DYLIB.
// Does NOT touch the main RubberDuckWidget build at all.

let package = Package(
    name: "LLMPlayground",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "LLMPlayground",
            path: "Sources/LLMPlayground",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
