// swift-tools-version: 6.0
import PackageDescription

// KeyVoice — system-wide push-to-talk voice typing for macOS.
// Modules map 1:1 to the plan's components so each can be built and reviewed on its own branch.
let package = Package(
    name: "KeyVoice",
    // Deploy target 14 so WhisperKit works as a fallback; macOS 26 APIs (SpeechAnalyzer) are @available-guarded.
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KeyVoice", targets: ["KeyVoiceApp"])
    ],
    targets: [
        // The frozen contract: protocols, Target, events, the Coordinator spine. Everything depends on this.
        .target(name: "KeyVoiceCore"),

        // One target per work area — filled in on its own feature branch/worktree.
        .target(name: "KeyVoiceHotkey", dependencies: ["KeyVoiceCore"]),   // branch: hotkey
        .target(name: "KeyVoiceInsert", dependencies: ["KeyVoiceCore"]),   // branch: paste
        .target(name: "KeyVoiceAudio",  dependencies: ["KeyVoiceCore"]),   // branch: speech
        .target(name: "KeyVoiceCleanup", dependencies: ["KeyVoiceCore"]),  // branch: cleanup

        // The app shell wires the concrete implementations into the Coordinator.
        .executableTarget(
            name: "KeyVoiceApp",
            dependencies: [
                "KeyVoiceCore", "KeyVoiceHotkey", "KeyVoiceInsert", "KeyVoiceAudio", "KeyVoiceCleanup"
            ]
        )
    ],
    // Language mode 5: this is a UI/system app full of CoreFoundation types that aren't Sendable.
    // Strict 6-mode concurrency here buys warnings, not safety. @MainActor is used where it matters.
    swiftLanguageModes: [.v5]
)
