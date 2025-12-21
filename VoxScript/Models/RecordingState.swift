import Foundation

/// Represents the current state of the recording/transcription pipeline
enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case postProcessing
    case complete
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle, .complete, .error:
            return false
        case .recording, .transcribing, .postProcessing:
            return true
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .postProcessing:
            return "Cleaning up..."
        case .complete:
            return "Done"
        case .error(let message):
            return message
        }
    }
}

/// Recording modes supported by the application
enum RecordingMode: String, CaseIterable, Codable {
    case toggle = "toggle"
    case pushToTalk = "pushToTalk"
    case continuous = "continuous"

    var displayName: String {
        switch self {
        case .toggle:
            return "Toggle"
        case .pushToTalk:
            return "Push-to-Talk"
        case .continuous:
            return "Continuous"
        }
    }

    var description: String {
        switch self {
        case .toggle:
            return "Press to start, press again to stop"
        case .pushToTalk:
            return "Hold to record, release to transcribe"
        case .continuous:
            return "Auto-stop after silence"
        }
    }
}
