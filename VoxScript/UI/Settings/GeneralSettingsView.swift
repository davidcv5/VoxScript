import SwiftUI
import ServiceManagement

/// General settings tab
struct GeneralSettingsView: View {
    private let settings = SettingsManager.shared
    @State private var launchAtLogin = false
    @State private var playSounds = true
    @State private var showFloatingIndicator = true
    @State private var selectedMode: RecordingMode = .toggle

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                        settings.launchAtLogin = newValue
                    }

                Toggle("Play sound effects", isOn: $playSounds)
                    .onChange(of: playSounds) { _, newValue in
                        settings.playSounds = newValue
                    }
                    .help("Play sounds when recording starts and stops")

                Toggle("Show floating indicator", isOn: $showFloatingIndicator)
                    .onChange(of: showFloatingIndicator) { _, newValue in
                        settings.showFloatingIndicator = newValue
                    }
                    .help("Show a floating panel during recording")

            } header: {
                Text("Behavior")
            }

            Section {
                Picker("Recording mode", selection: $selectedMode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: selectedMode) { _, newValue in
                    settings.recordingMode = newValue
                    print("[VoxScript] Recording mode changed to: \(newValue.displayName)")
                }

                Text(selectedMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } header: {
                Text("Recording Mode")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = settings.launchAtLogin
            playSounds = settings.playSounds
            showFloatingIndicator = settings.showFloatingIndicator
            selectedMode = settings.recordingMode
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsView()
        .frame(width: 500, height: 400)
}
