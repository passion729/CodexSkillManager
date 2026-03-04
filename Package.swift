// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexSkillManager",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
        .package(url: "https://github.com/mchakravarty/CodeEditorView", from: "0.15.4"),
    ],
    targets: [
        .executableTarget(
            name: "CodexSkillManager",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "CodeEditorView", package: "CodeEditorView"),
                .product(name: "LanguageSupport", package: "CodeEditorView"),
            ],
            path: "Sources/CodexSkillManager",
            swiftSettings: [
                .define("ENABLE_SPARKLE"),
                .unsafeFlags(["-default-isolation", "MainActor"]),
                .unsafeFlags(["-strict-concurrency=complete"]),
                .unsafeFlags(["-warn-concurrency"]),
            ]),
        .testTarget(
            name: "CodexSkillManagerTests",
            dependencies: ["CodexSkillManager"],
            path: "Tests/CodexSkillManagerTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"]),
            ])
    ]
)
