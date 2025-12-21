# VoxScript Implementation Notes

## Summary of Issues Encountered and Solutions

This document tracks all issues encountered during implementation and their solutions.

---

## 1. Build Errors

### 1.1 StatusBarController - KeyboardShortcuts API
**Issue:** `NSEvent.ModifierFlags has no member 'cocoaModifiers'` and `'Modifiers' is not a member type of struct 'KeyboardShortcuts.Shortcut'`

**Cause:** The KeyboardShortcuts library API doesn't have these extensions.

**Solution:** Removed the problematic extensions and simplified shortcut display with hardcoded modifiers.

---

### 1.2 OnboardingView - TabView Page Style
**Issue:** `.page(indexDisplayMode:)` is unavailable in macOS

**Cause:** TabView with page style is iOS-only.

**Solution:** Replaced TabView with a switch statement to show different onboarding steps.

---

### 1.3 TranscriptionEngine - WhisperKit 0.15.0 API
**Issue:** Multiple errors related to WhisperKit API changes:
- `WhisperKit.download` returns URL not String
- DecodingOptions parameters changed order
- CharacterSet reference issues

**Cause:** WhisperKit 0.15.0 has different API than older versions.

**Solution:** Rewrote TranscriptionEngine to use correct WhisperKit 0.15.0 API with proper DecodingOptions parameters and URL handling.

---

## 2. Runtime Issues

### 2.1 Model Download - Model Names Not Found
**Issue:** `No models found matching "*openai*large-v3-turbo/*"`

**Cause:** Model IDs didn't match the actual folder names in WhisperKit's HuggingFace repository.

**Solution:** Updated model IDs to match exact names from `argmaxinc/whisperkit-coreml`:
- `openai_whisper-large-v3`
- `openai_whisper-large-v3_turbo` (note: underscore before turbo)
- `openai_whisper-small.en`
- `openai_whisper-base`
- `openai_whisper-tiny`

---

### 2.2 Model Selection - Model Not Loading
**Issue:** Model downloaded but couldn't be selected/used. Settings showed model but recording failed.

**Cause:** ModelDownloadView created its own TranscriptionEngine instance instead of using the shared one. Model was loaded into a throwaway instance.

**Solution:** Made TranscriptionEngine a singleton (`TranscriptionEngine.shared`) so all code uses the same instance.

---

### 2.3 Keyboard Shortcuts - Not Triggering
**Issue:** Keyboard shortcuts configured but nothing happened when pressed.

**Cause:** `canStartRecording` returns false when no model is loaded, but no feedback was given to user.

**Solution:** Added `showCannotRecordAlert()` function to show floating panel explaining why recording can't start.

---

### 2.4 Microphone Permission - Not Requested
**Issue:** App checked permission but didn't request it.

**Cause:** `checkPermissions()` only checked status, didn't call `requestMicrophonePermission()`.

**Solution:** Updated `checkPermissions()` to actually request permission if not granted.

---

### 2.5 Transcription Empty Results
**Issue:** Recording worked but transcription returned empty string.

**Cause:** Initially suspected audio format issues, but was actually working - the issue was with text insertion.

**Solution:** Added debug logging to confirm transcription was working. Issue was in text insertion, not transcription.

---

## 3. Text Insertion Issues (ONGOING)

### 3.1 CGEvent Paste Not Working
**Issue:** `CGEvent` posting Cmd+V didn't paste text.

**Attempted Solutions:**
1. Changed from `.cghidEventTap` to `.cgSessionEventTap`
2. Changed event source from `.hidSystemState` to `.combinedSessionState`
3. Added delays between key events

**Status:** Still not working.

---

### 3.2 AppleScript Keystroke Not Working
**Issue:** AppleScript `keystroke "v" using command down` failed with "VoxScript is not allowed to send keystrokes"

**Cause:** Automation permission was granted but System Events still blocked keystrokes on macOS Sonoma.

**Attempted Solutions:**
1. Added `NSAppleEventsUsageDescription` to Info.plist
2. User granted Automation permission for System Events

**Status:** Still not working due to macOS Sonoma restrictions.

