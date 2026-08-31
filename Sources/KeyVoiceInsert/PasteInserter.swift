import Foundation
import KeyVoiceCore

/// Inserts text at the cursor via clipboard paste-injection (snapshot → temp → ⌘V → restore).
/// STUB — real implementation lands on branch `paste` (plan Phase 1).
public final class PasteInserter: TextInserter {
    private let config: AppConfig
    public init(config: AppConfig = AppConfig()) { self.config = config }

    public func insert(_ text: String, into target: Target) throws {
        // TODO(paste): full-item NSPasteboard snapshot; write concealed+transient temp string;
        // synth Cmd+V (virtualKey 0x09, .maskCommand); delayed async restore.
    }
}
