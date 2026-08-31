import Foundation
import ApplicationServices

/// Where a dictation is meant to land.
///
/// Captured the moment the user presses the key (`begin`), and re-verified just before the paste.
/// This is what stops the app from pasting into the wrong window if focus moves during the
/// ~1s transcribe+cleanup gap (plan blocker B2/C3).
public struct Target {
    /// Process id of the frontmost app at capture time.
    public let pid: pid_t
    /// Bundle id, e.g. "com.tinyspeck.slackmacgap". Drives per-app cleanup tone.
    public let bundleId: String
    /// Human name, e.g. "Slack". Passed to the cleaner as context.
    public let appName: String
    /// The focused UI element at capture time, if any. Used to re-verify the caret hasn't moved apps.
    public let focusedElement: AXUIElement?

    public init(pid: pid_t, bundleId: String, appName: String, focusedElement: AXUIElement?) {
        self.pid = pid
        self.bundleId = bundleId
        self.appName = appName
        self.focusedElement = focusedElement
    }

    /// The Sendable slice a `Cleaner` needs — never carries the AX element across an async boundary.
    public var appContext: AppContext { AppContext(bundleId: bundleId, appName: appName) }
}

/// The app-identity a `Cleaner` sees. Deliberately small and `Sendable` so it can cross to async code.
public struct AppContext: Sendable, Equatable {
    public let bundleId: String
    public let appName: String
    public init(bundleId: String, appName: String) {
        self.bundleId = bundleId
        self.appName = appName
    }
}
