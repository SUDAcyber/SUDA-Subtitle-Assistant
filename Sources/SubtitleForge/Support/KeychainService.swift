import Foundation
import Security

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

    func saveAPIKey(_ apiKey: String) {
        deleteAPIKey()
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        // The app is ad-hoc signed, so every build is a different identity to the
        // keychain and the default per-app ACL prompts "allow access?" on each
        // launch after a rebuild or upgrade. Trust all applications for this item
        // instead: it stays encrypted in the login keychain, and the per-app ACL
        // gave no real protection once the identity changes with every build.
        if let access = Self.makeOpenAccess() {
            query[kSecAttrAccess as String] = access
        }
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteAPIKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static func makeOpenAccess() -> SecAccess? {
        var access: SecAccess?
        // A nil trusted-application list means every application is trusted.
        let status = SecAccessCreate("SUDA字幕翻译助手 API Key" as CFString, nil, &access)
        return status == errSecSuccess ? access : nil
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
