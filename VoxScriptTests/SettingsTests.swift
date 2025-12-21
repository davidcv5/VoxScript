import XCTest
@testable import VoxScript

final class SettingsTests: XCTestCase {
    var settings: SettingsManager!

    override func setUp() {
        super.setUp()
        // Use a fresh instance for each test
        settings = SettingsManager.shared
    }

    override func tearDown() {
        // Reset defaults after each test
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        super.tearDown()
    }

    func testDefaultValues() {
        // Recording mode should default to toggle
        XCTAssertEqual(settings.recordingMode, .toggle)

        // Sounds should be on by default
        XCTAssertTrue(settings.playSounds)

        // Floating indicator should be shown by default
        XCTAssertTrue(settings.showFloatingIndicator)

        // Post-processing should be off by default
        XCTAssertFalse(settings.enablePostProcessing)

        // Insert directly should be on by default
        XCTAssertTrue(settings.insertDirectly)

        // Trailing newline should be off by default
        XCTAssertFalse(settings.addTrailingNewline)

        // Language should default to auto
        XCTAssertEqual(settings.language, "auto")
    }

    func testRecordingModePersistence() {
        settings.recordingMode = .pushToTalk
        XCTAssertEqual(settings.recordingMode, .pushToTalk)

        settings.recordingMode = .continuous
        XCTAssertEqual(settings.recordingMode, .continuous)

        settings.recordingMode = .toggle
        XCTAssertEqual(settings.recordingMode, .toggle)
    }

    func testBooleanSettingsPersistence() {
        settings.playSounds = false
        XCTAssertFalse(settings.playSounds)

        settings.showFloatingIndicator = false
        XCTAssertFalse(settings.showFloatingIndicator)

        settings.enablePostProcessing = true
        XCTAssertTrue(settings.enablePostProcessing)

        settings.addTrailingNewline = true
        XCTAssertTrue(settings.addTrailingNewline)
    }

    func testCustomVocabularyPersistence() {
        let vocabulary = ["SwiftUI", "WhisperKit", "CoreML"]
        settings.customVocabulary = vocabulary
        XCTAssertEqual(settings.customVocabulary, vocabulary)
    }

    func testFloatingPanelPositionPersistence() {
        let position = CGPoint(x: 100, y: 200)
        settings.floatingPanelPosition = position
        XCTAssertEqual(settings.floatingPanelPosition?.x, position.x)
        XCTAssertEqual(settings.floatingPanelPosition?.y, position.y)
    }

    func testSilenceDetectionSettings() {
        settings.silenceThreshold = 0.05
        XCTAssertEqual(settings.silenceThreshold, 0.05, accuracy: 0.001)

        settings.silenceDuration = 3.0
        XCTAssertEqual(settings.silenceDuration, 3.0, accuracy: 0.001)
    }
}
