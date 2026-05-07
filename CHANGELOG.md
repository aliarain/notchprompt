# NotchPrompt Changelog

---

## v2.0.0 — Major Feature Release

This is the biggest update since launch. NotchPrompt is now a fully-featured professional teleprompter that matches and exceeds the competition on every dimension.

---

### 🆕 What's New

#### Word-Level Real-Time Highlighting
The overlay now highlights each word as you speak it, in real time. Powered by a fuzzy character + word-level matching algorithm that handles speech recognition errors, accents, and fast speech gracefully. The current word is underlined; read words dim; unread words stay bright. Tap any word to jump the highlight to that position.

#### 3 Listening Modes
- **Word Tracking** — highlights each word as you say it. The most accurate mode.
- **Classic** — auto-scrolls at a constant WPM. No microphone needed.
- **Voice-Activated** — scrolls while you speak, pauses when you go silent.

#### Multi-Page Scripts
Scripts now support multiple pages. Add pages in the editor, navigate between them in the sidebar, and the overlay shows a "Next Page" button when a page finishes. Pages can be imported from PowerPoint presenter notes.

#### Floating & Fullscreen Overlay Modes
Three overlay modes now available:
- **Notch** (default) — anchored below the Mac notch, invisible in screen shares.
- **Floating** — a draggable, always-on-top window you can place anywhere on screen.
- **Fullscreen** — takes over an entire display. Perfect for a dedicated teleprompter monitor.

#### Resizable Overlay
Drag the handle at the bottom of the notch overlay to make it taller on the fly — no need to open settings.

#### In-Overlay Page Picker
Tap the page indicator (`1/3`) in the overlay control bar to open a page picker showing all pages with previews. Jump to any page instantly. Long-press also works.

#### Auto Next Page with Countdown
When a page finishes, a configurable countdown (1–10 seconds) auto-advances to the next page. A cancel button lets you stop it. Toggle in Settings → Scrolling.

#### Overlay Transparency / Blur Background
The overlay can now use a frosted glass blur-behind effect instead of solid black. Adjustable opacity. Toggle in Settings → Appearance.

#### Font Family Presets
Four font families: **Sans** (system), **Serif**, **Mono**, and **Dyslexia** (OpenDyslexic). Pick the one that works best for your reading style.

#### Font Size Presets
Four size presets: XS (14pt), SM (16pt), LG (20pt), XL (24pt).

#### Cue Color + Brightness
Separate color picker for `[bracket]` annotation cues, plus a brightness slider (Dim / Low / Medium / Bright) that controls how visible unread vs. read cues are.

#### Last Spoken Words Display
In word-tracking mode, the last few words you spoke appear next to the waveform in the overlay — so you can confirm the mic is picking you up correctly.

#### Audio Waveform + Progress Bar
A live audio waveform with progress coloring shows your reading progress and mic activity in the overlay control bar.

#### Elapsed Time Display
A `MM:SS` timer in the overlay shows how long you've been reading. Toggle in Settings → Appearance.

#### Speech Language Selection
Pick your speech recognition language from 9 locales: English (US/UK), Spanish, French, German, Italian, Portuguese (BR), Japanese, Chinese (Simplified).

#### Microphone Selection
Choose which input device to use for speech recognition. Lists all available CoreAudio input devices.

#### PPTX Import
Drag and drop a PowerPoint `.pptx` file onto the script editor to import presenter notes as pages. Each slide's notes become a separate page.

#### File Save / Open
Export scripts as `.notchprompt` files and re-import them. Useful for sharing scripts between machines or keeping backups.

#### Dictation Mode in Editor
A mic button in the script editor lets you dictate text directly into your script using speech-to-text. Recognized text is inserted at the cursor position.

#### Read Pages Tracking
Pages you've already read in the current session get a green badge in the page sidebar.

#### Auto-Update Checker
NotchPrompt silently checks for updates on launch and shows a prompt when a new version is available. Also accessible from the menu bar via "Check for Updates…".

#### macOS Services Integration
Select any text in any app, right-click, and choose "Read in NotchPrompt" to instantly open the overlay with that text.

#### URL Scheme
Trigger the teleprompter from other apps or scripts: `notchprompt://read?text=Your+script+here`

#### Multi-Display Support
The overlay follows your mouse to whichever display it's on. Toggle between "Follow Mouse" and "Fixed Display" in Settings → Overlay.

#### Keynote Import Warning
Dropping a `.key` file now shows a helpful alert with exact instructions for exporting as PPTX from Keynote, instead of a generic error.

#### Tap-to-Jump
Tap any word in the overlay to jump the reading position to that word. Works in all listening modes.

#### Scroll Wheel Support
Use your trackpad or mouse wheel to manually scroll through the script in the overlay.

---

### 🔧 Improvements
- Overlay control bar now shows mic toggle, waveform, page indicator, and last spoken words all in one compact row
- Settings reorganized into 6 tabs: Appearance, Guidance, Scrolling, Overlay, Shortcuts, About
- Script editor now shows page count and word count per page
- ESC key closes the page picker before closing the overlay
- All new settings persist across app restarts

---

### 📋 Full Feature List (v2.0)

| Feature | Status |
|---|---|
| Notch overlay (screen-share invisible) | ✅ |
| Floating overlay mode | ✅ |
| Fullscreen overlay mode | ✅ |
| Resizable overlay height | ✅ |
| Word-level real-time highlighting | ✅ |
| Tap-to-jump | ✅ |
| 3 listening modes (Word Tracking / Classic / Voice-Activated) | ✅ |
| Multi-page scripts | ✅ |
| In-overlay page picker | ✅ |
| Auto next page with countdown | ✅ |
| Overlay transparency / blur | ✅ |
| Font family presets (Sans / Serif / Mono / Dyslexia) | ✅ |
| Font size presets (XS / SM / LG / XL) | ✅ |
| Cue color + brightness | ✅ |
| Last spoken words display | ✅ |
| Audio waveform + progress | ✅ |
| Elapsed time display | ✅ |
| Speech language selection (9 locales) | ✅ |
| Microphone selection | ✅ |
| PPTX import (PowerPoint presenter notes) | ✅ |
| File save / open (.notchprompt) | ✅ |
| Dictation mode in editor | ✅ |
| Read pages tracking | ✅ |
| Auto-update checker | ✅ |
| macOS Services integration | ✅ |
| URL scheme (notchprompt://read) | ✅ |
| Multi-display support | ✅ |
| Keynote import warning | ✅ |
| Scroll wheel support | ✅ |
| Hover-to-pause | ✅ |
| Countdown timer before scroll | ✅ |
| Global hotkeys | ✅ |
| Script templates | ✅ |
| CJK language support | ✅ |

---

## v1.0.0 — Initial Release

- Notch overlay with DynamicNotchKit integration
- Screen-share invisibility (`sharingType = .none`)
- 3 scroll modes: Manual, Auto (WPM), Voice
- Script editor with multiple scripts
- Cue markers: `[Smile]`, `[Pause]`, `[CTA]`
- Hover-to-pause
- Global hotkeys
- Font size and text color settings
- Countdown timer before auto-scroll
- Persistence via UserDefaults
