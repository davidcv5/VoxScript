import XCTest
@testable import VoxScript

final class AppStateTests: XCTestCase {
    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState.shared
    }

    func testInitialState() {
        XCTAssertEqual(appState.recordingState, .idle)
        XCTAssertFalse(appState.isModelLoaded)
        XCTAssertNil(appState.currentModelId)
        XCTAssertFalse(appState.isDownloadingModel)
    }

    func testRecordingStateTransitions() {
        appState.setRecordingState(.recording)
        XCTAssertEqual(appState.recordingState, .recording)
        XCTAssertTrue(appState.recordingState.isActive)

        appState.setRecordingState(.transcribing)
        XCTAssertEqual(appState.recordingState, .transcribing)
        XCTAssertTrue(appState.recordingState.isActive)

        appState.setRecordingState(.postProcessing)
        XCTAssertEqual(appState.recordingState, .postProcessing)
        XCTAssertTrue(appState.recordingState.isActive)

        appState.setRecordingState(.complete)
        XCTAssertEqual(appState.recordingState, .complete)
        XCTAssertFalse(appState.recordingState.isActive)

        appState.setRecordingState(.idle)
        XCTAssertEqual(appState.recordingState, .idle)
        XCTAssertFalse(appState.recordingState.isActive)
    }

    func testErrorState() {
        let errorMessage = "Test error"
        appState.setRecordingState(.error(errorMessage))

        if case .error(let message) = appState.recordingState {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected error state")
        }

        XCTAssertFalse(appState.recordingState.isActive)
    }

    func testModelLoadedState() {
        appState.setModelLoaded(true, modelId: "test-model")
        XCTAssertTrue(appState.isModelLoaded)
        XCTAssertEqual(appState.currentModelId, "test-model")

        appState.setModelLoaded(false, modelId: nil)
        XCTAssertFalse(appState.isModelLoaded)
        XCTAssertNil(appState.currentModelId)
    }

    func testAudioLevelUpdate() {
        appState.setAudioLevel(0.5)
        XCTAssertEqual(appState.audioLevel, 0.5, accuracy: 0.01)

        appState.setAudioLevel(0.0)
        XCTAssertEqual(appState.audioLevel, 0.0, accuracy: 0.01)

        appState.setAudioLevel(1.0)
        XCTAssertEqual(appState.audioLevel, 1.0, accuracy: 0.01)
    }

    func testDownloadedModelsManagement() {
        let modelId = "test-model-id"

        appState.addDownloadedModel(modelId)
        XCTAssertTrue(appState.downloadedModels.contains(modelId))

        appState.removeDownloadedModel(modelId)
        XCTAssertFalse(appState.downloadedModels.contains(modelId))
    }

    func testTranscriptionHistory() {
        let result1 = TranscriptionResult(text: "First transcription")
        let result2 = TranscriptionResult(text: "Second transcription")

        appState.setLastTranscription(result1)
        XCTAssertEqual(appState.lastTranscription?.text, "First transcription")
        XCTAssertEqual(appState.transcriptionHistory.count, 1)

        appState.setLastTranscription(result2)
        XCTAssertEqual(appState.lastTranscription?.text, "Second transcription")
        XCTAssertEqual(appState.transcriptionHistory.count, 2)

        // Newest should be first
        XCTAssertEqual(appState.transcriptionHistory.first?.text, "Second transcription")
    }

    func testFormattedRecordingDuration() {
        // Test that format is correct (this is a bit tricky since duration updates via timer)
        appState.setRecordingState(.idle)
        XCTAssertEqual(appState.formattedRecordingDuration, "0:00.0")
    }

    func testPermissionsState() {
        appState.setMicrophonePermission(true)
        XCTAssertTrue(appState.hasMicrophonePermission)

        appState.setMicrophonePermission(false)
        XCTAssertFalse(appState.hasMicrophonePermission)

        appState.setAccessibilityPermission(true)
        XCTAssertTrue(appState.hasAccessibilityPermission)

        appState.setAccessibilityPermission(false)
        XCTAssertFalse(appState.hasAccessibilityPermission)
    }

    func testOllamaAvailability() {
        appState.setOllamaAvailable(true)
        XCTAssertTrue(appState.isOllamaAvailable)

        appState.setOllamaAvailable(false)
        XCTAssertFalse(appState.isOllamaAvailable)
    }
}

final class RecordingStateTests: XCTestCase {

    func testDisplayText() {
        XCTAssertEqual(RecordingState.idle.displayText, "Ready")
        XCTAssertEqual(RecordingState.recording.displayText, "Recording...")
        XCTAssertEqual(RecordingState.transcribing.displayText, "Transcribing...")
        XCTAssertEqual(RecordingState.postProcessing.displayText, "Cleaning up...")
        XCTAssertEqual(RecordingState.complete.displayText, "Done")
        XCTAssertEqual(RecordingState.error("Test error").displayText, "Test error")
    }

    func testIsActive() {
        XCTAssertFalse(RecordingState.idle.isActive)
        XCTAssertTrue(RecordingState.recording.isActive)
        XCTAssertTrue(RecordingState.transcribing.isActive)
        XCTAssertTrue(RecordingState.postProcessing.isActive)
        XCTAssertFalse(RecordingState.complete.isActive)
        XCTAssertFalse(RecordingState.error("Error").isActive)
    }
}
