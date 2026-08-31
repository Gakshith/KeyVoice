import Foundation
import ApplicationServices
import AppKit
import KeyVoiceCore

/// Captures and re-verifies the dictation target (frontmost app + focused element).
/// STUB — real implementation lands on branch `paste` (plan Phase 1).
public final class AXTargetProvider: TargetProvider {
    public init() {}

    public func currentTarget() -> Target? {
        // TODO(paste): AXUIElementCreateSystemWide → kAXFocusedUIElement → role check;
        // NSWorkspace.frontmostApplication for pid/bundleId/name. Return nil if no editable field.
        return nil
    }

    public func stillValid(_ target: Target) -> Bool {
        // TODO(paste): compare current frontmost pid + focused element against the locked target.
        return true
    }
}
