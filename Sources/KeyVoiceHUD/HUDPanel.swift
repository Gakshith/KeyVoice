import AppKit

/// A borderless, non-activating floating panel for the recording HUD.
///
/// The one hard constraint: this panel must NEVER become key or main. KeyVoice pastes back into the
/// field that was focused *before* dictation using a synthesized ⌘V. If the HUD ever stole key/main
/// status, macOS would move focus off that field and the paste would land in the wrong place (or
/// nowhere). Overriding `canBecomeKey`/`canBecomeMain` to `false` plus the `.nonactivatingPanel`
/// style mask is what keeps the app's focus contract intact.
///
/// It is display-only: `ignoresMouseEvents = true` makes it click-through, and it is shown with
/// `orderFrontRegardless()` — never `makeKeyAndOrderFront` and never `NSApp.activate`.
final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true            // display-only, click-through
        level = .statusBar                    // above normal windows
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
}
