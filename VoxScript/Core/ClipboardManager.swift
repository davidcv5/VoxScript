import AppKit
import Carbon.HIToolbox
import ApplicationServices

/// Manages text insertion via clipboard or direct input
final class ClipboardManager {
    // MARK: - Singleton

    static let shared = ClipboardManager()

    // MARK: - Properties

    private let settings = SettingsManager.shared
    private var previousPasteboardContents: String?
    private var lastInsertionTime: Date?
    private var lastInsertedText: String?
    private let debounceInterval: TimeInterval = 0.5

    // MARK: - Initialization

    private init() {}

    // MARK: - Text Insertion

    /// Insert text at the current cursor position
    func insertText(_ text: String) {
        // Debounce: prevent duplicate insertions of the same text within short time window
        if let lastTime = lastInsertionTime,
           let lastText = lastInsertedText,
           Date().timeIntervalSince(lastTime) < debounceInterval,
           lastText == text {
            return
        }

        var finalText = text

        // Add trailing newline if enabled, but NOT for terminal apps (would execute command)
        if settings.addTrailingNewline && !isTerminalAppFocused() {
            finalText += "\n"
        }

        // Track this insertion for debouncing
        lastInsertionTime = Date()
        lastInsertedText = text

        if settings.insertDirectly {
            insertDirectly(finalText)
        } else {
            insertViaClipboard(finalText)
        }
    }

    // MARK: - Direct Insertion

    /// Insert text directly by simulating keyboard input
    private func insertDirectly(_ text: String) {
        // Terminal apps require CGEvent typing (AX reports success but doesn't insert)
        if isTerminalAppFocused() {
            if typeTextViaCGEvent(text) { return }
        } else {
            // Try Accessibility API first (most reliable for standard apps)
            if insertTextViaAccessibility(text) { return }

            // Fallback: Try typing character by character via CGEvent
            if typeTextViaCGEvent(text) { return }
        }

        // Last resort: clipboard + paste simulation
        savePasteboardContents()
        copyToClipboard(text)

        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulatePaste()

            // Restore previous clipboard contents after a longer delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.restorePasteboardContents()
            }
        }
    }

    /// Check if the frontmost app is a terminal emulator
    private func isTerminalAppFocused() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let bundleId = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName ?? ""

        // Known terminal emulators
        let terminalBundleIds = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "io.alacritty",
            "com.github.wez.wezterm",
            "co.zeit.hyper",
            "com.microsoft.VSCodeInsiders",
            "com.microsoft.VSCode",
            "dev.warp.Warp-Stable",
            "com.jetbrains.intellij",  // Has integrated terminal
            "org.tabby",
            "net.kovidgoyal.kitty"
        ]

        let terminalAppNames = [
            "Terminal", "iTerm", "iTerm2", "Alacritty", "WezTerm",
            "Hyper", "Warp", "kitty", "Tabby"
        ]

        return terminalBundleIds.contains(bundleId) ||
               terminalAppNames.contains { appName.contains($0) }
    }

    /// Insert text via clipboard without restoration
    private func insertViaClipboard(_ text: String) {
        copyToClipboard(text)
        simulatePaste()
    }

    // MARK: - Clipboard Operations

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func savePasteboardContents() {
        previousPasteboardContents = NSPasteboard.general.string(forType: .string)
    }

    private func restorePasteboardContents() {
        if let contents = previousPasteboardContents {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(contents, forType: .string)
        }
        previousPasteboardContents = nil
    }

    // MARK: - Keyboard Simulation

    private func simulatePaste() {
        // Try AppleScript first (more reliable)
        if simulatePasteViaAppleScript() { return }

        // Fallback to CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9  // 'V' key

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        usleep(10000)
        keyUp.post(tap: .cgSessionEventTap)
    }

    private func simulatePasteViaAppleScript() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }

    /// Insert text directly using Accessibility API
    private func insertTextViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return false
        }

        let axElement = element as! AXUIElement

        // Try to set the selected text (inserts at cursor position / replaces selection)
        let setResult = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if setResult == .success {
            return true
        }

        // Fallback: Try appending to entire value (for simple text fields)
        var currentValue: CFTypeRef?
        let getResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            &currentValue
        )

        if getResult == .success, let currentText = currentValue as? String {
            let newText = currentText + text
            let appendResult = AXUIElementSetAttributeValue(
                axElement,
                kAXValueAttribute as CFString,
                newText as CFTypeRef
            )
            if appendResult == .success {
                return true
            }
        }

        return false
    }

    /// Type text character by character using CGEvent with Unicode
    /// Returns true if at least one character was typed successfully
    private func typeTextViaCGEvent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }

        // Use hidSystemState for better compatibility with Terminal and other apps
        let source = CGEventSource(stateID: .hidSystemState)
        var successCount = 0

        for character in text {
            let string = String(character)

            // Create key events with virtual key 0 (we use Unicode string instead)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                continue
            }

            // Set the Unicode string for this character
            var chars = Array(string.utf16)
            keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

            // Post to cgAnnotatedSessionEventTap for better app compatibility
            keyDown.post(tap: .cgAnnotatedSessionEventTap)

            // Create and post key up event
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUp.post(tap: .cgAnnotatedSessionEventTap)
            }

            successCount += 1

            // Delay between characters for Terminal and virtualized apps
            usleep(20000)  // 20ms
        }

        return successCount > 0
    }

    /// Simulate typing text character by character (slower but more compatible)
    /// Public version for external use
    func typeText(_ text: String) {
        _ = typeTextViaCGEvent(text)
    }

    // MARK: - Clipboard Reading

    /// Get current clipboard text content
    func getClipboardText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Check if clipboard has text content
    func hasClipboardText() -> Bool {
        NSPasteboard.general.string(forType: .string) != nil
    }
}

// MARK: - CGEvent Extension for Unicode

extension CGEvent {
    func keyboardSetUnicodeString(string: String) {
        var chars = Array(string.utf16)
        keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
    }
}
