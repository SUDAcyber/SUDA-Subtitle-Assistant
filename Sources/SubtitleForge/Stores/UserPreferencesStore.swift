import Foundation
import SubtitleForgeCore

enum UserPreferencesStore {
    private static let settingsKey = "subtitleForge.translationSettings"
    private static let previewCueLimitKey = "subtitleForge.previewCueLimit"
    private static let colorSchemeModeKey = "subtitleForge.colorSchemeMode"
    private static let interfaceLanguageKey = "subtitleForge.interfaceLanguage"

    static func loadSettings() -> TranslationSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(TranslationSettings.self, from: data)
        else {
            return .aiHubMixDefault
        }
        return settings
    }

    static func saveSettings(_ settings: TranslationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    static func loadPreviewCueLimit() -> Int {
        let value = UserDefaults.standard.integer(forKey: previewCueLimitKey)
        return value > 0 ? value : 800
    }

    static func savePreviewCueLimit(_ value: Int) {
        UserDefaults.standard.set(value, forKey: previewCueLimitKey)
    }

    static func loadColorSchemeMode() -> AppColorSchemeMode {
        guard let rawValue = UserDefaults.standard.string(forKey: colorSchemeModeKey),
              let mode = AppColorSchemeMode(rawValue: rawValue)
        else {
            return .system
        }
        return mode
    }

    static func saveColorSchemeMode(_ mode: AppColorSchemeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: colorSchemeModeKey)
    }

    static func loadInterfaceLanguage() -> AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: interfaceLanguageKey),
              let language = AppLanguage(rawValue: rawValue)
        else {
            return .zhHans
        }
        return language
    }

    static func saveInterfaceLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: interfaceLanguageKey)
    }
}
