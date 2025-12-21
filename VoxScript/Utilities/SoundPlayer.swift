import AVFoundation
import AppKit

/// Utility class for playing sound effects
final class SoundPlayer {
    // MARK: - Singleton

    static let shared = SoundPlayer()

    // MARK: - Properties

    private var audioPlayer: AVAudioPlayer?
    private let settings = SettingsManager.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Sound Effects

    func playRecordingStart() {
        guard settings.playSounds else { return }
        playSystemSound(.hero)
    }

    func playRecordingStop() {
        guard settings.playSounds else { return }
        playSystemSound(.pop)
    }

    func playSuccess() {
        guard settings.playSounds else { return }
        playSystemSound(.glass)
    }

    func playError() {
        guard settings.playSounds else { return }
        playSystemSound(.basso)
    }

    // MARK: - System Sounds

    private enum SystemSound: String {
        case hero = "Hero"
        case pop = "Pop"
        case glass = "Glass"
        case basso = "Basso"
        case blow = "Blow"
        case bottle = "Bottle"
        case frog = "Frog"
        case funk = "Funk"
        case morse = "Morse"
        case ping = "Ping"
        case purr = "Purr"
        case sosumi = "Sosumi"
        case submarine = "Submarine"
        case tink = "Tink"
    }

    private func playSystemSound(_ sound: SystemSound) {
        let soundPath = "/System/Library/Sounds/\(sound.rawValue).aiff"

        guard FileManager.default.fileExists(atPath: soundPath) else {
            // Fallback to NSSound
            NSSound(named: sound.rawValue)?.play()
            return
        }

        let url = URL(fileURLWithPath: soundPath)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.5
            audioPlayer?.play()
        } catch {
            // Fallback to NSSound
            NSSound(named: sound.rawValue)?.play()
        }
    }

    // MARK: - Custom Sounds

    func playCustomSound(named name: String) {
        guard settings.playSounds else { return }

        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }
}
