# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NotchPrompt is a macOS menu bar teleprompter app. The overlay displays scripts below the MacBook notch/camera and is invisible during screen shares (Zoom, Teams, Meet, OBS).

## Build Commands

```bash
# Build project
xcodebuild -project notchapp.xcodeproj -scheme notchapp -configuration Debug build

# Build for release
xcodebuild -project notchapp.xcodeproj -scheme notchapp -configuration Release build

# Clean build
xcodebuild -project notchapp.xcodeproj -scheme notchapp clean

# Run tests
xcodebuild -project notchapp.xcodeproj -scheme notchapp test

# Open in Xcode
open notchapp.xcodeproj
```

## Architecture

```
Menu Bar Icon (NSStatusItem)
    ↓
┌─────────────────────────────┐
│ Overlay Panel               │ ← NSPanel, sharingType = .none
│ - Script text display       │   (invisible in screen shares)
│ - Scroll controls           │
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

```
notchapp/
├── App/
│   ├── NotchPromptApp.swift       # @main entry point
│   └── AppDelegate.swift          # Menu bar + overlay management
├── Views/
│   ├── OverlayPanelController.swift  # NSPanel setup with sharingType = .none
│   ├── OverlayContentView.swift      # Script display with scroll controls
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
panel.level = .floating
```

**Tech Stack:**
- Swift + SwiftUI + AppKit
- NSPanel for floating overlay window
- SFSpeechRecognizer for voice-activated scrolling
- UserDefaults + JSON files for storage
- macOS 14+ minimum deployment target

**App Type:** Menu bar app using NSStatusItem (no dock icon)

## Implemented Features

- **Overlay** - Floating panel below notch, invisible in screen shares
- **Script Editor** - Create, edit, delete scripts with word count
- **3 Scroll Modes** - Manual (↑/↓ keys), Auto (WPM-based), Voice (speech recognition)
- **Settings** - Font size, opacity, text color, scroll speed
- **Persistence** - Scripts saved to UserDefaults

## Post-MVP Features

Deferred: AI script generation, CRM integrations, analytics, collaboration mode.
