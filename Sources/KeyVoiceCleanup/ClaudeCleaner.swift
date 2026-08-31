import Foundation
import KeyVoiceCore

/// Sends the raw transcript to Claude to fix grammar and format for the active app.
/// Returns nil on any failure/timeout so the caller pastes the raw text.
/// STUB — real implementation lands on branch `cleanup` (plan Phase 5).
public final class ClaudeCleaner: Cleaner {
    private let config: AppConfig
    public init(config: AppConfig = AppConfig()) { self.config = config }

    public func clean(_ text: String, app: AppContext) async -> String? {
        // TODO(cleanup): POST /v1/messages (URLSession), model from config, x-api-key from Keychain,
        // static system prompt + "App: …\nTranscript: …" user message; parse content[0].text.
        // Return nil on non-2xx / timeout / empty so the Coordinator pastes raw.
        return nil
    }
}
