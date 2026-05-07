# NotchPrompt v2.0 — Product Hunt Update

## Tagline
The teleprompter that lives in your Mac's notch — now with real-time word tracking, floating mode, and 30+ new features.

---

## Short Description (for comment / update post)

Hey Product Hunt 👋

We shipped NotchPrompt v1.0 a few weeks ago — a teleprompter that hides in your Mac's camera notch and stays invisible during screen shares.

Since then we've been heads-down building v2.0, and it's a completely different app now. Here's what's new:

**The big one: Word-level real-time highlighting.**
As you speak, each word lights up and dims as you pass it. Powered by a fuzzy matching algorithm that handles accents, speech recognition errors, and fast speech. Tap any word to jump to it.

**3 overlay modes:**
- Notch (original) — anchored below the camera notch
- Floating — a draggable window you can put anywhere
- Fullscreen — takes over a whole display for dedicated teleprompter setups

**3 listening modes:**
- Word Tracking — highlights each word as you say it
- Voice-Activated — scrolls while you speak, pauses when you stop
- Classic — constant WPM, no microphone needed

**Multi-page scripts** — split long scripts into pages, import PowerPoint presenter notes as pages, auto-advance with a countdown.

**30+ other things:** font families (including OpenDyslexic), speech language selection, microphone picker, blur background, resizable overlay, in-overlay page picker, dictation mode in the editor, macOS Services integration, URL scheme, auto-update checker, read pages tracking, and more.

Everything runs 100% on-device. No cloud, no account, no subscription.

---

## Full Feature List for Product Hunt

### Core
- Notch overlay — expands from the Mac notch with a Dynamic Island animation
- Screen-share invisible — `sharingType = .none` means it never appears in Zoom, Teams, Meet, or OBS recordings
- Word-level real-time highlighting — each word lights up as you say it
- Tap-to-jump — tap any word to jump the reading position there
- Fuzzy speech matching — handles accents, STT errors, and fast speech

### Overlay Modes
- **Notch** — anchored below the camera notch
- **Floating** — draggable, always-on-top window
- **Fullscreen** — takes over an entire display

### Listening Modes
- **Word Tracking** — per-word highlight in real time
- **Voice-Activated** — scrolls while speaking, pauses on silence
- **Classic** — constant WPM, no mic needed

### Script Management
- Multi-page scripts with sidebar navigation
- PPTX import — drag a PowerPoint file to import presenter notes as pages
- File save/open (.notchprompt format)
- Script templates (Sales Pitch, Presentation, Interview, Blank)
- Dictation mode — dictate text into the editor with your voice
- Word count, char count, estimated read time per page

### Overlay Controls
- Resizable height — drag the handle to expand the overlay
- In-overlay page picker — tap the page indicator to jump to any page
- Auto next page with countdown (1–10s, configurable)
- Hover-to-pause
- Scroll wheel support
- Last spoken words display
- Audio waveform + progress bar
- Elapsed time timer (MM:SS)

### Appearance
- Font families: Sans, Serif, Mono, Dyslexia (OpenDyslexic)
- Font sizes: XS / SM / LG / XL
- Text colors: White, Yellow, Cyan, Green, Lavender
- Cue color + brightness for [bracket] annotations
- Blur background with adjustable opacity
- Background opacity control

### System Integration
- macOS Services — right-click any text → "Read in NotchPrompt"
- URL scheme — `notchprompt://read?text=...`
- Multi-display support — follows mouse to any screen
- Auto-update checker (silent on launch)
- Read pages tracking (green badge on completed pages)

### Speech Settings
- 9 languages: English (US/UK), Spanish, French, German, Italian, Portuguese, Japanese, Chinese
- Microphone selection — pick any CoreAudio input device
- Keynote import warning with exact export instructions

### Shortcuts
- `⌃ + \`` — toggle overlay
- `⌃ + Space` — start/stop scroll
- `⇧⌘O/S/R` — global hotkeys (overlay, scroll, reset)
- `⇧⌘]/[` — next/previous script

---

## What's Next (v2.1 roadmap)

- Browser remote viewer — watch the teleprompter on your phone via local WiFi
- Director mode — remote operator sends script to the presenter via QR code
- External display / mirror mode — fullscreen on a second monitor with optional horizontal flip for mirror rigs
- AI script polish — on-device suggestions to improve pacing and readability

---

## Links
- GitHub: https://github.com/aliarain/notchprompt
- Website: https://raptrx.com
- Built by: Ali Arain (https://aliarain.com) & RaptrX (https://raptrx.com)
