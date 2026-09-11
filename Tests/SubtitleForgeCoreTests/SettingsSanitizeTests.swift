import XCTest
@testable import SubtitleForgeCore

final class SettingsSanitizeTests: XCTestCase {
    func testMultilineModelFieldIsResetToDefault() {
        var settings = TranslationSettings()
        settings.model = "1\n00:00:00,200 --> 00:00:02,766\n大家好\n\n2\n..."
        let cleaned = settings.sanitized()
        XCTAssertEqual(cleaned.model, TranslationSettings().model)
    }

    func testOverlongSingleLineFieldIsResetToDefault() {
        var settings = TranslationSettings()
        settings.providerName = String(repeating: "x", count: TranslationSettings.singleLineFieldLimit + 1)
        XCTAssertEqual(settings.sanitized().providerName, TranslationSettings().providerName)
    }

    func testLegitimateValuesSurviveAndAreTrimmed() {
        var settings = TranslationSettings()
        settings.model = "  gpt-5.6-luna-high  "
        settings.baseURL = "https://api.openai.com/v1"
        settings.targetLanguage = "繁体中文"
        let cleaned = settings.sanitized()
        XCTAssertEqual(cleaned.model, "gpt-5.6-luna-high")
        XCTAssertEqual(cleaned.baseURL, "https://api.openai.com/v1")
        XCTAssertEqual(cleaned.targetLanguage, "繁体中文")
    }

    func testCorruptedMemoryEntriesAreDroppedOthersKept() {
        var settings = TranslationSettings()
        settings.translationMemory = [
            TranslationMemoryEntry(source: "Surf", target: "Surf"),
            TranslationMemoryEntry(source: "bad\nentry", target: "x"),
        ]
        let memory = settings.sanitized().translationMemory
        XCTAssertEqual(memory.map(\.source), ["Surf"])
    }
}
