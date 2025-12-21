import XCTest
@testable import VoxScript

final class TranscriptionResultTests: XCTestCase {

    func testTranscriptionResultCreation() {
        let result = TranscriptionResult(
            text: "Hello world",
            rawText: "hello world",
            language: "en",
            duration: 2.5,
            processingTime: 0.5,
            wasPostProcessed: true
        )

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.rawText, "hello world")
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.duration, 2.5)
        XCTAssertEqual(result.processingTime, 0.5)
        XCTAssertTrue(result.wasPostProcessed)
    }

    func testWordCount() {
        let result = TranscriptionResult(text: "This is a test sentence")
        XCTAssertEqual(result.wordCount, 5)

        let singleWord = TranscriptionResult(text: "Hello")
        XCTAssertEqual(singleWord.wordCount, 1)

        let empty = TranscriptionResult(text: "")
        XCTAssertEqual(empty.wordCount, 0)
    }

    func testIsEmpty() {
        let empty = TranscriptionResult(text: "")
        XCTAssertTrue(empty.isEmpty)

        let whitespace = TranscriptionResult(text: "   \n\t  ")
        XCTAssertTrue(whitespace.isEmpty)

        let notEmpty = TranscriptionResult(text: "Hello")
        XCTAssertFalse(notEmpty.isEmpty)
    }

    func testDefaultRawText() {
        // When rawText is not provided, it should default to text
        let result = TranscriptionResult(text: "Hello world")
        XCTAssertEqual(result.rawText, "Hello world")
    }

    func testUniqueIdentifiers() {
        let result1 = TranscriptionResult(text: "Test 1")
        let result2 = TranscriptionResult(text: "Test 2")

        XCTAssertNotEqual(result1.id, result2.id)
    }
}

final class WhisperModelTests: XCTestCase {

    func testAvailableModels() {
        let models = WhisperModel.availableModels
        XCTAssertFalse(models.isEmpty)
    }

    func testDefaultModel() {
        let defaultModel = WhisperModel.defaultModel
        XCTAssertTrue(defaultModel.isDefault)
    }

    func testModelProperties() {
        let model = WhisperModel(
            id: "test-model",
            name: "Test Model",
            size: "100MB",
            sizeBytes: 104857600,
            isDownloaded: false,
            isDefault: false
        )

        XCTAssertEqual(model.id, "test-model")
        XCTAssertEqual(model.name, "Test Model")
        XCTAssertEqual(model.size, "100MB")
        XCTAssertEqual(model.sizeBytes, 104857600)
        XCTAssertFalse(model.isDownloaded)
        XCTAssertFalse(model.isDefault)
    }
}
