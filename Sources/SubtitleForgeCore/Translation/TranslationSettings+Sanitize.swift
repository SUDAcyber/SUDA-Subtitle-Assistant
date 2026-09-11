import Foundation

public extension TranslationSettings {
    /// Upper bound for single-line identifier fields (model name, URL, language…).
    static let singleLineFieldLimit = 256

    /// Returns a copy with single-line fields normalized: whitespace trimmed,
    /// and any value containing line breaks or exceeding the limit reset to the
    /// default. A stray paste of a whole subtitle file into the model-name field
    /// once produced a 76,000-character value that SwiftUI could not lay out,
    /// freezing the app before its window appeared.
    func sanitized() -> TranslationSettings {
        var copy = self
        let defaults = TranslationSettings()
        copy.model = Self.sanitizeLine(model, fallback: defaults.model)
        copy.providerName = Self.sanitizeLine(providerName, fallback: defaults.providerName)
        copy.baseURL = Self.sanitizeLine(baseURL, fallback: defaults.baseURL)
        copy.targetLanguage = Self.sanitizeLine(targetLanguage, fallback: defaults.targetLanguage)
        copy.whisperModel = Self.sanitizeLine(whisperModel, fallback: defaults.whisperModel)
        copy.transcriptionLanguage = Self.sanitizeLine(transcriptionLanguage, fallback: defaults.transcriptionLanguage)
        copy.translationMemory = translationMemory.compactMap { entry in
            var entry = entry
            entry.source = Self.sanitizeLine(entry.source, fallback: "")
            entry.target = Self.sanitizeLine(entry.target, fallback: "")
            entry.note = Self.sanitizeLine(entry.note, fallback: "")
            return entry.isUsable ? entry : nil
        }
        return copy
    }

    /// A field is considered corrupted when it spans multiple lines or is far
    /// longer than any legitimate value; such values are replaced by `fallback`.
    static func sanitizeLine(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLineBreak = trimmed.contains { $0.isNewline }
        if hasLineBreak || trimmed.count > singleLineFieldLimit {
            return fallback
        }
        return trimmed
    }
}
