import Foundation

public final class AnthropicClient: SubtitleTranslationClient, @unchecked Sendable {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func translate(
        batch: TranslationBatch,
        settings: TranslationSettings,
        apiKey: String
    ) async throws -> PartialTranslationResult {
        let system = TranslationPromptBuilder.systemPrompt(settings: settings, contextSummary: batch.contextSummary)
        let user = try TranslationPromptBuilder.userPrompt(batch: batch, settings: settings)
        let content = try await message(system: system, user: user, settings: settings, apiKey: apiKey)
        return try TranslationResultParser.parsePartial(
            content,
            expectedIDs: batch.expectedIDs,
            stripPunctuation: settings.stripTargetPunctuation
        )
    }

    public func analyzeContext(
        sourceText: String,
        settings: TranslationSettings,
        apiKey: String
    ) async throws -> String {
        let system = """
        You are a subtitle content analyst assisting a translation system. Return plain text only.
        Analyze the subtitle sample and provide a 5-8 sentence plot summary plus a glossary of up to 30 recurring names and terms in \(settings.targetLanguage).
        """
        return try await message(
            system: system,
            user: "Subtitle sample:\n\(sourceText)",
            settings: settings,
            apiKey: apiKey
        )
    }

    private func message(
        system: String,
        user: String,
        settings: TranslationSettings,
        apiKey: String
    ) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw OpenAICompatibleClientError.emptyAPIKey }
        guard !settings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAICompatibleClientError.emptyModel
        }
        let trimmed = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/v1/messages") else {
            throw OpenAICompatibleClientError.invalidBaseURL(settings.baseURL)
        }

        let body: [String: Any] = [
            "model": settings.model,
            "max_tokens": 8192,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        var request = URLRequest(url: url, timeoutInterval: settings.requestTimeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(AnthropicErrorEnvelope.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8) ?? "未知错误"
            throw OpenAICompatibleClientError.httpError(statusCode: http.statusCode, message: message)
        }
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        if decoded.stopReason == "max_tokens" { throw OpenAICompatibleClientError.truncatedResponse }
        let text = decoded.content.compactMap(\.text).joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAICompatibleClientError.emptyResponse
        }
        return text
    }
}

public final class RoutingTranslationClient: SubtitleTranslationClient, @unchecked Sendable {
    private let openAI: any SubtitleTranslationClient
    private let anthropic: any SubtitleTranslationClient

    public init(
        openAI: any SubtitleTranslationClient = OpenAICompatibleClient(),
        anthropic: any SubtitleTranslationClient = AnthropicClient()
    ) {
        self.openAI = openAI
        self.anthropic = anthropic
    }

    public func translate(batch: TranslationBatch, settings: TranslationSettings, apiKey: String) async throws -> PartialTranslationResult {
        try await client(for: settings).translate(batch: batch, settings: settings, apiKey: apiKey)
    }

    public func analyzeContext(sourceText: String, settings: TranslationSettings, apiKey: String) async throws -> String {
        try await client(for: settings).analyzeContext(sourceText: sourceText, settings: settings, apiKey: apiKey)
    }

    private func client(for settings: TranslationSettings) -> any SubtitleTranslationClient {
        settings.provider == .anthropic ? anthropic : openAI
    }
}

private struct AnthropicResponse: Decodable {
    struct Content: Decodable { let type: String; let text: String? }
    let content: [Content]
    let stopReason: String?
    enum CodingKeys: String, CodingKey { case content; case stopReason = "stop_reason" }
}

private struct AnthropicErrorEnvelope: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}
