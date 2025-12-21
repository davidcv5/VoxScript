import SwiftUI

/// About settings tab
struct AboutSettingsView: View {
    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon and name
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue)

                Text("VoxScript")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("Local AI-powered dictation for macOS")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Features
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "lock.fill", text: "100% local processing")
                FeatureRow(icon: "bolt.fill", text: "Powered by WhisperKit")
                FeatureRow(icon: "keyboard", text: "Global keyboard shortcuts")
                FeatureRow(icon: "sparkles", text: "Optional AI cleanup with Ollama")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Links
            HStack(spacing: 24) {
                Link(destination: URL(string: "https://github.com/argmaxinc/WhisperKit")!) {
                    Label("WhisperKit", systemImage: "link")
                }

                Link(destination: URL(string: "https://ollama.ai")!) {
                    Label("Ollama", systemImage: "link")
                }
            }
            .font(.caption)

            Spacer()

            // Copyright
            Text("© 2024 VoxScript. Open source under MIT license.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    AboutSettingsView()
        .frame(width: 500, height: 400)
}
