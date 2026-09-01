import Foundation
import AppKit
import SwiftUI
import KeyVoiceCore

/// Drives the floating recording HUD. The app shell holds one of these and feeds it exactly two
/// inputs — the pipeline `PipelineStatus` and a live 0…1 audio level — so the HUD stays a pure view
/// with no pipeline logic of its own.
///
/// `update(_:)` owns the panel's lifecycle (show/hide), so the HUD can never be orphaned on screen
/// and the app wiring stays a one-line status sink.
///
/// The panel is a focus-safe `HUDPanel` (never key/main, click-through) hosting the `AuroraView`,
/// which observes `viewModel` and draws the flowing ribbon reacting to the live voice level.
@MainActor
public final class HUDController {
    /// The bindable state the SwiftUI view observes.
    public let viewModel = HUDViewModel()

    private let config: AppConfig

    /// Panel geometry, in points. Small and unobtrusive at the bottom of the screen.
    private static let panelSize = NSSize(width: 240, height: 84)
    /// How long a terminal state (`done` / `deflate`) stays on screen before ordering out.
    private static let lingerSeconds: TimeInterval = 0.45

    /// Created lazily on first show so simply constructing a controller (e.g. in a unit test) never
    /// spins up a window.
    private var panel: HUDPanel?
    /// A scheduled order-out for a terminal phase; cancelled if a new show arrives first.
    private var pendingHide: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    public init(config: AppConfig = AppConfig()) {
        self.config = config
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    /// Reflect a pipeline status. Maps to a `HUDPhase`, updates the view state, and drives the
    /// panel's show/hide lifecycle so the HUD can never be left orphaned on screen.
    public func update(_ status: PipelineStatus) {
        let phase = HUDPhase.from(status)
        viewModel.phase = phase
        // Terminal phases stop drawing to a live level.
        if phase != .listening { viewModel.level = 0 }

        switch phase {
        case .appear, .listening, .thinking:
            // Active phases: cancel any pending hide and make sure we're on screen.
            pendingHide?.cancel()
            pendingHide = nil
            show()
        case .done, .deflate:
            // End states: keep the panel up briefly so the result reads, then order out.
            scheduleHide(after: Self.lingerSeconds)
        case .hidden:
            // Resting state. A late `.hidden` must win over any pending linger-hide.
            pendingHide?.cancel()
            pendingHide = nil
            hide()
        }
    }

    /// Feed the smoothed microphone level (0…1). Ignored unless we're listening, so a late buffer
    /// after `stop()` can't light the HUD back up.
    public func setLevel(_ level: Float) {
        guard viewModel.phase == .listening else { return }
        viewModel.level = max(0, min(1, level))
    }

    // MARK: - Panel lifecycle

    private func show() {
        let panel = ensurePanel()
        reposition(panel)
        panel.orderFrontRegardless()   // never makeKeyAndOrderFront; never NSApp.activate
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func scheduleHide(after delay: TimeInterval) {
        // Make sure the end state is actually visible before we time its exit.
        show()
        pendingHide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingHide = nil
            self.hide()
            // Settle to hidden so the Aurora TimelineView pauses (no rendering on an ordered-out panel).
            self.viewModel.phase = .hidden
        }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let rect = NSRect(origin: .zero, size: Self.panelSize)
        let panel = HUDPanel(contentRect: rect)
        let host = NSHostingView(rootView: AuroraView(model: viewModel))
        host.frame = rect
        // Let the material show through the hosting view / panel.
        if #available(macOS 13.0, *) {
            host.sceneBridgingOptions = []
        }
        panel.contentView = host
        self.panel = panel

        // Re-center when the display arrangement changes (resolution, screen added/removed).
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, panel.isVisible else { return }
                self.reposition(panel)
            }
        }
        return panel
    }

    /// Bottom-center of the screen under the mouse, a little above the dock.
    private func reposition(_ panel: HUDPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = Self.panelSize
        let x = frame.midX - size.width / 2
        let y = frame.minY + 24
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
