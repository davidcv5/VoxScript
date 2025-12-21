import AppKit
import SwiftUI

/// Controls the floating indicator panel that shows during recording
final class FloatingPanelController {
    // MARK: - Singleton

    static let shared = FloatingPanelController()

    // MARK: - Properties

    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingIndicatorView>?
    private let settings = SettingsManager.shared
    private let appState = AppState.shared

    // Panel dimensions
    private let panelWidth: CGFloat = 200
    private let panelHeight: CGFloat = 56
    private let topOffset: CGFloat = 60

    // MARK: - Initialization

    private init() {}

    // MARK: - Panel Control

    /// Show the floating panel
    func show() {
        guard settings.showFloatingIndicator else { return }

        if panel == nil {
            createPanel()
        }

        updatePosition()
        panel?.orderFrontRegardless()
    }

    /// Hide the floating panel
    func hide() {
        panel?.orderOut(nil)
    }

    /// Hide with fade animation
    func hideAnimated() {
        guard let panel = panel else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel?.alphaValue = 1
        }
    }

    // MARK: - Panel Creation

    private func createPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        guard let panel = panel else { return }

        // Configure panel
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.animationBehavior = .utilityWindow

        // Set initial position
        updatePosition()

        // Create SwiftUI content
        let indicatorView = FloatingIndicatorView()
        hostingView = NSHostingView(rootView: indicatorView)
        panel.contentView = hostingView

        // Track position changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    private func updatePosition() {
        guard let panel = panel, let screen = NSScreen.main else { return }

        // Use saved position or default to top center
        if let savedPosition = settings.floatingPanelPosition {
            panel.setFrameOrigin(NSPoint(x: savedPosition.x, y: savedPosition.y))
        } else {
            let x = (screen.frame.width - panelWidth) / 2
            let y = screen.frame.height - topOffset - panelHeight
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    @objc private func panelDidMove(_ notification: Notification) {
        guard let panel = panel else { return }
        settings.floatingPanelPosition = CGPoint(x: panel.frame.origin.x, y: panel.frame.origin.y)
    }

    // MARK: - Cleanup

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
