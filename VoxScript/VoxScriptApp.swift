import SwiftUI
import AppKit
import Sparkle

// MARK: - Main App Entry Point

@main
struct VoxScriptApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window
        Settings {
            SettingsView()
        }

        // Model manager window - this WindowGroup may be required for proper app lifecycle
        WindowGroup(id: "model-manager") {
            ModelDownloadView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private let appState = AppState.shared
    private let settings = SettingsManager.shared
    private let statusBar = StatusBarController.shared
    private let floatingPanel = FloatingPanelController.shared
    private let hotkeyManager = HotkeyManager.shared
    private let audioRecorder = AudioRecorder()
    private let transcriptionEngine = TranscriptionEngine.shared
    private let postProcessor = PostProcessor.shared
    private let clipboardManager = ClipboardManager.shared
    private let soundPlayer = SoundPlayer.shared

    // Sparkle updater controller for auto-updates
    private var updaterController: SPUStandardUpdaterController!

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Setup components
        setupStatusBar()
        setupHotkeys()
        setupNotifications()

        // Check permissions
        checkPermissions()

        // Check Ollama availability
        checkOllama()

        // Load default model
        loadDefaultModel()

        // Show onboarding if needed
        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        hotkeyManager.teardown()
        statusBar.teardown()
        floatingPanel.hide()

        // Cancel any in-progress recording
        if appState.recordingState == .recording {
            audioRecorder.cancelRecording()
        }
    }

    // MARK: - Setup

    private func setupStatusBar() {
        statusBar.setup()

        statusBar.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }

        statusBar.onOpenSettings = { [weak self] in
            self?.showSettings()
        }

        statusBar.onShowAbout = {
            NSApp.orderFrontStandardAboutPanel(nil)
        }

        statusBar.onCheckForUpdates = { [weak self] in
            self?.updaterController.checkForUpdates(nil)
        }

        statusBar.onQuit = {
            NSApp.terminate(nil)
        }

        statusBar.onModelSelected = { [weak self] modelId in
            self?.switchModel(to: modelId)
        }

        statusBar.onDownloadModel = { [weak self] in
            self?.showModelManager()
        }
    }

    private func setupHotkeys() {
        hotkeyManager.setup()

        hotkeyManager.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }

        hotkeyManager.onPushToTalkStart = { [weak self] in
            self?.startRecording()
        }

        hotkeyManager.onPushToTalkEnd = { [weak self] in
            self?.stopRecording()
        }

        hotkeyManager.onQuickModelSwitch = { [weak self] in
            self?.cycleModel()
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCancelRecording),
            name: .cancelRecording,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSilenceDetected),
            name: .silenceDetected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowModelManager),
            name: .showModelManager,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleRecording),
            name: .toggleRecording,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSelectModel(_:)),
            name: .selectModel,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowSettings),
            name: .showSettings,
            object: nil
        )
    }

    // MARK: - Permissions

    private func checkPermissions() {
        // Check and request microphone permission
        if !Permissions.checkMicrophonePermission() {
            Task {
                let granted = await Permissions.requestMicrophonePermission()
                await MainActor.run {
                    appState.setMicrophonePermission(granted)
                }
            }
        } else {
            appState.setMicrophonePermission(true)
        }

        // Check accessibility permission
        appState.setAccessibilityPermission(Permissions.checkAccessibilityPermission())
    }

    private func checkOllama() {
        Task {
            let available = await postProcessor.isOllamaAvailable()
            await MainActor.run {
                appState.setOllamaAvailable(available)
            }
        }
    }

    // MARK: - Model Management

    private func loadDefaultModel() {
        let modelId = settings.selectedModelId

        // Check if model is downloaded
        guard appState.downloadedModels.contains(modelId) else {
            return
        }

        Task {
            do {
                try await transcriptionEngine.loadModel(modelId)
            } catch {
                await MainActor.run {
                    appState.setError(error)
                }
            }
        }
    }

    private func switchModel(to modelId: String) {
        settings.selectedModelId = modelId

        Task {
            do {
                try await transcriptionEngine.loadModel(modelId)
            } catch {
                await MainActor.run {
                    appState.setError(error)
                }
            }
        }
    }

    private func cycleModel() {
        let models = WhisperModel.availableModels.filter { appState.downloadedModels.contains($0.id) }
        guard models.count > 1 else { return }

        let currentIndex = models.firstIndex { $0.id == settings.selectedModelId } ?? 0
        let nextIndex = (currentIndex + 1) % models.count
        let nextModel = models[nextIndex]

        switchModel(to: nextModel.id)
    }

    // MARK: - Recording

    private func toggleRecording() {
        if appState.recordingState == .recording {
            stopRecording()
        } else if appState.canStartRecording {
            startRecording()
        } else {
            // Show why recording can't start
            showCannotRecordAlert()
        }
    }

    private func showCannotRecordAlert() {
        var message = "Cannot start recording:\n"

        if !appState.hasMicrophonePermission {
            message += "• Microphone access not granted\n"
        }

        if !appState.isModelLoaded {
            if appState.downloadedModels.isEmpty {
                message += "• No Whisper model downloaded\n"
            } else {
                message += "• Whisper model not loaded\n"
            }
        }

        if appState.recordingState.isActive {
            message += "• Recording already in progress\n"
        }

        // Show floating panel with error
        appState.setRecordingState(.error(message.trimmingCharacters(in: .newlines)))
        floatingPanel.show()
        soundPlayer.playError()

        // Hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.floatingPanel.hideAnimated()
            self?.appState.setRecordingState(.idle)
        }
    }

    private func startRecording() {
        guard appState.canStartRecording else {
            showCannotRecordAlert()
            return
        }

        do {
            try audioRecorder.startRecording()
            appState.setRecordingState(.recording)
            floatingPanel.show()
            soundPlayer.playRecordingStart()
        } catch {
            appState.setRecordingState(.error(error.localizedDescription))
            soundPlayer.playError()
        }
    }

    private func stopRecording() {
        guard appState.recordingState == .recording else { return }

        soundPlayer.playRecordingStop()

        guard let audioURL = audioRecorder.stopRecording() else {
            appState.setRecordingState(.error("No audio recorded"))
            floatingPanel.hideAnimated()
            return
        }

        processRecording(audioURL: audioURL)
    }

    private func processRecording(audioURL: URL) {
        appState.setRecordingState(.transcribing)

        Task {
            do {
                // Transcribe audio
                var result = try await transcriptionEngine.transcribe(audioURL: audioURL)

                // Post-process if enabled and available
                if settings.enablePostProcessing && appState.isOllamaAvailable && !result.text.isEmpty {
                    await MainActor.run {
                        appState.setRecordingState(.postProcessing)
                    }

                    let cleanedText = try await postProcessor.cleanup(text: result.text)
                    result = TranscriptionResult(
                        text: cleanedText,
                        rawText: result.text,
                        language: result.language,
                        duration: result.duration,
                        processingTime: result.processingTime,
                        wasPostProcessed: true
                    )
                }

                await MainActor.run {
                    // Store and display result
                    appState.setLastTranscription(result)

                    // Insert text at cursor
                    if !result.text.isEmpty {
                        clipboardManager.insertText(result.text)
                    }

                    // Complete
                    appState.setRecordingState(.complete)
                    soundPlayer.playSuccess()

                    // Hide panel after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.floatingPanel.hideAnimated()
                        self?.appState.setRecordingState(.idle)
                    }

                    // Cleanup temp audio file
                    audioRecorder.cleanupTempFile()
                }

            } catch {
                await MainActor.run {
                    appState.setRecordingState(.error(error.localizedDescription))
                    soundPlayer.playError()

                    // Hide panel after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.floatingPanel.hideAnimated()
                        self?.appState.setRecordingState(.idle)
                    }

                    audioRecorder.cleanupTempFile()
                }
            }
        }
    }

    @objc private func handleCancelRecording() {
        if appState.recordingState == .recording {
            audioRecorder.cancelRecording()
            appState.setRecordingState(.idle)
            floatingPanel.hideAnimated()
        }
    }

    @objc private func handleSilenceDetected() {
        if appState.recordingState == .recording && settings.recordingMode == .continuous {
            stopRecording()
        }
    }

    @objc private func handleShowModelManager() {
        showModelManager()
    }

    @objc private func handleToggleRecording() {
        toggleRecording()
    }

    @objc private func handleSelectModel(_ notification: Notification) {
        if let modelId = notification.object as? String {
            switchModel(to: modelId)
        }
    }

    @objc private func handleShowSettings() {
        showSettings()
    }

    // MARK: - Windows

    private func showSettings() {
        if let settingsWindow = settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoxScript Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to VoxScript"
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }

    private var modelManagerWindow: NSWindow?

    private func showModelManager() {
        // Check if window already exists and show it
        if let window = modelManagerWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Model Manager"
        window.contentView = NSHostingView(rootView: ModelDownloadView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        modelManagerWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }
}
