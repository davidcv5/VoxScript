import Foundation
import SwiftUI

/// Central observable state for the application
@Observable
final class AppState {
    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Recording State

    private(set) var recordingState: RecordingState = .idle
    private(set) var audioLevel: Float = 0
    private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Transcription

    private(set) var lastTranscription: TranscriptionResult?
    private(set) var transcriptionHistory: [TranscriptionResult] = []

    // MARK: - Model State

    private(set) var isModelLoaded: Bool = false
    private(set) var currentModelId: String?
    private(set) var modelLoadingProgress: Double = 0
    private(set) var isDownloadingModel: Bool = false
    private(set) var downloadProgress: Double = 0
    private(set) var downloadingModelId: String?

    // MARK: - Available Models

    private(set) var downloadedModels: Set<String> = []

    // MARK: - Errors

    private(set) var lastError: Error?
    private(set) var showingError: Bool = false

    // MARK: - UI State

    var showingSettings: Bool = false
    var showingOnboarding: Bool = false
    var showingModelManager: Bool = false

    // MARK: - Permissions

    private(set) var hasMicrophonePermission: Bool = false
    private(set) var hasAccessibilityPermission: Bool = false

    // MARK: - Post-Processing

    private(set) var isOllamaAvailable: Bool = false

    // MARK: - Private

    private var recordingTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadDownloadedModels()
    }

    // MARK: - State Updates

    func setRecordingState(_ state: RecordingState) {
        recordingState = state

        switch state {
        case .recording:
            startRecordingTimer()
        case .idle, .complete, .error:
            stopRecordingTimer()
            recordingDuration = 0
        default:
            stopRecordingTimer()
        }
    }

    func setAudioLevel(_ level: Float) {
        audioLevel = level
    }

    func setModelLoaded(_ loaded: Bool, modelId: String?) {
        isModelLoaded = loaded
        currentModelId = modelId
    }

    func setModelLoadingProgress(_ progress: Double) {
        modelLoadingProgress = progress
    }

    func setDownloadingModel(_ modelId: String?, progress: Double) {
        downloadingModelId = modelId
        isDownloadingModel = modelId != nil
        downloadProgress = progress
    }

    func addDownloadedModel(_ modelId: String) {
        downloadedModels.insert(modelId)
        saveDownloadedModels()
    }

    func removeDownloadedModel(_ modelId: String) {
        downloadedModels.remove(modelId)
        saveDownloadedModels()
    }

    func setLastTranscription(_ result: TranscriptionResult) {
        lastTranscription = result
        transcriptionHistory.insert(result, at: 0)

        // Keep only last 100 transcriptions
        if transcriptionHistory.count > 100 {
            transcriptionHistory = Array(transcriptionHistory.prefix(100))
        }
    }

    func setError(_ error: Error?) {
        lastError = error
        showingError = error != nil
    }

    func clearError() {
        lastError = nil
        showingError = false
    }

    func setMicrophonePermission(_ granted: Bool) {
        hasMicrophonePermission = granted
    }

    func setAccessibilityPermission(_ granted: Bool) {
        hasAccessibilityPermission = granted
    }

    func setOllamaAvailable(_ available: Bool) {
        isOllamaAvailable = available
    }

    // MARK: - Recording Timer

    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Persistence

    private func loadDownloadedModels() {
        if let data = UserDefaults.standard.data(forKey: "downloadedModels"),
           let models = try? JSONDecoder().decode(Set<String>.self, from: data) {
            downloadedModels = models
        }
    }

    private func saveDownloadedModels() {
        if let data = try? JSONEncoder().encode(downloadedModels) {
            UserDefaults.standard.set(data, forKey: "downloadedModels")
        }
    }
}

// MARK: - Computed Properties

extension AppState {
    var canStartRecording: Bool {
        isModelLoaded && !recordingState.isActive && hasMicrophonePermission
    }

    var selectedModel: WhisperModel? {
        WhisperModel.availableModels.first { $0.id == SettingsManager.shared.selectedModelId }
    }

    var isSelectedModelDownloaded: Bool {
        downloadedModels.contains(SettingsManager.shared.selectedModelId)
    }

    var formattedRecordingDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
