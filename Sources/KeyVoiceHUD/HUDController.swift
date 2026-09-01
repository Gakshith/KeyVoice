import Foundation
import KeyVoiceCore

/// Drives the floating recording HUD. The app shell holds one of these and feeds it exactly two
/// inputs — the pipeline `PipelineStatus` and a live 0…1 audio level — so the HUD stays a pure view
/// with no pipeline logic of its own.
///
/// `update(_:)` owns the panel's lifecycle (show/hide), so the HUD can never be orphaned on screen
/// and the app wiring stays a one-line status sink.
///
/// Phase 0 note: this is the headless seam. The floating `NSPanel` and its SwiftUI content are added
/// on the `hud-panel` branch; this controller's public API (`update` / `setLevel`) is frozen here so
/// the app shell and the audio meter can wire against it in parallel.
@MainActor
public final class HUDController {
    /// The bindable state the SwiftUI view will observe (wired up on the `hud-panel` branch).
    public let viewModel = HUDViewModel()

    private let config: AppConfig

    public init(config: AppConfig = AppConfig()) {
        self.config = config
    }

    /// Reflect a pipeline status. Maps to a `HUDPhase` and updates the view state; the panel
    /// controller (hud-panel branch) turns that into show/animate/hide.
    public func update(_ status: PipelineStatus) {
        let phase = HUDPhase.from(status)
        viewModel.phase = phase
        // Terminal phases stop drawing to a live level.
        if phase != .listening { viewModel.level = 0 }
    }

    /// Feed the smoothed microphone level (0…1). Ignored unless we're listening, so a late buffer
    /// after `stop()` can't light the HUD back up.
    public func setLevel(_ level: Float) {
        guard viewModel.phase == .listening else { return }
        viewModel.level = max(0, min(1, level))
    }
}
