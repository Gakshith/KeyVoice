import Foundation
import KeyVoiceCore

/// Global push-to-talk on Right-Option, via a listen-only CGEvent tap.
/// STUB — real implementation lands on branch `hotkey` (plan Phase 2).
public final class HotkeyMonitor: HotkeyMonitoring {
    public var onEvent: ((HotkeyEvent) -> Void)?
    private let config: AppConfig

    public init(config: AppConfig = AppConfig()) {
        self.config = config
    }

    public func start() throws {
        // TODO(hotkey): CGEvent.tapCreate(.listenOnly) on flagsChanged+keyDown; keyCode 61;
        // debounce, combo-poison, re-arm on tapDisabled/wake. Emits .begin/.commit/.cancel.
    }

    public func stop() {}
}
