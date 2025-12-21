import XCTest
@testable import VoxScript

final class PostProcessorTests: XCTestCase {

    func testOllamaModelProperties() {
        let model = OllamaModel(
            name: "llama3.2:latest",
            modified_at: "2024-01-01T00:00:00Z",
            size: 2147483648 // 2GB
        )

        XCTAssertEqual(model.id, "llama3.2:latest")
        XCTAssertEqual(model.displayName, "llama3.2")
        XCTAssertFalse(model.formattedSize.isEmpty)
    }

    func testOllamaModelWithoutLatestSuffix() {
        let model = OllamaModel(
            name: "llama3.2:3b",
            modified_at: "2024-01-01T00:00:00Z",
            size: 2147483648
        )

        XCTAssertEqual(model.displayName, "llama3.2:3b")
    }

    func testPostProcessorErrorDescriptions() {
        XCTAssertFalse(PostProcessorError.ollamaNotAvailable.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PostProcessorError.modelNotFound.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PostProcessorError.invalidResponse.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PostProcessorError.requestFailed(statusCode: 500).errorDescription?.isEmpty ?? true)
        XCTAssertFalse(PostProcessorError.processingFailed("error").errorDescription?.isEmpty ?? true)
    }
}
