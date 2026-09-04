import Foundation
import Observation

/// The single bindable state the SwiftUI HUD reads: the current phase plus the live 0…1 voice level.
/// Owned and mutated by `HUDController` on the main actor; observed by the Aurora view.
@MainActor
@Observable
public final class HUDViewModel {
    /// What to draw. Defaults to hidden so a freshly built model shows nothing.
    public var phase: HUDPhase = .hidden
    /// Smoothed microphone loudness, 0…1. Only meaningful while `.listening`.
    public var level: Float = 0

    public init() {}
}
