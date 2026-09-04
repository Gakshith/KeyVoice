import Foundation
import AppKit
import SwiftUI
import Observation
import KeyVoiceCore

/// The no-target scratchpad: when you dictate with no editable field focused (or the target goes away
/// before insertion), KeyVoice doesn't lose your words or guess a destination — it shows them here
/// with a Copy button. Copy-only by design: an "Insert here" button would need a click, and clicking
/// this panel would move focus and recreate the wrong-target bug we're avoiding (NEW-2 / P0 · DATA).
///
/// Unlike the HUD/caption, this panel accepts the mouse (so Copy works), but it still never becomes
/// key or main, so it doesn't disturb the app you were in.
@MainActor
public final class ScratchpadController {
    public let model = ScratchpadModel()

    private var panel: ScratchpadPanel?
    private var dismissTimer: Timer?
    private static let panelSize = NSSize(width: 400, height: 168)
    private static let autoDismiss: TimeInterval = 30

    public init() {}

    /// Show captured text. Empty is ignored. Auto-dismisses after a while.
    public func show(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.text = trimmed
        model.copied = false
        let panel = ensurePanel()
        reposition(panel)
        panel.orderFrontRegardless()
        scheduleDismiss()
    }

    public func hide() {
        dismissTimer?.invalidate(); dismissTimer = nil
        panel?.orderOut(nil)
    }

    // MARK: - Panel

    private func scheduleDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: Self.autoDismiss, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func ensurePanel() -> ScratchpadPanel {
        if let panel { return panel }
        let rect = NSRect(origin: .zero, size: Self.panelSize)
        let panel = ScratchpadPanel(contentRect: rect)
        let host = NSHostingView(rootView: ScratchpadView(
            model: model,
            onCopy: { [weak self] in self?.copy() },
            onClose: { [weak self] in self?.hide() }
        ))
        host.frame = rect
        if #available(macOS 13.0, *) { host.sceneBridgingOptions = [] }
        panel.contentView = host
        self.panel = panel
        return panel
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.text, forType: .string)
        model.copied = true
    }

    /// Bottom-center, just above where the HUD pill sits.
    private func reposition(_ panel: ScratchpadPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.minY + 24 + 44 + 12
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

/// A non-activating panel that DOES accept the mouse (so the Copy button works) but never becomes
/// key/main — preserving the app's focus contract.
final class ScratchpadPanel: NSPanel {
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
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
}

/// The bindable scratchpad state.
@MainActor
@Observable
public final class ScratchpadModel {
    public var text = ""
    public var copied = false
    public init() {}
}

/// A velvet card: an amber "no target" cue, the captured text, and a Copy button.
struct ScratchpadView: View {
    let model: ScratchpadModel
    let onCopy: () -> Void
    let onClose: () -> Void

    private static let velvet = Color(red: 0.082, green: 0.075, blue: 0.063)
    private static let amber = Color(red: 1.0, green: 0.694, blue: 0.306)
    private static let good = Color(red: 0.298, green: 0.686, blue: 0.4)

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(Self.amber).frame(width: 7, height: 7)
                    Text("NO TEXT FIELD — SAVED HERE")
                        .font(.system(size: 10.5, weight: .bold)).tracking(0.9)
                        .foregroundStyle(Color(white: 0.72))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(white: 0.6))
                    }.buttonStyle(.plain)
                }
                Text(model.text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color(white: 0.95))
                    .lineLimit(4).truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Spacer()
                    Button(action: onCopy) {
                        HStack(spacing: 6) {
                            Image(systemName: model.copied ? "checkmark" : "doc.on.doc").font(.system(size: 12, weight: .semibold))
                            Text(model.copied ? "Copied" : "Copy").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(model.copied ? Self.good : Color(white: 0.1))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(model.copied ? Color.white.opacity(0.14) : Color(white: 0.94)))
                    }.buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Self.velvet.opacity(0.98))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Self.amber.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
            )
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.easeOut(duration: 0.15), value: model.copied)
    }
}
