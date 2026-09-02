import Foundation
import ApplicationServices
import AppKit
import KeyVoiceCore

/// Captures and re-verifies the dictation target (frontmost app + focused element).
///
/// The focused-element role check is what makes the app no-op when nothing editable is focused
/// (so we never paste into a read-only view), and `stillValid` is what stops a paste from landing
/// in the wrong window if focus moved apps during the ~1s transcribe+cleanup gap.
///
/// All calls here require the Accessibility permission. If it isn't granted we prompt once and
/// return nil until the user grants it.
public final class AXTargetProvider: TargetProvider {

    /// AX roles we accept as an editable destination. Native fields report the first three;
    /// web/Electron content reports AXWebArea (and, for individual inputs inside it, AXTextField/
    /// AXTextArea). Anything else → not editable → no-op.
    private static let editableRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXWebArea",
        "AXSearchField",
    ]

    public init() {}

    public func currentTarget() -> Target? {
        guard ensureTrusted() else { return nil }

        // The dictation destination is the frontmost app. We paste into it with ⌘V, so it's the app,
        // not a specific AX element, that we ultimately target.
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        // Try to read the focused element + role. Native fields report an editable role (AXTextField,
        // AXTextArea, …) and we keep that element for the most precise target re-check. But many
        // web/Electron inputs — Chrome, and Claude's own input among them — don't expose an editable
        // role (or any focused element) to accessibility, even though ⌘V pastes into them fine. So we
        // do NOT refuse those: we fall back to a pid-gated target (no element), which still pastes at
        // the cursor and is still guarded against landing in the wrong app by the pid check.
        let focused = copyFocusedElement()
        let role = focused.flatMap { copyStringAttribute($0, kAXRoleAttribute as CFString) }
        let isKnownEditable = role.map(Self.editableRoles.contains) ?? false

        if !isKnownEditable {
            Log.info("target: \(app.localizedName ?? "?") focus role '\(role ?? "unknown")' not a known editable field — pid-gated paste")
        }

        return Target(
            pid: app.processIdentifier,
            bundleId: app.bundleIdentifier ?? "",
            appName: app.localizedName ?? "",
            focusedElement: isKnownEditable ? focused : nil
        )
    }

    public func stillValid(_ target: Target) -> Bool {
        // Hard gate: the frontmost app must still be the one we captured.
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        guard app.processIdentifier == target.pid else { return false }

        // Best-effort: if we can read the focused element now and had one at capture, they should
        // match. AX reads are unreliable across app types, so a failure to read does NOT invalidate
        // — the pid match above is the real guarantee.
        if let captured = target.focusedElement, let current = copyFocusedElement() {
            return CFEqual(captured, current)
        }
        return true
    }

    // MARK: - Accessibility permission

    /// Returns true if the process is trusted for Accessibility. Prompts once if not.
    private func ensureTrusted() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - AX attribute helpers

    /// The system-wide focused UI element, or nil.
    private func copyFocusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value)
        guard err == .success, let value else { return nil }
        // AXUIElementCopyAttributeValue always returns an AXUIElement here; bridge safely.
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// Copies a string attribute (e.g. role) from an element, or nil.
    private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard err == .success else { return nil }
        return value as? String
    }
}
