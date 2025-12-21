import SwiftUI
import AVFoundation

/// Advanced settings tab
struct AdvancedSettingsView: View {
    @State private var settings = SettingsManager.shared
    @State private var audioDevices: [AVCaptureDevice] = []
    @State private var vocabularyText = ""
    @State private var showingVocabularyEditor = false

    var body: some View {
        Form {
            Section {
                Toggle("Insert text directly", isOn: Binding(
                    get: { settings.insertDirectly },
                    set: { settings.insertDirectly = $0 }
                ))
                .help("Insert text by simulating paste. Disable to just copy to clipboard.")

                Toggle("Add trailing newline", isOn: Binding(
                    get: { settings.addTrailingNewline },
                    set: { settings.addTrailingNewline = $0 }
                ))
                .help("Add a newline character after the transcribed text.")
            } header: {
                Text("Text Insertion")
            }

            Section {
                Picker("Audio input device", selection: Binding(
                    get: { settings.selectedAudioInputDevice ?? "default" },
                    set: { settings.selectedAudioInputDevice = $0 == "default" ? nil : $0 }
                )) {
                    Text("Default").tag("default")
                    ForEach(audioDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }

                Button("Refresh Devices") {
                    loadAudioDevices()
                }
                .buttonStyle(.link)
            } header: {
                Text("Audio Input")
            }

            Section {
                HStack {
                    Text("Custom vocabulary")
                    Spacer()
                    Text("\(settings.customVocabulary.count) terms")
                        .foregroundStyle(.secondary)
                    Button("Edit...") {
                        vocabularyText = settings.customVocabulary.joined(separator: "\n")
                        showingVocabularyEditor = true
                    }
                }
            } header: {
                Text("Custom Vocabulary")
            } footer: {
                Text("Add technical terms, names, and other words for better recognition.")
            }

            if settings.recordingMode == .continuous {
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Silence threshold")
                            Spacer()
                            Text("\(Int(settings.silenceThreshold * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.silenceThreshold) },
                            set: { settings.silenceThreshold = Float($0) }
                        ), in: 0.01...0.1)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Silence duration")
                            Spacer()
                            Text("\(String(format: "%.1f", settings.silenceDuration))s")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { settings.silenceDuration },
                            set: { settings.silenceDuration = $0 }
                        ), in: 0.5...5.0, step: 0.5)
                    }
                } header: {
                    Text("Silence Detection")
                } footer: {
                    Text("In continuous mode, recording stops after detecting silence.")
                }
            }

            Section {
                Button("Reset All Settings", role: .destructive) {
                    settings.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadAudioDevices()
        }
        .sheet(isPresented: $showingVocabularyEditor) {
            VocabularyEditorView(
                vocabularyText: $vocabularyText,
                onSave: {
                    settings.customVocabulary = vocabularyText
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            )
        }
    }

    private func loadAudioDevices() {
        audioDevices = AudioRecorder.getAvailableInputDevices()
    }
}

// MARK: - Vocabulary Editor

struct VocabularyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var vocabularyText: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom Vocabulary")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            TextEditor(text: $vocabularyText)
                .font(.system(.body, design: .monospaced))
                .padding(8)

            Divider()

            HStack {
                Text("Enter one term per line. These will be used to improve transcription accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - Preview

#Preview {
    AdvancedSettingsView()
        .frame(width: 500, height: 500)
}
