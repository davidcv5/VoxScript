import SwiftUI

/// View for managing model downloads
struct ModelDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    private var appState = AppState.shared
    private var settings = SettingsManager.shared
    @State private var downloadingModelId: String?
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    @State private var isLoadingModel: Bool = false

    private let transcriptionEngine = TranscriptionEngine.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Models")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Model list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(WhisperModel.availableModels) { model in
                        ModelRow(
                            model: model,
                            isDownloaded: appState.downloadedModels.contains(model.id),
                            isSelected: appState.currentModelId == model.id,
                            isDownloading: downloadingModelId == model.id,
                            isLoading: isLoadingModel && settings.selectedModelId == model.id,
                            downloadProgress: downloadingModelId == model.id ? downloadProgress : 0,
                            onDownload: { downloadModel(model) },
                            onSelect: { selectModel(model) },
                            onDelete: { deleteModel(model) }
                        )
                    }
                }
                .padding()
            }

            if let error = downloadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        downloadError = nil
                    }
                    .buttonStyle(.link)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
            }
        }
        .frame(width: 450, height: 400)
    }

    private func downloadModel(_ model: WhisperModel) {
        downloadingModelId = model.id
        downloadProgress = 0
        downloadError = nil

        Task {
            do {
                try await transcriptionEngine.downloadModel(model.id) { progress in
                    Task { @MainActor in
                        downloadProgress = progress
                    }
                }

                await MainActor.run {
                    downloadingModelId = nil
                }
            } catch {
                await MainActor.run {
                    downloadingModelId = nil
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func selectModel(_ model: WhisperModel) {
        guard !isLoadingModel else { return }

        settings.selectedModelId = model.id
        isLoadingModel = true

        Task {
            do {
                try await transcriptionEngine.loadModel(model.id)
                await MainActor.run {
                    isLoadingModel = false
                }
            } catch {
                await MainActor.run {
                    isLoadingModel = false
                    downloadError = "Failed to load model: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteModel(_ model: WhisperModel) {
        // Remove from downloaded models
        appState.removeDownloadedModel(model.id)

        // If this was the selected model, select another
        if settings.selectedModelId == model.id {
            if let firstDownloaded = appState.downloadedModels.first {
                settings.selectedModelId = firstDownloaded
            }
        }

        // TODO: Actually delete model files
    }
}

struct ModelRow: View {
    let model: WhisperModel
    let isDownloaded: Bool
    let isSelected: Bool
    let isDownloading: Bool
    let isLoading: Bool
    let downloadProgress: Double
    let onDownload: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
            }

            // Model info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(model.name)
                        .font(.headline)

                    if model.isDefault {
                        Text("Recommended")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(isLoading ? "Loading..." : model.size)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            if isDownloading {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 80)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if isDownloaded {
                HStack(spacing: 8) {
                    if !isSelected && !isLoading {
                        Button("Use") {
                            onSelect()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !isLoading {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete model")
                    }
                }
            } else {
                Button("Download") {
                    onDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if isDownloaded && !isLoading && !isSelected {
                onSelect()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ModelDownloadView()
}
