import Foundation
import KeyVoiceCore

/// Dispatches each cleanup to whichever backend the user has selected in Settings, read live from
/// `UserDefaults` (thread-safe, so switching providers takes effect immediately — no relaunch). The
/// coordinator holds one of these for the app's lifetime; the routing happens per call.
///
/// Provider keys match `SettingsStore`: "cleanupProvider" ∈ {off, ollama, claude}, "ollamaModel".
///
/// The "cli" provider (piping transcripts to an agentic `claude`/`codex`/`gemini` CLI with tool
/// access) was removed for the MVP: spoken text becoming a local agent prompt is a real injection
/// risk (audit P0 · SECURITY). Any legacy "cli" setting falls through to "off" here, and
/// `SettingsStore` migrates it on launch.
public final class RoutingCleaner: Cleaner {
    private let config: AppConfig
    // UserDefaults is thread-safe by contract but not marked Sendable; this is a shared read.
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(config: AppConfig = AppConfig(), defaults: UserDefaults = .standard) {
        self.config = config
        self.defaults = defaults
    }

    public func clean(_ text: String, app: AppContext) async -> String? {
        switch defaults.string(forKey: "cleanupProvider") ?? "off" {
        case "ollama":
            let model = defaults.string(forKey: "ollamaModel") ?? "llama3.2"
            return await OllamaCleaner(model: model).clean(text, app: app)
        case "claude":
            return await ClaudeCleaner(config: config).clean(text, app: app)
        default:
            return nil   // "off" (and any legacy/unknown value) — raw transcript is pasted
        }
    }
}
