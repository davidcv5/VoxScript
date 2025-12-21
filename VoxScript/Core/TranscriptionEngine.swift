import Foundation
import WhisperKit
import AVFoundation

/// Handles speech-to-text transcription using WhisperKit
@Observable
final class TranscriptionEngine {
    // MARK: - Singleton

    static let shared = TranscriptionEngine()

    // MARK: - Properties

    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var currentModelId: String?
    private(set) var loadingProgress: Double = 0

    private let appState = AppState.shared
    private let settings = SettingsManager.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Model Management

    /// Load a Whisper model
    func loadModel(_ modelId: String) async throws {
        // Unload existing model
        if isModelLoaded {
            await unloadModel()
        }

        appState.setModelLoadingProgress(0)

        do {
            // Get model folder from the model ID
            let modelFolder = try await getModelFolder(for: modelId)

            whisperKit = try await WhisperKit(
                modelFolder: modelFolder,
                computeOptions: getComputeOptions(),
                verbose: false,
                logLevel: .none,
                prewarm: true,
                load: true,
                download: false
            )

            isModelLoaded = true
            currentModelId = modelId
            appState.setModelLoaded(true, modelId: modelId)
            appState.setModelLoadingProgress(1.0)

        } catch {
            isModelLoaded = false
            currentModelId = nil
            appState.setModelLoaded(false, modelId: nil)
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Unload the current model
    func unloadModel() async {
        whisperKit = nil
        isModelLoaded = false
        currentModelId = nil
        appState.setModelLoaded(false, modelId: nil)
    }

    /// Download a model
    func downloadModel(_ modelId: String, progress: @escaping (Double) -> Void) async throws {
        appState.setDownloadingModel(modelId, progress: 0)

        do {
            let modelName = getModelName(from: modelId)

            // Use WhisperKit's built-in download
            let modelURL = try await WhisperKit.download(
                variant: modelName,
                progressCallback: { downloadProgress in
                    let progressValue = downloadProgress.fractionCompleted
                    progress(progressValue)
                    Task { @MainActor in
                        self.appState.setDownloadingModel(modelId, progress: progressValue)
                    }
                }
            )

            // Verify download
            guard FileManager.default.fileExists(atPath: modelURL.path) else {
                throw TranscriptionError.downloadFailed("Model files not found after download")
            }

            appState.addDownloadedModel(modelId)
            appState.setDownloadingModel(nil, progress: 0)

        } catch {
            appState.setDownloadingModel(nil, progress: 0)
            throw TranscriptionError.downloadFailed(error.localizedDescription)
        }
    }

    /// Get list of downloaded models
    func getDownloadedModels() -> [String] {
        Array(appState.downloadedModels)
    }

    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) async -> Bool {
        let modelName = getModelName(from: modelId)

        do {
            let localModels = try await WhisperKit.recommendedModels().supported
            return localModels.contains(modelName)
        } catch {
            return false
        }
    }

    // MARK: - Transcription

    /// Transcribe audio from a file URL
    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }

        let startTime = Date()

        do {
            // Configure decoding options with correct parameter order
            let decodingOptions = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: getLanguageCode(),
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: true,
                usePrefillCache: true,
                detectLanguage: getLanguageCode() == nil,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                wordTimestamps: false,
                suppressBlank: true,
                supressTokens: nil,
                compressionRatioThreshold: 2.4,
                logProbThreshold: -1.0,
                firstTokenLogProbThreshold: nil,
                noSpeechThreshold: 0.6
            )

            // Perform transcription
            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: decodingOptions
            )

            let processingTime = Date().timeIntervalSince(startTime)

            // Combine all segments
            let fullText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Get audio duration
            let duration = try await getAudioDuration(from: audioURL)

            // Get detected language
            let detectedLanguage = results.first?.language

            return TranscriptionResult(
                text: fullText,
                rawText: fullText,
                language: detectedLanguage,
                duration: duration,
                processingTime: processingTime,
                wasPostProcessed: false
            )

        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Transcribe streaming audio data
    func transcribeStreaming(audioData: [Float]) async throws -> String {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }

        // WhisperKit streaming transcription
        let decodingOptions = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: getLanguageCode(),
            temperature: 0.0,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results = try await whisperKit.transcribe(
            audioArray: audioData,
            decodeOptions: decodingOptions
        )

        return results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    // MARK: - Private Helpers

    private func getModelFolder(for modelId: String) async throws -> String {
        let modelName = getModelName(from: modelId)

        // Check local models first
        let localModelPath = getLocalModelPath(for: modelName)
        if FileManager.default.fileExists(atPath: localModelPath) {
            return localModelPath
        }

        // Use WhisperKit's model discovery
        let modelURL = try await WhisperKit.download(variant: modelName)
        return modelURL.path
    }

    private func getModelName(from modelId: String) -> String {
        // WhisperKit expects the full model name as it appears in the HuggingFace repo
        // e.g., "openai_whisper-large-v3-turbo" should stay as is
        return modelId
    }

    private func getLocalModelPath(for modelName: String) -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("VoxScript")
            .appendingPathComponent("Models")
            .appendingPathComponent(modelName)
            .path
    }

    private func getComputeOptions() -> ModelComputeOptions {
        // Use Apple Neural Engine when available
        return ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )
    }

    private func getLanguageCode() -> String? {
        let language = settings.language
        return language == "auto" ? nil : language
    }

    private func getAudioDuration(from url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case downloadFailed(String)
    case transcriptionFailed(String)
    case invalidAudioFile

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is loaded. Please load a model first."
        case .modelLoadFailed(let details):
            return "Failed to load model: \(details)"
        case .downloadFailed(let details):
            return "Failed to download model: \(details)"
        case .transcriptionFailed(let details):
            return "Transcription failed: \(details)"
        case .invalidAudioFile:
            return "The audio file is invalid or corrupt"
        }
    }
}
