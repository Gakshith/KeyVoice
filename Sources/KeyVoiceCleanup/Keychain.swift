import Foundation
import Security
import KeyVoiceCore

/// Stores the Anthropic API key in the login Keychain.
/// STUB — real implementation lands on branch `cleanup` (plan Phase 5).
public enum Keychain {
    public static let service = "com.keyvoice.app"
    public static let account = "anthropic-api-key"

    public static func save(_ key: String) throws {
        // TODO(cleanup): SecItemDelete then SecItemAdd with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
    }

    public static func load() -> String? {
        // TODO(cleanup): SecItemCopyMatching → String.
        return nil
    }
}
