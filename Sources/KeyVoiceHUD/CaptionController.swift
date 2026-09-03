import Foundation
import AppKit
import SwiftUI
import Observation
import KeyVoiceCore

/// The live streaming caption: shows the words as you speak, above the recording HUD, before you
/// release the key. Driven by the transcriber's volatile (partial) results. A separate click-through,
/// non-activating panel so it never touches the tuned Aurora HUD or the app's focus contract.
@MainActor
public final class CaptionController {
    public let model = CaptionModel()

    private var panel: HUDPanel?
    private static let panelSize = NSSize(width: 560, height: 130)

    public init() {}

    /// Update the live text. Empty hides the caption.
    public func setText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        model.text = trimmed
        if trimmed.isEmpty { hide() } else { show() }
    }

    /// React to the pipeline: clear on a fresh listen, keep during cleanup, remove when done.
    public func update(_ status: PipelineStatus) {
        switch status {
        case .listening:            setText("")     // fresh start — volatile results will fill it
        case .thinking:             break           // keep the last partial while cleaning
        default:                    clear()          // idle / done / skipped / aborted / error
        }
    }

    public func clear() {
        model.text = ""
        hide()
    }

    // MARK: - Panel

    private func show() {
        let panel = ensurePanel()
        reposition(panel)
        panel.orderFrontRegardless()
    }

    private func hide() { panel?.orderOut(nil) }

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let rect = NSRect(origin: .zero, size: Self.panelSize)
        let panel = HUDPanel(contentRect: rect)
        let host = NSHostingView(rootView: CaptionView(model: model))
        host.frame = rect
        if #available(macOS 13.0, *) { host.sceneBridgingOptions = [] }
        panel.contentView = host
        self.panel = panel
        return panel
    }

    /// Bottom-center, sitting just above the HUD pill (which is 44pt tall, 24pt off the dock).
    private func reposition(_ panel: HUDPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.minY + 24 + 44 + 8      // above the HUD
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

/// The bindable caption text.
@MainActor
@Observable
public final class CaptionModel {
    public var text: String = ""
    public init() {}
}

/// A dark velvet bubble with a spectrum-edged border, bottom-anchored so it hugs the HUD.
struct CaptionView: View {
    let model: CaptionModel

    private static let spectrum = [
        Color(red: 0.416, green: 0.298, blue: 1.0), Color(red: 0.298, green: 0.482, blue: 1.0),
        Color(red: 0.184, green: 0.816, blue: 0.812), Color(red: 1.0, green: 0.694, blue: 0.306),
        Color(red: 1.0, green: 0.361, blue: 0.541),
    ]

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if !model.text.isEmpty {
                Text(model.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.96))
                    .lineLimit(2)
                    .truncationMode(.head)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.082, green: 0.075, blue: 0.063).opacity(0.97))
                            .overlay(
                                Capsule(style: .continuous).strokeBorder(
                                    LinearGradient(colors: Self.spectrum, startPoint: .leading, endPoint: .trailing)
                                        .opacity(0.55),
                                    lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                    )
                    .frame(maxWidth: 500)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 2)
        .animation(.easeOut(duration: 0.14), value: model.text)
    }
}
