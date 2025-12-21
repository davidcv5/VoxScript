import Foundation
import SwiftUI
import KeyboardShortcuts

// MARK: - Keyboard Shortcuts Extension

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.command, .shift]))
    static let quickModelSwitch = Self("quickModelSwitch", default: .init(.m, modifiers: [.command, .shift]))
}

// MARK: - Settings Manager

/// Manages all application settings with persistence
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    // MARK: - General Settings

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.launchAtLogin) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.launchAtLogin) }
    }

    var playSounds: Bool {
        get { UserDefaults.standard.object(forKey: Keys.playSounds) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.playSounds) }
    }

    var showFloatingIndicator: Bool {
        get { UserDefaults.standard.object(forKey: Keys.showFloatingIndicator) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showFloatingIndicator) }
    }

    var recordingMode: RecordingMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: Keys.recordingMode),
                  let mode = RecordingMode(rawValue: rawValue) else {
                return .toggle
            }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.recordingMode) }
    }

    // MARK: - Transcription Settings

    var selectedModelId: String {
        get { UserDefaults.standard.string(forKey: Keys.selectedModel) ?? WhisperModel.defaultModel.id }
        set { UserDefaults.standard.set(newValue, forKey: Keys.selectedModel) }
    }

    var language: String {
        get { UserDefaults.standard.string(forKey: Keys.language) ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.language) }
    }

    var enablePostProcessing: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.enablePostProcessing) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.enablePostProcessing) }
    }

    var postProcessingModel: String {
        get { UserDefaults.standard.string(forKey: Keys.postProcessingModel) ?? "llama3.2:3b" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.postProcessingModel) }
    }

    // MARK: - Advanced Settings

    var insertDirectly: Bool {
        get { UserDefaults.standard.object(forKey: Keys.insertDirectly) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.insertDirectly) }
    }

    var addTrailingNewline: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.addTrailingNewline) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.addTrailingNewline) }
    }

    var customVocabulary: [String] {
        get { UserDefaults.standard.stringArray(forKey: Keys.customVocabulary) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.customVocabulary) }
    }

    var selectedAudioInputDevice: String? {
        get { UserDefaults.standard.string(forKey: Keys.audioInputDevice) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.audioInputDevice) }
    }

    // MARK: - Push-to-Talk Settings

    var pushToTalkKeyCode: UInt16 {
        get { UInt16(UserDefaults.standard.integer(forKey: Keys.pushToTalkKeyCode)) }
        set { UserDefaults.standard.set(Int(newValue), forKey: Keys.pushToTalkKeyCode) }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: - Floating Panel Position

    var floatingPanelPosition: CGPoint? {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.floatingPanelPosition),
                  let point = try? JSONDecoder().decode(CGPoint.self, from: data) else {
                return nil
            }
            return point
        }
        set {
            if let point = newValue, let data = try? JSONEncoder().encode(point) {
                UserDefaults.standard.set(data, forKey: Keys.floatingPanelPosition)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.floatingPanelPosition)
            }
        }
    }

    // MARK: - Silence Detection

    var silenceThreshold: Float {
        get { UserDefaults.standard.object(forKey: Keys.silenceThreshold) as? Float ?? 0.02 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.silenceThreshold) }
    }

    var silenceDuration: TimeInterval {
        get { UserDefaults.standard.object(forKey: Keys.silenceDuration) as? TimeInterval ?? 2.0 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.silenceDuration) }
    }

    // MARK: - Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let playSounds = "playSounds"
        static let showFloatingIndicator = "showFloatingIndicator"
        static let recordingMode = "recordingMode"
        static let selectedModel = "selectedModel"
        static let language = "language"
        static let enablePostProcessing = "enablePostProcessing"
        static let postProcessingModel = "postProcessingModel"
        static let insertDirectly = "insertDirectly"
        static let addTrailingNewline = "addTrailingNewline"
        static let customVocabulary = "customVocabulary"
        static let audioInputDevice = "audioInputDevice"
        static let pushToTalkKeyCode = "pushToTalkKeyCode"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let floatingPanelPosition = "floatingPanelPosition"
        static let silenceThreshold = "silenceThreshold"
        static let silenceDuration = "silenceDuration"
    }

    // MARK: - Initialization

    private init() {
        // Set default push-to-talk key to Right Command (0x36)
        if UserDefaults.standard.object(forKey: Keys.pushToTalkKeyCode) == nil {
            pushToTalkKeyCode = 0x36
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - CGPoint Codable Extension

extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

// MARK: - Supported Languages

struct SupportedLanguage: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String

    static let languages: [SupportedLanguage] = [
        SupportedLanguage(id: "auto", code: "auto", name: "Auto-detect"),
        SupportedLanguage(id: "en", code: "en", name: "English"),
        SupportedLanguage(id: "es", code: "es", name: "Spanish"),
        SupportedLanguage(id: "fr", code: "fr", name: "French"),
        SupportedLanguage(id: "de", code: "de", name: "German"),
        SupportedLanguage(id: "it", code: "it", name: "Italian"),
        SupportedLanguage(id: "pt", code: "pt", name: "Portuguese"),
        SupportedLanguage(id: "nl", code: "nl", name: "Dutch"),
        SupportedLanguage(id: "pl", code: "pl", name: "Polish"),
        SupportedLanguage(id: "ru", code: "ru", name: "Russian"),
        SupportedLanguage(id: "zh", code: "zh", name: "Chinese"),
        SupportedLanguage(id: "ja", code: "ja", name: "Japanese"),
        SupportedLanguage(id: "ko", code: "ko", name: "Korean")
    ]
}
