import SwiftUI

/// Transcription settings tab
struct TranscriptionSettingsView: View {
    @State private var settings = SettingsManager.shared
    @State private var appState = AppState.shared
    @State private var ollamaModels: [OllamaModel] = []
    @State private var isCheckingOllama = false

    var body: some View {
        Form {
            Section {
                Picker("Model", selection: Binding(
                    get: { settings.selectedModelId },
                    set: { settings.selectedModelId = $0 }
                )) {
                    ForEach(WhisperModel.availableModels) { model in
                        HStack {
                            Text(model.name)
                            Spacer()
                            Text(model.size)
                                .foregroundStyle(.secondary)
                            if !appState.downloadedModels.contains(model.id) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(model.id)
                    }
                }
                .disabled(appState.recordingState.isActive)

                Button("Manage Models...") {
                    NotificationCenter.default.post(name: .showModelManager, object: nil)
                }

                Picker("Language", selection: Binding(
                    get: { settings.language },
                    set: { settings.language = $0 }
                )) {
                    ForEach(SupportedLanguage.languages) { language in
                        Text(language.name).tag(language.code)
                    }
                }

            } header: {
                Text("Whisper Model")
            }

            Section {
                Toggle("Enable post-processing", isOn: Binding(
                    get: { settings.enablePostProcessing },
                    set: { settings.enablePostProcessing = $0 }
                ))
                .disabled(!appState.isOllamaAvailable)

                if settings.enablePostProcessing {
                    Picker("Post-processing model", selection: Binding(
                        get: { settings.postProcessingModel },
                        set: { settings.postProcessingModel = $0 }
                    )) {
                        if ollamaModels.isEmpty {
                            Text(settings.postProcessingModel).tag(settings.postProcessingModel)
                        } else {
                            ForEach(ollamaModels) { model in
                                Text(model.displayName).tag(model.name)
                            }
                        }
                    }
                    .disabled(!appState.isOllamaAvailable)
                }

                HStack {
                    if appState.isOllamaAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Ollama is running")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Ollama not detected")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Refresh") {
                        checkOllama()
                    }
                    .buttonStyle(.link)
                    .disabled(isCheckingOllama)
                }
                .font(.caption)

                if !appState.isOllamaAvailable {
                    Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
                        .font(.caption)
                }

            } header: {
                Text("Post-Processing (Optional)")
            } footer: {
                Text("Post-processing uses a local LLM to clean up grammar and formatting.")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkOllama()
        }
    }

    private func checkOllama() {
        isCheckingOllama = true
        Task {
            let available = await PostProcessor.shared.isOllamaAvailable()
            await MainActor.run {
                appState.setOllamaAvailable(available)
                isCheckingOllama = false

                if available {
                    loadOllamaModels()
                }
            }
        }
    }

    private func loadOllamaModels() {
        Task {
            do {
                let models = try await PostProcessor.shared.getAvailableModels()
                await MainActor.run {
                    ollamaModels = models
                }
            } catch {
                print("Failed to load Ollama models: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TranscriptionSettingsView()
        .frame(width: 500, height: 400)
}
