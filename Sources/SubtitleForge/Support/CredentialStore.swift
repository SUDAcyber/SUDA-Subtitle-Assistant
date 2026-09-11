import Foundation

/// Stores API keys in a user-only (0600) JSON file under Application Support.
///
/// The app is distributed ad-hoc signed, so to the keychain every build and
/// every upgrade is a different application: legacy keychain items prompt
/// "allow access?" on each launch, and modern macOS (partition IDs) no longer
/// lets an item be created readable-by-all. A file readable only by the current
/// user gives the same practical protection the user ends up with after
/// clicking "Always Allow" — without ever blocking launch on a system dialog.
struct CredentialStore: Sendable {
    private let fileURL: URL?

    init(directory: URL? = AppPaths.supportDirectory) {
        fileURL = directory?.appendingPathComponent("credentials.json")
    }

    func load(account: String) -> String {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return ""
        }
        return dict[account] ?? ""
    }

    func save(_ value: String, account: String) {
        guard let fileURL else { return }
        var dict = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dict.removeValue(forKey: account)
        } else {
            dict[account] = trimmed
        }
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(dict)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Credentials are re-enterable; never let a failed write take the app down.
        }
    }
}
