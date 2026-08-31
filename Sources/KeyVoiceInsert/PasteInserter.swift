import Foundation
import AppKit
import CoreGraphics
import KeyVoiceCore

/// Inserts text at the cursor via clipboard paste-injection.
///
/// This is the only insertion method that works uniformly across native AppKit fields,
/// Electron apps (Slack, VS Code, Discord) and web content — synthesizing keystrokes or
/// poking `kAXValue` fails or misbehaves in one class or another. The tradeoff is that we
/// temporarily borrow the system clipboard, so we snapshot the full pasteboard first and
/// restore it after the paste is consumed.
///
/// Contract: `insert(_:into:)` runs on the main thread (the Coordinator calls it there).
public final class PasteInserter: TextInserter {
    private let config: AppConfig

    /// nspasteboard.org convention markers so clipboard managers ignore/conceal our temp value.
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Virtual keycode for 'v' (ANSI_V) — layout-independent as used with `.combinedSessionState`.
    private static let vKeyCode: CGKeyCode = 0x09

    /// How long to wait before restoring the original clipboard. A paste is a READ and never
    /// bumps `changeCount`, so completion can't be detected — we give the frontmost app time to
    /// consume ⌘V, then put the user's clipboard back.
    private static let restoreDelay: TimeInterval = 0.12

    public init(config: AppConfig = AppConfig()) { self.config = config }

    public func insert(_ text: String, into target: Target) throws {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // 1. Snapshot the ENTIRE current clipboard — every item, every type's raw data — so RTF,
        //    HTML, images and file URLs survive, not just the plain string.
        let saved = snapshot(pasteboard)

        // 2. Replace it with our text, flagged transient + concealed for clipboard managers.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: Self.transientType)
        pasteboard.setData(Data(), forType: Self.concealedType)

        // 3. Synthesize ⌘V into the focused app.
        postCommandV()

        // 4. Restore the user's clipboard after the paste has been consumed.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) {
            pasteboard.clearContents()
            if !saved.isEmpty {
                pasteboard.writeObjects(saved)
            }
        }
    }

    /// Deep-copies the pasteboard into detached items, preserving every representation.
    private func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    /// Posts a ⌘V key-down/up pair to the session event tap.
    private func postCommandV() {
        // `.combinedSessionState` reads the live modifier/keyboard state of the login session,
        // which makes the synthetic keystroke land in the frontmost app's focused field.
        let source = CGEventSource(stateID: .combinedSessionState)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