---

### 3.3 Accessibility API Direct Insertion (CURRENT)
**Issue:** Trying to insert text directly using AXUIElement API.

**Implementation:**
```swift
func insertTextViaAccessibility(_ text: String) -> Bool {
    let systemWide = AXUIElementCreateSystemWide()
    var focusedElement: CFTypeRef?
    AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, &focusedElement)
    AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute, text)
}
```

**Status:** Testing in progress.

---

## 4. Required Permissions Summary

The app requires these permissions:

1. **Microphone** - For audio recording
   - Entitlement: `com.apple.security.device.audio-input`
   - Info.plist: `NSMicrophoneUsageDescription`

2. **Accessibility** - For global hotkeys and text insertion
   - System Settings > Privacy & Security > Accessibility
   - Required for CGEvent posting

3. **Automation** (System Events) - For AppleScript keystroke simulation
   - Entitlement: `com.apple.security.automation.apple-events`
   - Info.plist: `NSAppleEventsUsageDescription`
   - System Settings > Privacy & Security > Automation > System Events

---

## 5. Key Technical Learnings

### WhisperKit Model Names
The WhisperKit models in `argmaxinc/whisperkit-coreml` use specific naming:
- Prefix: `openai_whisper-`
- Turbo variants use underscore: `_turbo` not `-turbo`
- Full list: https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main

### Text Insertion on macOS Sonoma
macOS Sonoma has stricter security for:
- CGEvent posting (even with Accessibility permission)
- AppleScript keystroke commands
- Best approach may be: Accessibility API (AXUIElement) for direct text insertion

### Singleton Pattern for Shared Resources
Components that need to share state (TranscriptionEngine, AppState, Settings) should be singletons to ensure consistent state across the app.

---

## 6. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        VoxScriptApp                         │
│                       (AppDelegate)                         │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐   ┌─────────────────┐   ┌────────────────┐
│ HotkeyManager │   │ StatusBarController│ │ FloatingPanel  │
│   (shared)    │   │    (shared)     │   │  Controller    │
└───────────────┘   └─────────────────┘   └────────────────┘
        │                                         │
        │ onToggleRecording                       │
        ▼                                         ▼
┌───────────────┐                         ┌────────────────┐
│ AudioRecorder │                         │ FloatingPanel  │
│               │                         │    View        │
└───────────────┘                         └────────────────┘
        │
        │ audioURL
        ▼
┌───────────────────┐
│ TranscriptionEngine│
│     (shared)      │
│   [WhisperKit]    │
└───────────────────┘
        │
        │ result.text
        ▼
┌───────────────────┐     ┌────────────────┐
│  PostProcessor    │────▶│    Ollama      │
│    (optional)     │     │  (localhost)   │
└───────────────────┘     └────────────────┘
        │
        │ cleanedText
        ▼
┌───────────────────┐
│ ClipboardManager  │
│     (shared)      │
│ [Text Insertion]  │
└───────────────────┘
        │
        │ Accessibility API / CGEvent / AppleScript
        ▼
┌───────────────────┐
│   Target App      │
│ (focused element) │
└───────────────────┘
```

---

## 7. Files Modified from Original PRD Structure

| PRD Structure | Actual Implementation | Notes |
|---------------|----------------------|-------|
| `Settings.swift` | `SettingsManager` + `KeyboardShortcuts.Name` extension | Split settings and keyboard shortcut definitions |
| `TranscriptionResult.swift` | Also contains `WhisperModel` struct | Combined model definitions |
| Single `SettingsView.swift` | Split into 5 tab views | Better organization |
| `Permissions.swift` | Added to Utilities | Permission helpers |
| `SoundPlayer.swift` | Added to Utilities | Audio feedback |

---

## 8. Dependencies

### Package.swift
```swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0")
]
```

### System Frameworks Used
- AVFoundation (audio recording)
- AppKit (window management, menu bar)
- SwiftUI (UI views)
- Carbon.HIToolbox (keyboard codes)
- ApplicationServices (Accessibility API - AXUIElement)
- CoreML (via WhisperKit)
