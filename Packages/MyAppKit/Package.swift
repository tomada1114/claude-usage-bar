// swift-tools-version: 6.2
import PackageDescription

/// Strictness from day one: Swift 6 language mode (data-race safety as errors)
/// and every warning treated as an error. There is never a "legacy" codebase.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "MyAppKit",
    // The language the String Catalog is written in, and the one a reader falls back to
    // when the catalog lacks theirs. A second language is an ADR (`localizing-the-app`).
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MyAppCore", targets: ["MyAppCore"]),
        .library(name: "MyAppUI", targets: ["MyAppUI"]),
        .library(name: "MyAppPlatform", targets: ["MyAppPlatform"]),
    ],
    targets: [
        // Core owns the user-facing wording (it returns `LocalizedStringResource`), so the
        // one String Catalog lives here. xcodebuild compiles it into Core's resource
        // bundle; `swift build` only copies it, so tests read English from `defaultValue`.
        .target(
            name: "MyAppCore",
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: strictSettings,
        ),
        .target(name: "MyAppUI", dependencies: ["MyAppCore"], swiftSettings: strictSettings),
        // OS-integration adapters behind Core-declared ports. Depends on MyAppCore
        // only: it must not see MyAppUI, and MyAppUI must not see it (enforced by
        // ArchitectureBoundaryTests, since SwiftPM cannot stop a system framework
        // import and this graph alone would not stop a later dependency edit).
        .target(name: "MyAppPlatform", dependencies: ["MyAppCore"], swiftSettings: strictSettings),
        .testTarget(
            name: "MyAppCoreTests",
            dependencies: ["MyAppCore"],
            swiftSettings: strictSettings,
        ),
        // Local-machine tests for the adapters: they talk to the real OS, which a CI
        // runner cannot (no logged-in GUI session, and no way to grant Accessibility,
        // Input Monitoring, or Screen Recording). Every suite here carries the
        // `.requiresLocalMachine` trait, so the tests are reported as skipped unless
        // RUN_LOCAL_MACHINE_TESTS=1 is set — `just test-local` sets it. Linking
        // MyAppPlatform does not put it inside the coverage floor: scripts/coverage.sh
        // measures Sources/MyAppCore and nothing else.
        .testTarget(
            name: "MyAppPlatformTests",
            dependencies: ["MyAppPlatform", "MyAppCore"],
            swiftSettings: strictSettings,
        ),
    ],
)
