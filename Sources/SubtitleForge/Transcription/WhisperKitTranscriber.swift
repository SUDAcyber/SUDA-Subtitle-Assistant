import Foundation
import SubtitleForgeCore
import WhisperKit

/// Local on-device transcription via WhisperKit (CoreML on the Apple Neural Engine).
/// The pipeline is non-Sendable, so all use of it stays inside this actor; the
/// loaded model is cached so repeated runs skip the load cost.
actor WhisperKitEngine {
    static let shared = WhisperKitEngine()

    private var pipeline: WhisperKit?
    private var loadedModel: String?

    var transcriptionFraction: Double {
        pipeline?.progress.fractionCompleted ?? 0
    }

    func transcribe(
        model: String,
        audioPath: String,
        languageHint: String?
    ) async throws -> [TranscribedSegment] {
        let pipeline = try await loadPipeline(model: model)

        var options = DecodingOptions()
        options.task = .transcribe
        options.skipSpecialTokens = true
        options.chunkingStrategy = .vad
        if let languageHint, !languageHint.isEmpty, languageHint != "auto" {
            options.language = languageHint
        } else {
            options.detectLanguage = true
        }

        let results = try await pipeline.transcribe(
            audioPath: audioPath,
            decodeOptions: options,
            callback: { _ in
                Task.isCancelled ? false : nil
            }
        )

        return results
            .flatMap(\.segments)
            .map { segment in
                TranscribedSegment(
                    start: Double(segment.start),
                    end: Double(segment.end),
                    text: segment.text
                )
            }
    }

    private func loadPipeline(model: String) async throws -> WhisperKit {
        if let pipeline, loadedModel == model {
            return pipeline
        }
        pipeline = nil
        loadedModel = nil
        let config = WhisperKitConfig(
            model: model,
            verbose: false,
            prewarm: true,
            load: true,
            download: true
        )
        let created = try await WhisperKit(config)
        pipeline = created
        loadedModel = model
        return created
    }
}

struct WhisperKitTranscriber: SubtitleTranscriber {
    let model: String

    func transcribe(
        audioURL: URL,
        languageHint: String?,
        onProgress: @escaping @Sendable (TranscriptionProgressUpdate) -> Void
    ) async throws -> [TranscribedSegment] {
        onProgress(.preparingModel)

        let poller = Task {
            while !Task.isCancelled {
                let fraction = await WhisperKitEngine.shared.transcriptionFraction
                if fraction > 0 {
                    onProgress(.transcribing(fraction: min(0.999, fraction)))
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        defer { poller.cancel() }

        return try await WhisperKitEngine.shared.transcribe(
            model: model,
            audioPath: audioURL.path,
            languageHint: languageHint
        )
    }
}
