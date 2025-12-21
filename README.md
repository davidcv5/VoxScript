# VoxScript

**Local AI-powered dictation for macOS using WhisperKit**

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3-orange)](https://support.apple.com/en-us/HT211814)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   🎤 VoxScript - Local Dictation for macOS                     │
│                                                                 │
│   ┌─────────────┐    ┌──────────────┐    ┌─────────────┐       │
│   │   Record    │ -> │  WhisperKit  │ -> │  Insert at  │       │
│   │   Audio     │    │  Transcribe  │    │   Cursor    │       │
│   └─────────────┘    └──────────────┘    └─────────────┘       │
│                             │                                   │
│                             ▼                                   │
│                    ┌──────────────┐                            │
│                    │   Ollama     │                            │
│                    │  (Optional)  │                            │
│                    └──────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Features

- **100% Local Processing** - All transcription happens on-device using Apple Silicon
- **Global Hotkeys** - Press ⌘⇧Space anywhere to start/stop recording
- **Multiple Recording Modes** - Toggle, Push-to-Talk, or Continuous with silence detection
- **Optional Post-Processing** - Clean up text with local Ollama LLM
- **Menu Bar App** - Runs quietly in the background
- **Works Everywhere** - Text insertion works in standard apps AND terminal emulators

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     VoxScript.app                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    VoxScriptApp                        │  │
│  │                 (App Entry Point)                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│           ┌───────────────┼───────────────┐                 │
│           ▼               ▼               ▼                 │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────┐      │
│  │  StatusBar  │ │ FloatingPanel│ │   HotkeyManager │      │
│  │ Controller  │ │  Controller  │ │                 │      │
│  └─────────────┘ └──────────────┘ └─────────────────┘      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    Core Services                       │  │
│  ├──────────────┬───────────────┬──────────────────────┤  │
│  │AudioRecorder │TranscriptionE │    PostProcessor      │  │
│  │ (AVAudioEng) │ (WhisperKit)  │     (Ollama)         │  │
│  └──────────────┴───────────────┴──────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                      Models                            │  │
│  ├─────────────┬─────────────┬─────────────────────────┤  │
│  │  AppState   │  Settings   │  TranscriptionResult    │  │
│  └─────────────┴─────────────┴─────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** (M1/M2/M3/M4)
- **~1-2GB disk space** for Whisper model

## Installation

### Download Release

Download the latest DMG from the [Releases](../../releases) page.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/VoxScript.git
cd VoxScript

# Open in Xcode
open VoxScript.xcodeproj

# Build and Run (⌘R)
```

Or build via command line:

```bash
xcodebuild -project VoxScript.xcodeproj -scheme VoxScript -configuration Release
```

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | 0.15.0+ | Speech-to-text engine |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.0.0+ | Global hotkey handling |

### Optional

- [Ollama](https://ollama.ai) - For post-processing text cleanup (install separately)

## Usage

1. **Launch VoxScript** - It appears in the menu bar
2. **Press ⌘⇧Space** to start recording
3. **Speak** your text
4. **Press ⌘⇧Space** again to stop and transcribe
5. Text is **automatically inserted** at cursor

### First Run

On first launch, VoxScript will:
1. Request **Microphone** permission
2. Request **Accessibility** permission (for global shortcuts)
3. Download the default Whisper model (~1GB)

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle Recording | ⌘⇧Space |
| Cancel Recording | Escape |
| Open Settings | ⌘, |

## Recording Modes

| Mode | Behavior |
|------|----------|
| **Toggle** | Press to start, press again to stop |
| **Push-to-Talk** | Hold key to record, release to transcribe |
| **Continuous** | Auto-stops after detecting silence (2s) |

## Available Models

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| large-v3-turbo | ~950MB | Fast | Excellent |
| large-v3 | ~1.5GB | Slower | Best |
| small.en | ~460MB | Very fast | Good (English) |
| base | ~140MB | Fastest | Basic |
| tiny | ~75MB | Instant | Testing only |

## Data Flow

```
┌──────────┐     ┌───────────────┐     ┌──────────────┐
│ Mic/User │────▶│ AudioRecorder │────▶│ Temp WAV File│
└──────────┘     └───────────────┘     └──────────────┘
                                              │
                                              ▼
                       ┌──────────────────────────────────────┐
                       │        TranscriptionEngine           │
                       │  ┌──────────────────────────────┐   │
                       │  │         WhisperKit            │   │
                       │  │  ┌────────┐   ┌───────────┐  │   │
                       │  │  │ Model  │ + │ CoreML/ANE│  │   │
                       │  │  └────────┘   └───────────┘  │   │
                       │  └──────────────────────────────┘   │
                       └──────────────────────────────────────┘
                                              │
                                              ▼
                               ┌──────────────────────┐
                               │  TranscriptionResult │
                               │  { text, language }  │
                               └──────────────────────┘
                                              │
                         ┌────────────────────┼────────────────────┐
                         │                    │                    │
                         ▼                    │                    ▼
              ┌─────────────────┐            │         ┌─────────────────┐
              │ Post-Processing │◀───────────┘         │ ClipboardManager│
              │    (Optional)   │                      │                 │
              │ ┌─────────────┐ │                      │  ┌───────────┐  │
              │ │   Ollama    │ │                      │  │  Paste/   │  │
              │ │   llama3.2  │ │─────────────────────▶│  │  Insert   │  │
              │ └─────────────┘ │                      │  └───────────┘  │
              └─────────────────┘                      └─────────────────┘
                                                                │
                                                                ▼
                                                       ┌──────────────┐
                                                       │ Target App   │
                                                       │ (at cursor)  │
                                                       └──────────────┘
```

## Settings

Access via menu bar icon → Settings (⌘,)

- **General**: Launch at login, sounds, floating indicator
- **Transcription**: Model selection, language, post-processing
- **Shortcuts**: Customize keyboard shortcuts
- **Advanced**: Insert directly, trailing newline, silence detection

## Privacy

- **All processing happens locally** on your device
- **No data is sent** to any cloud service
- **Audio is only saved temporarily** during transcription
- **No telemetry** or usage tracking

## Project Structure

```
VoxScript/
├── Package.swift                    # Swift Package Manager dependencies
├── VoxScript.xcodeproj/
├── VoxScript/
│   ├── VoxScriptApp.swift           # Main app entry point
│   ├── Info.plist                   # App configuration
│   ├── VoxScript.entitlements       # Audio, automation entitlements
│   ├── Core/
│   │   ├── TranscriptionEngine.swift   # WhisperKit wrapper (singleton)
│   │   ├── AudioRecorder.swift         # AVAudioEngine recording
│   │   ├── HotkeyManager.swift         # KeyboardShortcuts wrapper
│   │   ├── ClipboardManager.swift      # Text insertion with terminal detection
│   │   └── PostProcessor.swift         # Ollama integration
│   ├── UI/
│   │   ├── FloatingPanel/              # Recording indicator
│   │   ├── Settings/                   # Settings tabs
│   │   ├── Onboarding/                 # First-run setup
│   │   └── MenuBar/                    # Status bar controller
│   ├── Models/
│   │   ├── AppState.swift              # Observable app state
│   │   ├── Settings.swift              # User preferences
│   │   └── TranscriptionResult.swift   # Result model
│   └── Utilities/
│       ├── Permissions.swift           # Permission helpers
│       └── SoundPlayer.swift           # Audio feedback
└── VoxScriptTests/                     # Unit tests
```

## Troubleshooting

### Text not inserting in Terminal/iTerm2

VoxScript automatically detects terminal apps and uses a different insertion method. If it's still not working:
1. Open Settings → Advanced
2. Disable "Insert directly"
3. Manually paste with ⌘V after transcription

### Model download fails

1. Check your internet connection
2. Try a smaller model first (base or tiny)
3. Check available disk space

### Shortcut not working

1. Ensure Accessibility permission is granted
2. Check System Settings → Privacy & Security → Accessibility
3. Toggle VoxScript off and on in the list

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax
- [Whisper](https://github.com/openai/whisper) by OpenAI
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- [Ollama](https://ollama.ai) for local LLM inference

## See Also

- [VoxScript PRD](../VoxScript-PRD.md) - Full product requirements document with implementation notes
