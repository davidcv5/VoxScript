import SwiftUI
import KeyboardShortcuts

/// Shortcuts settings tab
struct ShortcutsSettingsView: View {
    @State private var settings = SettingsManager.shared
    @State private var hasAccessibilityPermission = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle recording")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleRecording)
                }

                HStack {
                    Text("Quick model switch")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .quickModelSwitch)
                }
            } header: {
                Text("Keyboard Shortcuts")
            } footer: {
                Text("These shortcuts work globally, even when VoxScript is in the background.")
            }

            if settings.recordingMode == .pushToTalk {
                Section {
                    Picker("Push-to-talk key", selection: Binding(
                        get: { settings.pushToTalkKeyCode },
                        set: {
                            settings.pushToTalkKeyCode = $0
                            HotkeyManager.shared.setPushToTalkKey($0)
                        }
                    )) {
                        ForEach(KeyCodes.pushToTalkOptions, id: \.keyCode) { option in
                            Text(option.name).tag(option.keyCode)
                        }
                    }
                } header: {
                    Text("Push-to-Talk")
                } footer: {
                    Text("Hold this key to record, release to transcribe.")
                }
            }

            Section {
                HStack {
                    if hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Accessibility access granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Accessibility access required")
                    }
                    Spacer()

                    Button("Refresh") {
                        checkAccessibility()
                    }
                    .buttonStyle(.link)

                    if !hasAccessibilityPermission {
                        Button("Grant Access") {
                            HotkeyManager.requestAccessibilityPermission()
                            // Delay check to give user time to grant
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                checkAccessibility()
                            }
                        }
                    }
                }

                if !hasAccessibilityPermission {
                    Text("VoxScript needs accessibility access for global shortcuts and text insertion. After granting, click Refresh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkAccessibility()
        }
    }

    private func checkAccessibility() {
        hasAccessibilityPermission = HotkeyManager.checkAccessibilityPermission()
    }
}

// MARK: - Preview

#Preview {
    ShortcutsSettingsView()
        .frame(width: 500, height: 400)
}
