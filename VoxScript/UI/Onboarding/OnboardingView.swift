import SwiftUI

/// First-run onboarding flow
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var settings = SettingsManager.shared
    @State private var appState = AppState.shared

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            // Content
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep()
                case 1:
                    PermissionsStep()
                case 2:
                    ModelDownloadStep()
                case 3:
                    ShortcutStep()
                default:
                    WelcomeStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: currentStep)

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                    .buttonStyle(.link)
                }

                Spacer()

                if currentStep < totalSteps - 1 {
                    Button("Continue") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .frame(width: 500, height: 450)
    }

    private var canContinue: Bool {
        switch currentStep {
        case 1:
            // Permissions step - need at least microphone
            return appState.hasMicrophonePermission
        case 2:
            // Model step - need a model downloaded
            return !appState.downloadedModels.isEmpty
        default:
            return true
        }
    }

    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(.blue)

            Text("Welcome to VoxScript")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Local AI-powered dictation for macOS")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                FeatureItem(
                    icon: "lock.shield.fill",
                    title: "100% Private",
                    description: "All processing happens on your device"
                )

                FeatureItem(
                    icon: "bolt.fill",
                    title: "Lightning Fast",
                    description: "Optimized for Apple Silicon with WhisperKit"
                )

                FeatureItem(
                    icon: "text.cursor",
                    title: "Just Works",
                    description: "Press a shortcut, speak, and text appears"
                )
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()
        }
        .padding()
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStep: View {
    @State private var appState = AppState.shared
    @State private var hasMicrophone = false
    @State private var hasAccessibility = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "shield.checkered")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(.blue)

            Text("Permissions Required")
                .font(.title)
                .fontWeight(.bold)

            Text("VoxScript needs a few permissions to work properly")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "To record your voice",
                    isGranted: hasMicrophone,
                    onRequest: requestMicrophone
                )

                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "For global keyboard shortcuts",
                    isGranted: hasAccessibility,
                    onRequest: requestAccessibility
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        hasMicrophone = AudioRecorder.checkMicrophonePermission()
        hasAccessibility = HotkeyManager.checkAccessibilityPermission()

        appState.setMicrophonePermission(hasMicrophone)
        appState.setAccessibilityPermission(hasAccessibility)
    }

    private func requestMicrophone() {
        Task {
            let granted = await AudioRecorder.requestMicrophonePermission()
            await MainActor.run {
                hasMicrophone = granted
                appState.setMicrophonePermission(granted)
            }
        }
    }

    private func requestAccessibility() {
        HotkeyManager.requestAccessibilityPermission()
        // Check after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            hasAccessibility = HotkeyManager.checkAccessibilityPermission()
            appState.setAccessibilityPermission(hasAccessibility)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow") {
                    onRequest()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Model Download Step

struct ModelDownloadStep: View {
    @State private var appState = AppState.shared
    @State private var settings = SettingsManager.shared
    @State private var selectedModel = WhisperModel.defaultModel.id
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(.blue)

            Text("Download Model")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose a Whisper model to download")
                .font(.body)
                .foregroundStyle(.secondary)

            Picker("Model", selection: $selectedModel) {
                ForEach(WhisperModel.availableModels) { model in
                    HStack {
                        Text(model.name)
                        Spacer()
                        Text(model.size)
                            .foregroundStyle(.secondary)
                    }
                    .tag(model.id)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .disabled(isDownloading)
            .padding(.horizontal, 60)

            if isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 200)
                    Text("\(Int(downloadProgress * 100))% downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !isDownloading {
                Button(appState.downloadedModels.contains(selectedModel) ? "Downloaded ✓" : "Download") {
                    downloadModel()
                }
                .buttonStyle(.bordered)
                .disabled(appState.downloadedModels.contains(selectedModel))
            }

            Spacer()
        }
        .padding()
    }

    private func downloadModel() {
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        Task {
            do {
                try await TranscriptionEngine.shared.downloadModel(selectedModel) { progress in
                    Task { @MainActor in
                        downloadProgress = progress
                    }
                }

                await MainActor.run {
                    isDownloading = false
                    settings.selectedModelId = selectedModel
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Shortcut Step

struct ShortcutStep: View {
    @State private var settings = SettingsManager.shared
    @State private var testComplete = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "keyboard.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(.blue)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Use the keyboard shortcut to start recording")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                HStack {
                    Text("Toggle Recording")
                    Spacer()
                    Text("⌘ ⇧ Space")
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if settings.recordingMode == .pushToTalk {
                    HStack {
                        Text("Push-to-Talk")
                        Spacer()
                        Text("Hold Right ⌘")
                            .font(.system(.body, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 60)

            VStack(spacing: 8) {
                Text("Quick Tips")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    TipRow(text: "Look for the waveform icon in your menu bar")
                    TipRow(text: "Click the floating indicator to cancel recording")
                    TipRow(text: "Open Settings to customize shortcuts")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

struct TipRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
