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

    // MARK: - Initialization

    private init() {}

    // MARK: - Text Insertion

    /// Insert text at the current cursor position
    func insertText(_ text: String) {
        var finalText = text

        // Add trailing newline if enabled, but NOT for terminal apps (would execute command)
        if settings.addTrailingNewline && !isTerminalAppFocused() {
            finalText += "\n"
        }

        print("[VoxScript] ClipboardManager.insertText called with \(finalText.count) chars")
        print("[VoxScript] Insert directly setting: \(settings.insertDirectly)")

        if settings.insertDirectly {
            insertDirectly(finalText)
        } else {
            insertViaClipboard(finalText)
        }
    }

    // MARK: - Direct Insertion

    /// Insert text directly by simulating keyboard input
    private func insertDirectly(_ text: String) {
        // Check if we're in a terminal app - they report AX success but don't actually insert
        if isTerminalAppFocused() {
            print("[VoxScript] Terminal app detected, using CGEvent typing...")
            if typeTextViaCGEvent(text) {
                print("[VoxScript] CGEvent typing succeeded in terminal")
                return
            }
        } else {
            // Try Accessibility API first (most reliable for standard apps)
            if insertTextViaAccessibility(text) {
                return
            }

            // Fallback: Try typing character by character via CGEvent
            print("[VoxScript] Trying character-by-character typing...")
            if typeTextViaCGEvent(text) {
                print("[VoxScript] Character-by-character typing succeeded")
                return
            }
        }

        // Last resort: clipboard + paste simulation
        print("[VoxScript] Falling back to clipboard paste...")

        // Save current pasteboard contents
        savePasteboardContents()

        // Copy text to clipboard
        copyToClipboard(text)

        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // Simulate Cmd+V
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

        let isTerminal = terminalBundleIds.contains(bundleId) ||
                         terminalAppNames.contains { appName.contains($0) }

        if isTerminal {
            print("[VoxScript] Detected terminal app: \(appName) (\(bundleId))")
        }

        return isTerminal
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
        let success = pasteboard.setString(text, forType: .string)
        print("[VoxScript] Copied to clipboard: \(success), text length: \(text.count)")
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
        print("[VoxScript] simulatePaste() called")

        // Try AppleScript first (more reliable)
        if simulatePasteViaAppleScript() {
            print("[VoxScript] Paste via AppleScript succeeded")
            return
        }

        print("[VoxScript] AppleScript failed, trying CGEvent...")

        // Fallback to CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) else {
            print("[VoxScript] Failed to create keyDown event")
            return
        }
        keyDown.flags = .maskCommand

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("[VoxScript] Failed to create keyUp event")
            return
        }
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        usleep(10000)
        keyUp.post(tap: .cgSessionEventTap)
        print("[VoxScript] CGEvent Cmd+V posted")
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
            if let error = error {
                print("[VoxScript] AppleScript error: \(error)")
                return false
            }
            return true
        }
        return false
    }

    /// Insert text directly using Accessibility API
    private func insertTextViaAccessibility(_ text: String) -> Bool {
        print("[VoxScript] Trying Accessibility API insertion...")

        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get the focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            print("[VoxScript] Failed to get focused element: \(axErrorDescription(focusResult))")
            return false
        }

        let axElement = element as! AXUIElement

        // Log element info for debugging
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
        print("[VoxScript] Focused element role: \(role ?? "unknown" as CFTypeRef)")

        // Try to set the selected text (inserts at cursor position / replaces selection)
        let setResult = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        if setResult == .success {
            print("[VoxScript] Accessibility API insertion via kAXSelectedTextAttribute succeeded")
            return true
        }

        print("[VoxScript] kAXSelectedTextAttribute failed: \(axErrorDescription(setResult))")

        // Fallback: Try setting the entire value (for simple text fields)
        var currentValue: CFTypeRef?
        let getResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            &currentValue
        )

        if getResult == .success, let currentText = currentValue as? String {
            // Append text to current value
            let newText = currentText + text
            let appendResult = AXUIElementSetAttributeValue(
                axElement,
                kAXValueAttribute as CFString,
                newText as CFTypeRef
            )
            if appendResult == .success {
                print("[VoxScript] Accessibility API via kAXValueAttribute succeeded")
                return true
            }
            print("[VoxScript] kAXValueAttribute failed: \(axErrorDescription(appendResult))")
        } else {
            print("[VoxScript] Could not get kAXValueAttribute: \(axErrorDescription(getResult))")
        }

        return false
    }

    /// Convert AXError to human-readable description
    private func axErrorDescription(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure (general error)"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete (element busy or unresponsive)"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled (Accessibility not enabled)"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown error (\(error.rawValue))"
        }
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

            // Create key down event with virtual key 0 (we'll set Unicode instead)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                print("[VoxScript] Failed to create keyDown event for '\(character)'")
                continue
            }

            // Set the Unicode string for this character
            var chars = Array(string.utf16)
            keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

            // Post to cgAnnotatedSessionEventTap for better app compatibility
            keyDown.post(tap: .cgAnnotatedSessionEventTap)

            // Create key up event
            guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            keyUp.post(tap: .cgAnnotatedSessionEventTap)

            successCount += 1

            // Longer delay between characters for Terminal and virtualized apps
            usleep(20000) // 20ms - more reliable for Terminal
        }

        print("[VoxScript] Typed \(successCount)/\(text.count) characters via CGEvent")
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
