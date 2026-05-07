# NotchPrompt 🎙️

**NotchPrompt** is a professional macOS teleprompter that lives in your Mac's camera notch. It tracks your words in real time, stays invisible during screen shares, and works across Zoom, Teams, Meet, and OBS.

![NotchPrompt Banner](https://raw.githubusercontent.com/aliarain/notchprompt/main/Assets/banner.png)

---

## Why NotchPrompt

Most teleprompters are either hardware rigs or clunky apps that show up in screen recordings. NotchPrompt is different:

- **True eye contact** — text sits right next to your camera, not below it
- **Screen-share invisible** — uses `sharingType = .none` so it never appears in Zoom, Teams, Meet, or OBS recordings
- **Word-level tracking** — highlights each word as you say it, in real time, using on-device speech recognition
- **No subscription** — fully local, no cloud, no account required

---

## Features

### Overlay Modes
| Mode | Description |
|---|---|
| **Notch** | Anchored below the Mac notch. Expands with a Dynamic Island animation. |
| **Floating** | Draggable window you can place anywhere on screen. Always on top. |
| **Fullscreen** | Takes over an entire display. Perfect for a dedicated teleprompter monitor. |

### Listening Modes
| Mode | Description |
|---|---|
| **Word Tracking** | Highlights each word as you say it. Fuzzy matching handles accents and STT errors. |
| **Voice-Activated** | Scrolls while you speak, pauses when you go silent. |
| **Classic** | Auto-scrolls at a constant WPM. No microphone needed. |

### Script Management
- **Multi-page scripts** — split long scripts into pages, navigate between them in the sidebar
- **PPTX import** — drag a PowerPoint file to import presenter notes as pages
- **File save/open** — export and import `.notchprompt` files
- **Script templates** — Sales Pitch, Presentation, Interview, Blank
- **Dictation mode** — dictate text directly into the editor with your voice
- **Word count, char count, estimated read time** per page

### Overlay Controls
- **Tap-to-jump** — tap any word to jump the reading position there
- **Resizable height** — drag the handle to make the overlay taller on the fly
- **In-overlay page picker** — tap the page indicator to jump to any page
- **Auto next page** — configurable countdown (1–10s) auto-advances pages
- **Hover-to-pause** — move your mouse over the overlay to pause scrolling
- **Scroll wheel** — use trackpad or mouse wheel to scroll manually
- **Last spoken words** — shows the last few words you said next to the waveform
- **Audio waveform + progress** — live waveform with reading progress coloring
- **Elapsed time** — `MM:SS` timer showing how long you've been reading

### Appearance
- **Font families** — Sans, Serif, Mono, Dyslexia (OpenDyslexic)
- **Font sizes** — XS (14pt), SM (16pt), LG (20pt), XL (24pt)
- **Text colors** — White, Yellow, Cyan, Green, Lavender
- **Cue color + brightness** — separate color and opacity for `[bracket]` annotations
- **Blur background** — frosted glass effect with adjustable opacity
- **Background opacity** — adjust the overlay darkness

### System Integration
- **macOS Services** — right-click any text → "Read in NotchPrompt"
- **URL scheme** — `notchprompt://read?text=Your+script` from any app or script
- **Multi-display** — overlay follows your mouse to whichever screen it's on
- **Auto-update checker** — silent check on launch, prompt when update available
- **Read pages tracking** — green badge on pages already read this session

### Speech Settings
- **9 languages** — English (US/UK), Spanish, French, German, Italian, Portuguese, Japanese, Chinese
- **Microphone selection** — choose any CoreAudio input device
- **Keynote import warning** — helpful instructions when you drop a `.key` file

---

## Keyboard Shortcuts

### Overlay Controls
| Shortcut | Action |
|---|---|
| `↑ / ↓` | Scroll up / down |
| `Space` | Play / Pause (Classic mode) |
| `Esc` | Close overlay |

### Global Hotkeys (requires Accessibility permission)
| Shortcut | Action |
|---|---|
| `⌃ + \`` | Toggle overlay on/off |
| `⌃ + Space` | Start / Stop scrolling |
| `⇧⌘O` | Toggle overlay |
| `⇧⌘S` | Start / Stop scroll |
| `⇧⌘R` | Reset position |
| `⇧⌘]` | Next script |
| `⇧⌘[` | Previous script |

---

## Installation

### Manual
1. Download the latest `.dmg` from [Releases](https://github.com/aliarain/notchprompt/releases).
2. Drag **NotchPrompt** to your Applications folder.
3. Launch it — the icon appears in your menu bar.

### Homebrew
```bash
brew install --cask notchprompt
```

---

## Permissions

NotchPrompt needs two permissions for voice features:

- **Microphone** — for speech recognition in Word Tracking and Voice-Activated modes
- **Speech Recognition** — for on-device word matching

Both are requested on first use. Grant them in **System Settings → Privacy & Security**.

Classic mode works with no permissions at all.

---

## Development

### Requirements
- macOS 14.0+
- Xcode 15.0+

### Build
```bash
git clone https://github.com/aliarain/notchprompt.git
cd notchprompt
xcodebuild -project NotchPrompt.xcodeproj -scheme NotchPrompt build
```

### Project Structure
```
NotchPrompt/
├── App/
│   ├── NotchPromptApp.swift       # @main entry point
│   └── AppDelegate.swift          # Menu bar, overlay management, hotkeys
├── Views/
│   ├── OverlayPanelController.swift  # Notch / Floating / Fullscreen routing
│   ├── OverlayContentView.swift      # Main teleprompter UI
│   ├── WordFlowView.swift            # Word-level highlight layout engine
│   ├── ScriptEditorView.swift        # Script editor with multi-page support
│   └── SettingsView.swift            # 6-tab settings panel
├── Core/
│   ├── ScrollingController.swift     # All scroll modes + settings state
│   ├── SpeechRecognitionManager.swift # Word tracking + fuzzy matching
│   └── DictationManager.swift        # Editor dictation
├── Models/
│   └── Script.swift                  # Script model + CJK word splitting
├── Services/
│   ├── ScriptStorage.swift           # Persistence + PPTX import
│   └── UpdateChecker.swift           # GitHub releases checker
└── Helpers/
    └── Theme.swift                   # Colors, animations, button styles
```

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## Credits

Built by:
- **[RaptrX](https://raptrx.com)** — digital product studio
- **[Ali Arain](https://aliarain.com)** — developer & founder

---

## License

MIT License. See [LICENSE](LICENSE) for details.
