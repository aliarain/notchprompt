# NotchPrompt 🎙️

**NotchPrompt** is a lightweight, professional macOS teleprompter designed for creators, sales professionals, and educators. It hides seamlessly in your Mac's camera notch, ensuring perfect eye contact during video calls while remaining completely invisible to others on screen shares.

![NotchPrompt Banner](https://raw.githubusercontent.com/aliarain/notchprompt/main/Assets/banner.png)

## Core Innovation
- **True Eye Contact**: Positions text directly around your camera.
- **Screen-Share Invisible**: Uses native macOS window layering (`sharingType = .none`) to ensure the overlay is never seen on Zoom, Teams, Meet, or OBS.
- **Dynamic Notch Integration**: Smoothly expands and collapses from the notch for a premium, integrated feel.

## Key Features
- **3 Scroll Modes**:
    1. **Voice (AI Flow)**: Smart speech recognition follows your speaking pace.
    2. **Auto**: Consistent scrolling at your preferred Words Per Minute (WPM).
    3. **Manual**: Control with arrow keys or mouse wheel.
- **Cue Markers**: Visual badges for `[Smile]`, `[Pause]`, and `[CTA]` to sharpen your delivery.
- **Hover-to-Pause**: Instant control by just moving your mouse over the prompter.
- **Script Editor**: Manage multiple scripts, use professional templates, and track word counts.
- **Customizable**: Tweak font size, text colors, and background opacity to match your lighting.

## Shortcuts
| Shortcut | Action |
|----------|--------|
| **`⌃ + \``** | Toggle Overlay On/Off |
| **`⌃ + Space`** | Start/Stop Scrolling |
| `↑ / ↓` | Manual Scroll (Overlay focused) |
| `Space` | Play/Pause (Overlay focused) |
| `Esc` | Close Overlay |

## Installation

### Homebrew (Recommended)
```bash
brew install --cask notchprompt
```

### Manual
1. Download the latest `.dmg` from [Releases](https://github.com/aliarain/notchprompt/releases).
2. Drag **NotchPrompt** to your Applications folder.

## Development

### Prerequisites
- macOS 14.0+
- Xcode 15.0+

### Build Instructions
```bash
git clone https://github.com/aliarain/notch-prompt.git
cd notch-prompt
xcodebuild -project NotchPrompt.xcodeproj -scheme NotchPrompt build
```

## Contributing
We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Credits
Built with passion by:
- **[RaptrX](https://raptrx.com)**: Digital product studio building the future.
- **[Ali Arain](https://aliarain.com)**: Full-stack developer & tech entrepreneur.

## License
NotchPrompt is available under the **MIT License**. See `LICENSE` for more info.
