import Foundation

/// Handles post-processing of transcriptions using local LLM via Ollama
final class PostProcessor {
    // MARK: - Singleton

    static let shared = PostProcessor()

    // MARK: - Properties

    private let ollamaBaseURL = URL(string: "http://localhost:11434")!
    private let settings = SettingsManager.shared
    private let appState = AppState.shared

    private let urlSession: URLSession

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        urlSession = URLSession(configuration: config)
    }

    // MARK: - Ollama Availability

    /// Check if Ollama is running and available
    func isOllamaAvailable() async -> Bool {
        let url = ollamaBaseURL.appendingPathComponent("api/version")

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            let available = httpResponse.statusCode == 200
            await MainActor.run {
                appState.setOllamaAvailable(available)
            }
            return available
        } catch {
            await MainActor.run {
                appState.setOllamaAvailable(false)
            }
            return false
        }
    }

    /// Get list of available Ollama models
    func getAvailableModels() async throws -> [OllamaModel] {
        let url = ollamaBaseURL.appendingPathComponent("api/tags")

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PostProcessorError.ollamaNotAvailable
        }

        let result = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return result.models
    }

    // MARK: - Text Cleanup

    /// Clean up transcribed text using Ollama
    func cleanup(text: String) async throws -> String {
        let model = settings.postProcessingModel

        // Build the prompt
        let prompt = buildCleanupPrompt(for: text)

        // Call Ollama generate endpoint
        let url = ollamaBaseURL.appendingPathComponent("api/generate")

        let requestBody = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: OllamaOptions(
                temperature: 0.1,
                top_p: 0.9,
                num_predict: 500
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostProcessorError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw PostProcessorError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

        // Clean up the response
        return cleanResponse(result.response, originalText: text)
    }

    // MARK: - Prompt Building

    private func buildCleanupPrompt(for text: String) -> String {
        var prompt = """
        Clean up this dictated text. Fix grammar, add proper punctuation, and ensure technical terms are correctly formatted. Preserve the original meaning exactly. Do not add or remove information. Output only the cleaned text with no explanation.

        Text: \(text)
        """

        // Add custom vocabulary context if available
        let customVocab = settings.customVocabulary
        if !customVocab.isEmpty {
            let vocabList = customVocab.joined(separator: ", ")
            prompt = """
            The following technical terms may appear in the text (ensure correct spelling): \(vocabList)

            \(prompt)
            """
        }

        return prompt
    }

    private func cleanResponse(_ response: String, originalText: String) -> String {
        var cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common LLM prefixes/suffixes
        let prefixesToRemove = [
            "Here is the cleaned text:",
            "Here's the cleaned text:",
            "Cleaned text:",
            "Output:",
            "Result:",
        ]

        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Remove quotes if the entire response is quoted
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 2 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // If the response is empty or very different in length, return original
        if cleaned.isEmpty || Double(cleaned.count) < Double(originalText.count) * 0.3 {
            return originalText
        }

        return cleaned
    }

    // MARK: - Streaming Cleanup

    /// Clean up text with streaming response (for real-time display)
    func cleanupStreaming(text: String, onChunk: @escaping (String) -> Void) async throws -> String {
        let model = settings.postProcessingModel
        let prompt = buildCleanupPrompt(for: text)

        let url = ollamaBaseURL.appendingPathComponent("api/generate")

        let requestBody = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: true,
            options: OllamaOptions(
                temperature: 0.1,
                top_p: 0.9,
                num_predict: 500
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PostProcessorError.requestFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        var fullResponse = ""

        for try await line in bytes.lines {
            if let data = line.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) {
                fullResponse += chunk.response
                onChunk(chunk.response)

                if chunk.done {
                    break
                }
            }
        }

        return cleanResponse(fullResponse, originalText: text)
    }
}

// MARK: - Ollama API Types

struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaOptions: Codable {
    let temperature: Double?
    let top_p: Double?
    let num_predict: Int?
}

struct OllamaGenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
    let context: [Int]?
    let total_duration: Int64?
    let load_duration: Int64?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int64?
    let eval_count: Int?
    let eval_duration: Int64?
}

struct OllamaStreamChunk: Codable {
    let model: String
    let response: String
    let done: Bool
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable, Identifiable, Hashable {
    let name: String
    let modified_at: String
    let size: Int64

    var id: String { name }

    var displayName: String {
        // Remove :latest suffix if present
        if name.hasSuffix(":latest") {
            return String(name.dropLast(7))
        }
        return name
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Errors

enum PostProcessorError: LocalizedError {
    case ollamaNotAvailable
    case modelNotFound
    case invalidResponse
    case requestFailed(statusCode: Int)
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .ollamaNotAvailable:
            return "Ollama is not running. Please start Ollama to enable post-processing."
        case .modelNotFound:
            return "The selected Ollama model is not available."
        case .invalidResponse:
            return "Received an invalid response from Ollama."
        case .requestFailed(let statusCode):
            return "Request to Ollama failed with status code \(statusCode)."
        case .processingFailed(let message):
            return "Post-processing failed: \(message)"
        }
    }
}
