enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case zhHans
    case english

    var id: String { rawValue }

    var appName: String {
        switch self {
        case .zhHans:
            return "SUDA字幕翻译助手"
        case .english:
            return "SUDATranslator"
        }
    }

    var displayName: String {
        switch self {
        case .zhHans:
            return "中文"
        case .english:
            return "English"
        }
    }
}
