import AVFoundation
import Foundation

/// Handles audio recording from the microphone
@Observable
final class AudioRecorder {
    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?

    private(set) var isRecording = false
    private(set) var audioLevel: Float = 0

    private let settings = SettingsManager.shared
    private let appState = AppState.shared

    // Audio buffer for streaming
    private var audioBuffer: [Float] = []
    private let bufferQueue = DispatchQueue(label: "com.voxscript.audiobuffer")

    // Silence detection
    private var silenceStartTime: Date?
    private var silenceDetectionEnabled = false

    // MARK: - Initialization

    init() {}

    // MARK: - Recording Control

    /// Start recording audio from the microphone
    /// - Returns: URL of the temporary audio file
    @discardableResult
    func startRecording() throws -> URL {
        guard !isRecording else {
            throw AudioRecorderError.alreadyRecording
        }

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voxscript_recording_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        tempFileURL = fileURL

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineCreationFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Validate format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw AudioRecorderError.invalidAudioFormat
        }

        // Create output format for WhisperKit (16kHz mono)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // Create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }

        // Create audio file with output format
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: audioSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        // Reset buffers
        bufferQueue.sync {
            audioBuffer.removeAll()
        }

        silenceStartTime = nil
        silenceDetectionEnabled = settings.recordingMode == .continuous

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }

        // Start engine
        try audioEngine.start()
        isRecording = true

        print("[VoxScript] Recording started, saving to: \(fileURL.path)")
        print("[VoxScript] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        return fileURL
    }

    /// Stop recording and return the audio file URL
    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        isRecording = false
        audioLevel = 0

        // Close the audio file properly
        audioFile = nil

        let url = tempFileURL
        print("[VoxScript] Recording stopped")
        if let url = url, let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
            print("[VoxScript] Recorded file size: \(size) bytes")
        }
        // Don't clear tempFileURL yet - caller needs to use it
        return url
    }

    /// Cancel recording and clean up
    func cancelRecording() {
        guard isRecording else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        isRecording = false
        audioLevel = 0

        // Delete temp file
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempFileURL = nil
    }

    /// Clean up the temporary file after transcription
    func cleanupTempFile() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        tempFileURL = nil
    }

    // MARK: - Audio Level Stream

    /// Get the current audio buffer for streaming transcription
    func getAudioBuffer() -> [Float] {
        bufferQueue.sync {
            let buffer = audioBuffer
            audioBuffer.removeAll()
            return buffer
        }
    }

    // MARK: - Private Methods

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
        // Calculate audio level from input
        calculateAudioLevel(from: buffer)

        // Convert to output format
        let outputFrameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate
        )

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCount
        ) else { return }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error else {
            print("Audio conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }

        // Write to file
        if let audioFile = audioFile {
            do {
                try audioFile.write(from: outputBuffer)
            } catch {
                print("Error writing audio file: \(error)")
            }
        }

        // Add to buffer for streaming
        if let channelData = outputBuffer.floatChannelData?[0] {
            let frames = Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
            bufferQueue.sync {
                audioBuffer.append(contentsOf: frames)
            }
        }

        // Check for silence in continuous mode
        if silenceDetectionEnabled {
            checkForSilence()
        }
    }

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameCount {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, 0.000001))

        // Normalize to 0-1 range (assuming -60 to 0 dB range)
        let normalized = max(0, min(1, (db + 60) / 60))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalized
            self?.appState.setAudioLevel(normalized)
        }
    }

    private func checkForSilence() {
        let threshold = settings.silenceThreshold
        let duration = settings.silenceDuration

        if audioLevel < threshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
                print("[VoxScript] Silence started (level: \(audioLevel), threshold: \(threshold))")
            } else if let startTime = silenceStartTime,
                      Date().timeIntervalSince(startTime) >= duration {
                // Silence threshold exceeded - notify to stop recording
                print("[VoxScript] Silence duration exceeded (\(duration)s), auto-stopping...")
                silenceStartTime = nil  // Reset to prevent multiple triggers
                silenceDetectionEnabled = false  // Disable further checks
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .silenceDetected,
                        object: nil
                    )
                }
            }
        } else {
            if silenceStartTime != nil {
                print("[VoxScript] Sound detected, resetting silence timer (level: \(audioLevel))")
            }
            silenceStartTime = nil
        }
    }

    // MARK: - Permissions

    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func checkMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    // MARK: - Audio Input Devices

    static func getAvailableInputDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case engineCreationFailed
    case invalidAudioFormat
    case converterCreationFailed
    case noMicrophonePermission

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .invalidAudioFormat:
            return "Invalid audio format from input device"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .noMicrophonePermission:
            return "Microphone access is required"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let silenceDetected = Notification.Name("silenceDetected")
}
