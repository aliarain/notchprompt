# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NotchPrompt is a macOS menu bar teleprompter app. The overlay displays scripts below the MacBook notch/camera and is invisible during screen shares (Zoom, Teams, Meet, OBS).

## Build Commands

```bash
# Build project
xcodebuild -project NotchPrompt.xcodeproj -scheme NotchPrompt -configuration Debug build

# Build for release
xcodebuild -project NotchPrompt.xcodeproj -scheme NotchPrompt -configuration Release build

# Clean build
xcodebuild -project NotchPrompt.xcodeproj -scheme NotchPrompt clean

# Run tests
xcodebuild -project NotchPrompt.xcodeproj -scheme NotchPrompt test

# Open in Xcode
open NotchPrompt.xcodeproj
```

## Architecture

```text
Menu Bar Icon (NSStatusItem)
    ↓
┌─────────────────────────────┐
│ DynamicNotchKit             │ ← True notch integration
│ - Expands from Mac notch    │   (Dynamic Island-style)
│ - sharingType = .none       │   (invisible in screen shares)
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ TeleprompterContentView     │
│ - Script text display       │
│ - Scroll controls on hover  │
│ - Close button on hover     │
└─────────────────────────────┘
    ↓
┌─────────────────────────────┐
│ ScrollingController         │
│ - Manual (arrow keys)       │
│ - Auto (WPM-based timer)    │
│ - Voice (speech recognition)│
└─────────────────────────────┘
```

### File Structure

```text
NotchPrompt/
├── App/
│   ├── NotchPromptApp.swift       # @main entry point
│   └── AppDelegate.swift          # Menu bar + overlay management (@MainActor)
├── Views/
│   ├── OverlayPanelController.swift  # DynamicNotchKit integration
│   ├── OverlayContentView.swift      # TeleprompterContentView with hover controls
│   ├── ScriptEditorView.swift        # Script list + text editor
│   └── SettingsView.swift            # Appearance + scrolling settings
├── Core/
│   ├── ScrollingController.swift     # Manual/Auto/Voice scroll modes
│   └── SpeechRecognitionManager.swift # SFSpeechRecognizer integration
├── Models/
│   └── Script.swift                  # Script data model
├── Services/
│   └── ScriptStorage.swift           # UserDefaults persistence
└── Info.plist                        # LSUIElement=true for menu bar app
```

## Key Technical Details

**Screen Share Invisibility** - The critical line:

```swift
panel.sharingType = .none  // Makes overlay invisible in screen shares
```

**DynamicNotchKit Integration:**

```swift
let notch = DynamicNotch(
    hoverBehavior: [.keepVisible, .hapticFeedback],
    style: .auto
) {
    TeleprompterContentView(...)
}
await notch.expand()  // Shows from Mac notch
await notch.hide()    // Hides with animation
```

**Tech Stack:**

- Swift + SwiftUI + AppKit
- DynamicNotchKit for true notch integration (Dynamic Island-style)
- SFSpeechRecognizer for voice-activated scrolling
- UserDefaults for persistence
- macOS 14+ minimum deployment target

**App Type:** Menu bar app using NSStatusItem (no dock icon)

## Implemented Features

- **Notch Overlay** - Expands from Mac notch (Dynamic Island-style), invisible in screen shares
- **Hover Controls** - Close button and scroll controls appear on hover
- **Keyboard Shortcuts** - Arrow keys for scrolling, Space to toggle auto-scroll, ESC to close
- **Script Editor** - Create, edit, delete scripts with word count
- **3 Scroll Modes** - Manual (↑/↓ keys), Auto (WPM-based), Voice (speech recognition)
- **Settings** - Font size, text color, scroll speed
- **Persistence** - Scripts saved to UserDefaults

## Post-MVP Features

Deferred: AI script generation, CRM integrations, analytics, collaboration mode.
