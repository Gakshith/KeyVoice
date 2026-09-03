import Foundation
import Observation

/// One thing that must be true before KeyVoice can actually type for you. The app shell checks these
/// (permissions, speech model) and updates `Readiness`; the UI reads it so the home screen tells the
/// truth instead of a hard-coded green light (audit P0 · TRUST).
public enum ReadinessItem: String, CaseIterable, Sendable, Identifiable {
    case accessibility, inputMonitoring, microphone, speech
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility:   return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .microphone:      return "Microphone"
        case .speech:          return "Speech model"
        }
    }

    /// Short, plain reason shown on the repair card.
    public var detail: String {
        switch self {
        case .accessibility:   return "Lets KeyVoice paste text into the app you’re using."
        case .inputMonitoring: return "Lets KeyVoice see you hold the push-to-talk key."
        case .microphone:      return "Lets KeyVoice hear you."
        case .speech:          return "The on-device model that turns your speech into text."
        }
    }

    public var symbol: String {
        switch self {
        case .accessibility:   return "hand.point.up.left.fill"
        case .inputMonitoring: return "keyboard"
        case .microphone:      return "mic.fill"
        case .speech:          return "waveform"
        }
    }

    /// The System Settings privacy anchor to open, or nil (the speech model isn't a settings pane —
    /// it's re-checked / downloaded instead).
    public var settingsAnchor: String? {
        switch self {
        case .accessibility:   return "Privacy_Accessibility"
        case .inputMonitoring: return "Privacy_ListenEvent"
        case .microphone:      return "Privacy_Microphone"
        case .speech:          return nil
        }
    }
}

/// The live, observable readiness of the app. Owned by the app shell (which alone can read the OS
/// permission state) and observed by the Dictation cockpit. Nothing here checks the OS itself —
/// keeping it a plain state object means the Hub can depend on it without pulling in AppKit.
@MainActor
@Observable
public final class Readiness {
    public var accessibility = false
    public var inputMonitoring = false
    public var microphone = false
    public var speechReady = false
    /// True once the hotkey listener is armed (implies Input Monitoring was granted).
    public var hotkeyArmed = false

    public init() {}

    public var permissionsGranted: Bool { accessibility && inputMonitoring && microphone }

    /// Everything needed to dictate right now.
    public var isReady: Bool { permissionsGranted && speechReady }

    /// The things still missing, in the order to fix them.
    public var missing: [ReadinessItem] {
        var out: [ReadinessItem] = []
        if !accessibility { out.append(.accessibility) }
        if !inputMonitoring { out.append(.inputMonitoring) }
        if !microphone { out.append(.microphone) }
        if !speechReady { out.append(.speech) }
        return out
    }
}
