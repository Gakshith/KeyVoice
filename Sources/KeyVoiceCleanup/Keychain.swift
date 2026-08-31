import Foundation
import Security
import KeyVoiceCore

/// Stores the Anthropic API key in the login Keychain as a generic password.
/// The key never touches disk in plaintext and never appears in source or logs.
public enum Keychain {
    public static let service = "com.keyvoice.app"
    public static let account = "anthropic-api-key"

    /// Overwrites any existing key with `key`. Delete-then-add keeps the item's
    /// attributes clean rather than relying on SecItemUpdate.
    public static func save(_ key: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Remove the old item if present; errSecItemNotFound is fine.
        let deleteStatus = SecItemDelete(base as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(deleteStatus)
        }

        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    /// Returns the stored key, or nil if none is stored / it can't be decoded.
    public static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
}

/// Surfaced by `save` when the Keychain rejects the write.
public enum KeychainError: Error, CustomStringConvertible {
    case unexpectedStatus(OSStatus)

    public var description: String {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain error \(status): \(message)"
        }
    }
}
