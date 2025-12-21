import Foundation

/// Represents the result of a transcription operation
struct TranscriptionResult: Identifiable, Equatable {
    let id: UUID
    let text: String
    let rawText: String
    let language: String?
    let duration: TimeInterval
    let processingTime: TimeInterval
    let wasPostProcessed: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        text: String,
        rawText: String? = nil,
        language: String? = nil,
        duration: TimeInterval = 0,
        processingTime: TimeInterval = 0,
        wasPostProcessed: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.rawText = rawText ?? text
        self.language = language
        self.duration = duration
        self.processingTime = processingTime
        self.wasPostProcessed = wasPostProcessed
        self.timestamp = timestamp
    }

    /// Word count of the transcribed text
    var wordCount: Int {
        text.split(separator: " ").count
    }

    /// Whether the transcription is empty
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Information about a Whisper model
struct WhisperModel: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let size: String
    let sizeBytes: Int64
    let isDownloaded: Bool
    let isDefault: Bool

    static let availableModels: [WhisperModel] = [
        WhisperModel(
            id: "openai_whisper-large-v3",
            name: "large-v3",
            size: "1.5GB",
            sizeBytes: 1_610_612_736,
            isDownloaded: false,
            isDefault: false
        ),
        WhisperModel(
            id: "openai_whisper-large-v3_turbo",
            name: "large-v3 turbo",
            size: "954MB",
            sizeBytes: 1_000_341_504,
            isDownloaded: false,
            isDefault: true
        ),
        WhisperModel(
            id: "openai_whisper-small.en",
            name: "small.en",
            size: "217MB",
            sizeBytes: 227_540_992,
            isDownloaded: false,
            isDefault: false
        ),
        WhisperModel(
            id: "openai_whisper-base",
            name: "base",
            size: "140MB",
            sizeBytes: 146_800_640,
            isDownloaded: false,
            isDefault: false
        ),
        WhisperModel(
            id: "openai_whisper-tiny",
            name: "tiny",
            size: "70MB",
            sizeBytes: 73_400_320,
            isDownloaded: false,
            isDefault: false
        )
    ]

    static var defaultModel: WhisperModel {
        availableModels.first { $0.isDefault } ?? availableModels[0]
    }
}
