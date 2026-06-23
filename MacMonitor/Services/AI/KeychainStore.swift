import Foundation
import Security

/// Groq API anahtarını macOS Keychain'de saklar (düz metin/UserDefaults değil).
enum KeychainStore {
    private static let service = "com.macmonitor.app"
    private static let account = "groq.apiKey"

    /// Anahtarı kaydeder (varsa üzerine yazar).
    @discardableResult
    static func save(_ value: String) -> Bool {
        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)   // eskisini sil

        var add = base
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Kayıtlı anahtarı okur (yoksa nil).
    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Anahtar var mı? (Gizli veriye erişmez → izin penceresi açmaz.)
    static func exists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Anahtarı siler.
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
