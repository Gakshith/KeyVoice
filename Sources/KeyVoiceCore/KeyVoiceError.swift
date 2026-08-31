import Foundation

/// Errors surfaced to the user as a status, never swallowed.
public enum KeyVoiceError: LocalizedError {
    case inputMonitoringDenied
    case accessibilityDenied
    case microphoneDenied
    case microphoneBusy
    case transcriptionAssetsMissing
    case transcriptionFailed(String)
    case apiKeyMissing
    case apiKeyInvalid

    public var errorDescription: String? {
        switch self {
        case .inputMonitoringDenied:    return "Input Monitoring permission is off — enable it to use the hotkey."
        case .accessibilityDenied:      return "Accessibility permission is off — enable it to paste text."
        case .microphoneDenied:         return "Microphone permission is off."
        case .microphoneBusy:           return "The microphone is in use by another app."
        case .transcriptionAssetsMissing: return "Speech model isn't installed yet — downloading or falling back."
        case .transcriptionFailed(let m): return "Transcription failed: \(m)"
        case .apiKeyMissing:            return "Add your Anthropic API key in Settings to enable cleanup."
        case .apiKeyInvalid:            return "The Anthropic API key was rejected — check it in Settings."
        }
    }
}
