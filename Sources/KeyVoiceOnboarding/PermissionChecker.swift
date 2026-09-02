import Foundation
import Observation
import AppKit
import CoreGraphics
import ApplicationServices
import AVFoundation

/// The three macOS permissions KeyVoice needs before it can do anything.
/// Input Monitoring lets the hotkey listener see the Right-Option key; Accessibility lets
/// it paste text into the focused app; Microphone lets it hear you. Without all three the
/// app launches and then silently does nothing, so onboarding walks the user through granting them.
public enum Permission: CaseIterable, Sendable {
    case inputMonitoring
    case accessibility
    case microphone

    public var title: String {
        switch self {
        case .inputMonitoring: return "Input Monitoring"
        case .accessibility:   return "Accessibility"
        case .microphone:      return "Microphone"
        }
    }

    public var reason: String {
        switch self {
        case .inputMonitoring: return "So KeyVoice can hear you hold Right-Option to talk."
        case .accessibility:   return "So your words land as text in whatever app you're using."
        case .microphone:      return "So KeyVoice can turn your speech into text."
        }
    }

    public var symbol: String {
        switch self {
        case .inputMonitoring: return "keyboard"
        case .accessibility:   return "hand.point.up.left.fill"
        case .microphone:      return "mic.fill"
        }
    }

    /// The `x-apple.systempreferences:` deep link that opens the matching pane in System Settings.
    fileprivate var settingsURL: URL {
        let anchor: String
        switch self {
        case .inputMonitoring: anchor = "Privacy_ListenEvent"
        case .accessibility:   anchor = "Privacy_Accessibility"
        case .microphone:      anchor = "Privacy_Microphone"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }
}

/// Live view of the three permissions. `refresh()` re-reads all of them (cheap, safe to poll),
/// and each can open its System Settings pane. Microphone can also be requested in-app, which
/// pops the standard macOS prompt without a trip to System Settings.
@MainActor
@Observable
public final class PermissionChecker {
    public private(set) var inputMonitoringGranted = false
    public private(set) var accessibilityGranted = false
    public private(set) var microphoneGranted = false

    public init() {
        refresh()
    }

    public var allGranted: Bool {
        inputMonitoringGranted && accessibilityGranted && microphoneGranted
    }

    public func isGranted(_ permission: Permission) -> Bool {
        switch permission {
        case .inputMonitoring: return inputMonitoringGranted
        case .accessibility:   return accessibilityGranted
        case .microphone:      return microphoneGranted
        }
    }

    /// Re-read the current status of all three from the OS. Safe to call on a timer.
    public func refresh() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// The button action for a card. Microphone gets an in-app prompt the first time (much
    /// smoother than sending the user to System Settings); everything else opens the pane.
    public func requestAccess(for permission: Permission) {
        switch permission {
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                    Task { @MainActor in self?.refresh() }
                }
            } else {
                // Already asked once and denied — only System Settings can flip it now.
                openSettings(for: permission)
            }
        case .inputMonitoring, .accessibility:
            openSettings(for: permission)
        }
    }

    /// Open the System Settings pane for a permission so the user can toggle it on.
    public func openSettings(for permission: Permission) {
        NSWorkspace.shared.open(permission.settingsURL)
    }
}
