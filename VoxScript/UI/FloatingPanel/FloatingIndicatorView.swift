import SwiftUI

/// The floating indicator view that shows recording state
struct FloatingIndicatorView: View {
    @State private var appState = AppState.shared

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            statusContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 200, height: 56)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onTapGesture {
            // Cancel recording on tap
            NotificationCenter.default.post(name: .cancelRecording, object: nil)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch appState.recordingState {
        case .recording:
            RecordingDot()

        case .transcribing:
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 16, height: 16)

        case .postProcessing:
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.purple)
                .frame(width: 16, height: 16)

        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .frame(width: 16, height: 16)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)
                .frame(width: 16, height: 16)

        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch appState.recordingState {
        case .recording:
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(appState.formattedRecordingDuration)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)

                    AudioLevelIndicator(level: appState.audioLevel)
                }
            }

        case .transcribing:
            Text("Transcribing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

        case .postProcessing:
            Text("Cleaning up...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

        case .complete:
            Text("Done!")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

        case .error(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

        case .idle:
            EmptyView()
        }
    }
}

// MARK: - Recording Dot

struct RecordingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 12, height: 12)
            .shadow(color: .red.opacity(isPulsing ? 0.6 : 0.3), radius: isPulsing ? 8 : 4)
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Audio Level Indicator

struct AudioLevelIndicator: View {
    let level: Float

    private let barCount = 5
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let maxHeight: CGFloat = 12

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let threshold = Float(index) / Float(barCount)
                let isActive = level > threshold
                let height = maxHeight * CGFloat(index + 1) / CGFloat(barCount)

                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive ? barColor(for: index) : Color.gray.opacity(0.3))
                    .frame(width: barWidth, height: height)
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
    }

    private func barColor(for index: Int) -> Color {
        if index < 3 {
            return .green
        } else if index < 4 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cancelRecording = Notification.Name("cancelRecording")
    static let showModelManager = Notification.Name("showModelManager")
    static let toggleRecording = Notification.Name("toggleRecording")
    static let selectModel = Notification.Name("selectModel")
    static let showSettings = Notification.Name("showSettings")
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FloatingIndicatorView()
    }
    .padding()
    .frame(width: 300, height: 200)
}
