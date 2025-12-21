import Carbon.HIToolbox
import Cocoa
import KeyboardShortcuts

/// Manages global keyboard shortcuts using Carbon APIs and KeyboardShortcuts library
final class HotkeyManager {
    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Properties

    private var keyMonitor: Any?
    private var pushToTalkActive = false
    private var pushToTalkKeyCode: UInt16 = 0x36 // Right Command

    private let settings = SettingsManager.shared

    // Callbacks
    var onToggleRecording: (() -> Void)?
    var onPushToTalkStart: (() -> Void)?
    var onPushToTalkEnd: (() -> Void)?
    var onQuickModelSwitch: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    func setup() {
        // Setup keyboard shortcuts using KeyboardShortcuts library
        setupKeyboardShortcuts()

        // Setup push-to-talk key monitoring
        setupPushToTalkMonitor()
    }

    func teardown() {
        KeyboardShortcuts.reset(.toggleRecording)
        KeyboardShortcuts.reset(.quickModelSwitch)

        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        // Toggle recording shortcut
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            print("[VoxScript] Toggle recording shortcut triggered")
            self?.onToggleRecording?()
        }

        // Quick model switch shortcut
        KeyboardShortcuts.onKeyUp(for: .quickModelSwitch) { [weak self] in
            print("[VoxScript] Quick model switch shortcut triggered")
            self?.onQuickModelSwitch?()
        }

        print("[VoxScript] Keyboard shortcuts set up")
    }

    // MARK: - Push-to-Talk

    private func setupPushToTalkMonitor() {
        pushToTalkKeyCode = settings.pushToTalkKeyCode

        // Monitor for key events globally
        keyMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .keyUp]
        ) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Also monitor local events (when app is in foreground)
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Only handle push-to-talk in that mode
        guard settings.recordingMode == .pushToTalk else { return }

        // Check for the push-to-talk key
        if event.keyCode == pushToTalkKeyCode {
            if event.type == .flagsChanged {
                // For modifier keys (Command, Option, etc.)
                let isPressed = isModifierPressed(event)

                if isPressed && !pushToTalkActive {
                    pushToTalkActive = true
                    DispatchQueue.main.async { [weak self] in
                        self?.onPushToTalkStart?()
                    }
                } else if !isPressed && pushToTalkActive {
                    pushToTalkActive = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onPushToTalkEnd?()
                    }
                }
            }
        }
    }

    private func isModifierPressed(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 0x36, 0x37: // Right/Left Command
            return event.modifierFlags.contains(.command)
        case 0x38, 0x3C: // Left/Right Shift
            return event.modifierFlags.contains(.shift)
        case 0x3A, 0x3D: // Left/Right Option
            return event.modifierFlags.contains(.option)
        case 0x3B, 0x3E: // Left/Right Control
            return event.modifierFlags.contains(.control)
        default:
            return false
        }
    }

    // MARK: - Push-to-Talk Key Configuration

    func setPushToTalkKey(_ keyCode: UInt16) {
        pushToTalkKeyCode = keyCode
        settings.pushToTalkKeyCode = keyCode
    }

    // MARK: - Accessibility Permission

    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Key Code Constants

enum KeyCodes {
    // Letters
    static let a: UInt16 = 0x00
    static let s: UInt16 = 0x01
    static let d: UInt16 = 0x02
    static let f: UInt16 = 0x03
    static let h: UInt16 = 0x04
    static let g: UInt16 = 0x05
    static let z: UInt16 = 0x06
    static let x: UInt16 = 0x07
    static let c: UInt16 = 0x08
    static let v: UInt16 = 0x09
    static let b: UInt16 = 0x0B
    static let q: UInt16 = 0x0C
    static let w: UInt16 = 0x0D
    static let e: UInt16 = 0x0E
    static let r: UInt16 = 0x0F
    static let y: UInt16 = 0x10
    static let t: UInt16 = 0x11
    static let o: UInt16 = 0x13
    static let u: UInt16 = 0x14
    static let i: UInt16 = 0x22
    static let p: UInt16 = 0x23
    static let l: UInt16 = 0x25
    static let j: UInt16 = 0x26
    static let k: UInt16 = 0x28
    static let n: UInt16 = 0x2D
    static let m: UInt16 = 0x2E

    // Special keys
    static let space: UInt16 = 0x31
    static let returnKey: UInt16 = 0x24
    static let tab: UInt16 = 0x30
    static let escape: UInt16 = 0x35

    // Modifiers
    static let rightCommand: UInt16 = 0x36
    static let leftCommand: UInt16 = 0x37
    static let leftShift: UInt16 = 0x38
    static let capsLock: UInt16 = 0x39
    static let leftOption: UInt16 = 0x3A
    static let leftControl: UInt16 = 0x3B
    static let rightShift: UInt16 = 0x3C
    static let rightOption: UInt16 = 0x3D
    static let rightControl: UInt16 = 0x3E
    static let function: UInt16 = 0x3F

    // Function keys
    static let f1: UInt16 = 0x7A
    static let f2: UInt16 = 0x78
    static let f3: UInt16 = 0x63
    static let f4: UInt16 = 0x76
    static let f5: UInt16 = 0x60
    static let f6: UInt16 = 0x61
    static let f7: UInt16 = 0x62
    static let f8: UInt16 = 0x64
    static let f9: UInt16 = 0x65
    static let f10: UInt16 = 0x6D
    static let f11: UInt16 = 0x67
    static let f12: UInt16 = 0x6F

    /// Get display name for a key code
    static func displayName(for keyCode: UInt16) -> String {
        switch keyCode {
        case rightCommand: return "Right ⌘"
        case leftCommand: return "Left ⌘"
        case leftShift: return "Left ⇧"
        case rightShift: return "Right ⇧"
        case leftOption: return "Left ⌥"
        case rightOption: return "Right ⌥"
        case leftControl: return "Left ⌃"
        case rightControl: return "Right ⌃"
        case function: return "fn"
        case capsLock: return "⇪"
        case space: return "Space"
        case returnKey: return "Return"
        case tab: return "Tab"
        case escape: return "Escape"
        default: return "Key \(keyCode)"
        }
    }

    /// Available keys for push-to-talk
    static let pushToTalkOptions: [(keyCode: UInt16, name: String)] = [
        (rightCommand, "Right ⌘"),
        (leftCommand, "Left ⌘"),
        (rightShift, "Right ⇧"),
        (leftShift, "Left ⇧"),
        (rightOption, "Right ⌥"),
        (leftOption, "Left ⌥"),
        (rightControl, "Right ⌃"),
        (leftControl, "Left ⌃"),
        (function, "fn")
    ]
}
