import Foundation
import Observation

/// User-editable settings, persisted in `UserDefaults`. Observable so SwiftUI Settings binds
/// straight to it; the app shell reads these to configure the hotkey, mic, and behavior.
@MainActor
@Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Right-Option (61) by default; user can rebind in Settings later.
    public var hotKeyCode: Int {
        get { defaults.object(forKey: "hotKeyCode") as? Int ?? 61 }
        set { defaults.set(newValue, forKey: "hotKeyCode") }
    }

    /// Preferred microphone unique id, or nil for the system default.
    public var micDeviceID: String? {
        get { defaults.string(forKey: "micDeviceID") }
        set { defaults.set(newValue, forKey: "micDeviceID") }
    }

    public var launchAtLogin: Bool {
        get { defaults.object(forKey: "launchAtLogin") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    public var showHUD: Bool {
        get { defaults.object(forKey: "showHUD") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showHUD") }
    }

    public var soundEnabled: Bool {
        get { defaults.object(forKey: "soundEnabled") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }

    /// True until the user finishes first-run onboarding.
    public var needsOnboarding: Bool {
        get { defaults.object(forKey: "needsOnboarding") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "needsOnboarding") }
    }

    // MARK: - Cleanup model
    // These keys are also read directly (thread-safe) by RoutingCleaner off the main actor.

    /// Which backend polishes transcripts: "off" (raw, most private), "ollama", "cli", "claude".
    public var cleanupProvider: String {
        get { defaults.string(forKey: "cleanupProvider") ?? "off" }
        set { defaults.set(newValue, forKey: "cleanupProvider") }
    }

    /// The Ollama model name to use when cleanupProvider == "ollama".
    public var ollamaModel: String? {
        get { defaults.string(forKey: "ollamaModel") }
        set { defaults.set(newValue, forKey: "ollamaModel") }
    }

    /// The installed CLI to use when cleanupProvider == "cli": "claude", "codex", or "gemini".
    public var cliTool: String {
        get { defaults.string(forKey: "cliTool") ?? "claude" }
        set { defaults.set(newValue, forKey: "cliTool") }
    }

    /// Language to translate cleaned text into (e.g. "Spanish"), or "off" for none. Needs a cleanup tier.
    public var targetLanguage: String {
        get { defaults.string(forKey: "targetLanguage") ?? "off" }
        set { defaults.set(newValue, forKey: "targetLanguage") }
    }
}
