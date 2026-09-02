// swift-tools-version: 6.0
import PackageDescription

// KeyVoice — system-wide push-to-talk voice typing for macOS.
// Modules map 1:1 to the plan's components so each can be built and reviewed on its own branch.
let package = Package(
    name: "KeyVoice",
    // Deploy target 14 for the app shell. On-device transcription (Apple SpeechAnalyzer) needs macOS 26 and is @available-guarded; below 26 dictation surfaces an error (Apple-only, no fallback).
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KeyVoice", targets: ["KeyVoiceApp"]),
        .library(name: "KeyVoiceDesign", targets: ["KeyVoiceDesign"])
    ],
    targets: [
        // The frozen contract: protocols, Target, events, the Coordinator spine. Everything depends on this.
        .target(name: "KeyVoiceCore"),
        .target(name: "KeyVoiceDesign"),

        // One target per work area — filled in on its own feature branch/worktree.
        .target(name: "KeyVoiceHotkey", dependencies: ["KeyVoiceCore"]),   // branch: hotkey
        .target(name: "KeyVoiceInsert", dependencies: ["KeyVoiceCore"]),   // branch: paste
        .target(name: "KeyVoiceAudio",  dependencies: ["KeyVoiceCore"]),   // branch: speech
        .target(name: "KeyVoiceCleanup", dependencies: ["KeyVoiceCore"]),  // branch: cleanup
        .target(
            name: "KeyVoiceHUD",
            dependencies: ["KeyVoiceCore", "KeyVoiceDesign"],   // floating Aurora HUD (glass + Metal)
            exclude: ["Shaders"],                                // .metal source; precompiled by Scripts/build-shaders.sh
            resources: [.copy("Resources/default.metallib")]     // loaded at runtime via ShaderLibrary(url:)
        ),

        // MVP product modules.
        .target(name: "KeyVoiceStore",   dependencies: ["KeyVoiceCore"]),                    // local history + dictionary + settings (SwiftData)
        .target(name: "KeyVoiceHub",     dependencies: ["KeyVoiceCore", "KeyVoiceStore"]),   // the Hub window: Home / Dictionary / Settings
        .target(name: "KeyVoiceOnboarding", dependencies: ["KeyVoiceCore", "KeyVoiceStore"]),// first-run permission walkthrough

        // The app shell wires the concrete implementations into the Coordinator.
        .executableTarget(
            name: "KeyVoiceApp",
            dependencies: [
                "KeyVoiceCore", "KeyVoiceHotkey", "KeyVoiceInsert", "KeyVoiceAudio", "KeyVoiceCleanup",
                "KeyVoiceHUD", "KeyVoiceStore", "KeyVoiceHub", "KeyVoiceOnboarding"
            ]
        ),

        // Pure-logic unit tests (no hardware needed) so the core is verifiable in CI.
        .testTarget(name: "KeyVoiceCoreTests", dependencies: ["KeyVoiceCore"]),
        .testTarget(name: "KeyVoiceHUDTests", dependencies: ["KeyVoiceHUD"]),
        .testTarget(name: "KeyVoiceAudioTests", dependencies: ["KeyVoiceAudio"])
    ],
    // Language mode 5: this is a UI/system app full of CoreFoundation types that aren't Sendable.
    // Strict 6-mode concurrency here buys warnings, not safety. @MainActor is used where it matters.
    swiftLanguageModes: [.v5]
)
