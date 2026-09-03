import Foundation
import KeyVoiceCore

/// Dispatches each cleanup to whichever backend the user has selected in Settings, read live from
/// `UserDefaults` (thread-safe, so switching providers takes effect immediately — no relaunch). The
/// coordinator holds one of these for the app's lifetime; the routing happens per call.
///
/// Provider keys match `SettingsStore`: "cleanupProvider" ∈ {off, ollama, cli, claude},
/// "ollamaModel", "cliTool".
public final class RoutingCleaner: Cleaner {
    private let config: AppConfig
    private let defaults: UserDefaults

    public init(config: AppConfig = AppConfig(), defaults: UserDefaults = .standard) {
        self.config = config
        self.defaults = defaults
    }

    public func clean(_ text: String, app: AppContext) async -> String? {
        switch defaults.string(forKey: "cleanupProvider") ?? "off" {
        case "ollama":
            let model = defaults.string(forKey: "ollamaModel") ?? "llama3.2"
            return await OllamaCleaner(model: model).clean(text, app: app)
        case "cli":
            let tool = CLITool(rawValue: defaults.string(forKey: "cliTool") ?? "claude") ?? .claude
            return await CLICleaner(tool: tool).clean(text, app: app)
        case "claude":
            return await ClaudeCleaner(config: config).clean(text, app: app)
        default:
            return nil   // "off" — raw transcript is pasted
        }
    }
}
