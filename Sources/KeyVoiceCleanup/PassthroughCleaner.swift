import KeyVoiceCore

/// Disables cleanup so the caller falls back to the raw transcript.
public final class PassthroughCleaner: Cleaner {
    public init() {}

    public func clean(_ text: String, app: AppContext) async -> String? {
        nil
    }
}
