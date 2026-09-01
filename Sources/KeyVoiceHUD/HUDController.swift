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
/// The panel is a focus-safe `HUDPanel` (never key/main, click-through) hosting a SwiftUI view that
/// observes `viewModel`. The SwiftUI content here is a deliberate PLACEHOLDER — a small translucent
/// capsule — standing in for the real "Aurora" ribbon that lands on a later branch.
@MainActor
public final class HUDController {
    /// The bindable state the SwiftUI view observes.
    public let viewModel = HUDViewModel()

    private let config: AppConfig

    /// Panel geometry, in points. Small on purpose — this is a stand-in.
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
        }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func ensurePanel() -> HUDPanel {
        if let panel { return panel }
        let rect = NSRect(origin: .zero, size: Self.panelSize)
        let panel = HUDPanel(contentRect: rect)
        let host = NSHostingView(rootView: HUDCapsuleView(model: viewModel))
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

// MARK: - Placeholder content

/// Small, monochrome, translucent stand-in for the Aurora ribbon. Reacts minimally to phase/level.
/// Deliberately contains NO focusable controls (no TextField/Button), so nothing here can ever
/// become first responder and break the panel's focus-safety.
private struct HUDCapsuleView: View {
    @State var model: HUDViewModel

    private var isDeflate: Bool { model.phase == .deflate }

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                (isDeflate ? Color.orange : Color.primary).opacity(0.18),
                lineWidth: 1
            )
        )
        .padding(14)
        .animation(.easeInOut(duration: 0.2), value: model.phase)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .listening:
            LevelBars(level: model.level)
        case .thinking:
            ThinkingDots()
        case .deflate:
            DeflateLine()
        case .done:
            DonePulse()
        case .appear, .hidden:
            LevelBars(level: 0)
        }
    }
}

/// A short row of bars. The center bars scale with the live voice level while `.listening`.
private struct LevelBars: View {
    var level: Float

    private let count = 5

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 5, height: barHeight(i))
            }
        }
        .frame(height: 40)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: level)
    }

    /// Bell-shaped weighting so the middle bars react most, edges least.
    private func barHeight(_ i: Int) -> CGFloat {
        let mid = Double(count - 1) / 2
        let weight = 1 - abs(Double(i) - mid) / (mid + 1)   // 1 at center → ~0.33 at edges
        let base = 8.0
        let span = 30.0 * weight
        return base + span * CGFloat(max(0, min(1, level)))
    }
}

/// A calm three-dot swirl for the transcribe + cleanup wait.
private struct ThinkingDots: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: 8, height: 8)
                    .scaleEffect(0.6 + 0.4 * pulse(i))
                    .opacity(0.5 + 0.5 * pulse(i))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func pulse(_ i: Int) -> Double {
        // Stagger the three dots so they breathe out of phase.
        let shifted = phase + Double(i) * 0.33
        return (sin(shifted * .pi * 2) + 1) / 2
    }
}

/// Deflate to a single amber line — nothing heard, target lost, or an error.
private struct DeflateLine: View {
    var body: some View {
        Capsule()
            .fill(Color.orange.opacity(0.9))
            .frame(width: 44, height: 5)
    }
}

/// One confident pulse when text lands.
private struct DonePulse: View {
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Color.primary.opacity(0.9))
            .frame(width: 14, height: 14)
            .scaleEffect(on ? 1.25 : 0.85)
            .opacity(on ? 1 : 0.6)
            .onAppear {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { on = true }
            }
    }
}
