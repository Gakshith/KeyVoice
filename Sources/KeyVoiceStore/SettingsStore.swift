import Foundation
import Observation

/// User-editable settings, persisted in `UserDefaults`. Observable so SwiftUI updates the moment a
/// value changes. IMPORTANT: the properties are *stored* (not computed) — `@Observable` only tracks
/// stored properties, so computed forwarders would silently fail to update the UI until the view was
/// recreated. Each `didSet` writes through to `UserDefaults`, which is also where `RoutingCleaner`
/// and `MicAudioCapture` read these values (thread-safe) off the main actor.
@MainActor
@Observable
public final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults

    /// Right-Option (61) by default; user can rebind in Settings.
    public var hotKeyCode: Int { didSet { defaults.set(hotKeyCode, forKey: "hotKeyCode") } }
    /// Preferred microphone unique id, or nil for the system default.
    public var micDeviceID: String? { didSet { defaults.set(micDeviceID, forKey: "micDeviceID") } }
    public var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") } }
    public var showHUD: Bool { didSet { defaults.set(showHUD, forKey: "showHUD") } }
    public var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: "soundEnabled") } }
    /// True until the user finishes first-run onboarding.
    public var needsOnboarding: Bool { didSet { defaults.set(needsOnboarding, forKey: "needsOnboarding") } }

    // MARK: - Cleanup model

    /// Which backend polishes transcripts: "off" (raw, most private), "ollama", "claude". The old
    /// "cli" provider was removed for security (audit P0) and is migrated to "off" on launch.
    public var cleanupProvider: String { didSet { defaults.set(cleanupProvider, forKey: "cleanupProvider") } }
    /// The Ollama model name to use when cleanupProvider == "ollama".
    public var ollamaModel: String? { didSet { defaults.set(ollamaModel, forKey: "ollamaModel") } }
    /// Language to translate cleaned text into (e.g. "Spanish"), or "off". Needs a cleanup tier.
    public var targetLanguage: String { didSet { defaults.set(targetLanguage, forKey: "targetLanguage") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotKeyCode      = defaults.object(forKey: "hotKeyCode") as? Int ?? 61
        micDeviceID     = defaults.string(forKey: "micDeviceID")
        launchAtLogin   = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        showHUD         = defaults.object(forKey: "showHUD") as? Bool ?? true
        soundEnabled    = defaults.object(forKey: "soundEnabled") as? Bool ?? false
        needsOnboarding = defaults.object(forKey: "needsOnboarding") as? Bool ?? true
        // Migrate away from the removed CLI cleanup provider (audit P0 · SECURITY) → default it Off.
        let savedProvider = defaults.string(forKey: "cleanupProvider") ?? "off"
        cleanupProvider = (savedProvider == "cli") ? "off" : savedProvider
        ollamaModel     = defaults.string(forKey: "ollamaModel")
        targetLanguage  = defaults.string(forKey: "targetLanguage") ?? "off"

        // Property observers don't fire during init, so persist the migration explicitly.
        if savedProvider == "cli" {
            defaults.set("off", forKey: "cleanupProvider")
            defaults.removeObject(forKey: "cliTool")
        }
    }
}
