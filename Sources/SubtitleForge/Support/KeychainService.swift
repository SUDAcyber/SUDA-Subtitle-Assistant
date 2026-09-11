import Foundation
import Security

/// Legacy credential storage. Kept only to migrate keys saved by earlier
/// versions into `CredentialStore`; reading may show the system "allow access?"
/// prompt once, after which the item is deleted so it never prompts again.
struct KeychainService: Sendable {
    private let service = "com.subtitleforge.credentials"
    private let account: String

    static let translationAccount = "openai-compatible-api-key"
    static let scribeAccount = "elevenlabs-scribe-api-key"

    init(account: String = KeychainService.translationAccount) {
        self.account = account
    }

    func loadAPIKey() -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return key
    }

    func deleteAPIKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
