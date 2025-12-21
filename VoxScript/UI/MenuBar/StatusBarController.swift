import AppKit
import SwiftUI
import KeyboardShortcuts

/// Manages the menu bar status item and its menu
final class StatusBarController {
    // MARK: - Singleton

    static let shared = StatusBarController()

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private let appState = AppState.shared
    private let settings = SettingsManager.shared

    // Callbacks
    var onToggleRecording: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onShowAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onModelSelected: ((String) -> Void)?
    var onDownloadModel: (() -> Void)?

    // Menu items that need updating
    private var recordingMenuItem: NSMenuItem?
    private var postProcessingMenuItem: NSMenuItem?
    private var modelSubmenu: NSMenu?

    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set icon
        button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoxScript")
        button.image?.isTemplate = true

        // Create menu
        buildMenu()
        statusItem?.menu = menu

        // Update menu when app state changes
        setupObservation()
    }

    func teardown() {
        updateTimer?.invalidate()
        updateTimer = nil
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    // MARK: - Menu Building

    private func buildMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false

        // Recording status/action
        recordingMenuItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: " "  // Space
        )
        recordingMenuItem?.target = self
        recordingMenuItem?.keyEquivalentModifierMask = [.command, .shift]

        menu?.addItem(recordingMenuItem!)
        menu?.addItem(NSMenuItem.separator())

        // Model submenu
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelSubmenu = NSMenu()
        buildModelSubmenu()
        modelItem.submenu = modelSubmenu
        menu?.addItem(modelItem)

        // Post-processing toggle
        postProcessingMenuItem = NSMenuItem(
            title: "Post-processing Enabled",
            action: #selector(togglePostProcessing),
            keyEquivalent: ""
        )
        postProcessingMenuItem?.target = self
        postProcessingMenuItem?.state = settings.enablePostProcessing ? .on : .off
        menu?.addItem(postProcessingMenuItem!)

        menu?.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About VoxScript",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu?.addItem(aboutItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit VoxScript",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    private func buildModelSubmenu() {
        modelSubmenu?.removeAllItems()

        let currentModelId = settings.selectedModelId

        for model in WhisperModel.availableModels {
            let isDownloaded = appState.downloadedModels.contains(model.id)
            let isCurrent = model.id == currentModelId

            let title = "\(model.name) (\(model.size))"
            let item = NSMenuItem(
                title: title,
                action: isDownloaded ? #selector(selectModel(_:)) : nil,
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = model.id
            item.state = isCurrent ? .on : .off

            if !isDownloaded {
                item.isEnabled = false
                item.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                )
            }

            modelSubmenu?.addItem(item)
        }

        modelSubmenu?.addItem(NSMenuItem.separator())

        let downloadItem = NSMenuItem(
            title: "Download Models...",
            action: #selector(downloadModels),
            keyEquivalent: ""
        )
        downloadItem.target = self
        modelSubmenu?.addItem(downloadItem)
    }

    // MARK: - Observation

    private func setupObservation() {
        // Periodic update for menu state
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuState()
            }
        }
    }

    // MARK: - Menu Updates

    func updateMenuState() {
        // Update recording menu item
        switch appState.recordingState {
        case .recording:
            recordingMenuItem?.title = "● Stop Recording"
            recordingMenuItem?.isEnabled = true
            updateStatusIcon(recording: true)

        case .transcribing, .postProcessing:
            recordingMenuItem?.title = "Processing..."
            recordingMenuItem?.isEnabled = false
            updateStatusIcon(recording: false)

        case .idle, .complete, .error:
            recordingMenuItem?.title = "Start Recording"
            recordingMenuItem?.isEnabled = appState.canStartRecording
            updateStatusIcon(recording: false)
        }

        // Update post-processing state
        postProcessingMenuItem?.state = settings.enablePostProcessing ? .on : .off

        // Rebuild model submenu if needed
        buildModelSubmenu()
    }

    private func updateStatusIcon(recording: Bool) {
        guard let button = statusItem?.button else { return }

        if recording {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
            button.contentTintColor = .systemRed
        } else {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoxScript")
            button.contentTintColor = nil
        }
        button.image?.isTemplate = !recording
    }

    // MARK: - Actions

    @objc private func toggleRecording() {
        onToggleRecording?()
    }

    @objc private func togglePostProcessing() {
        settings.enablePostProcessing.toggle()
        postProcessingMenuItem?.state = settings.enablePostProcessing ? .on : .off
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let modelId = sender.representedObject as? String else { return }
        onModelSelected?(modelId)
    }

    @objc private func downloadModels() {
        onDownloadModel?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func showAbout() {
        onShowAbout?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
