import Foundation
import Combine
import AppKit

// MARK: - Scroll / Listening Mode

enum ScrollMode: String, CaseIterable {
    case manual = "Manual"
    case auto = "Auto"
    case voice = "Voice"
}

/// How the teleprompter tracks your speech
enum ListeningMode: String, CaseIterable, Identifiable {
    case wordTracking  = "Word Tracking"
    case classic       = "Classic"
    case silencePaused = "Voice-Activated"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .wordTracking:  return "Tracks each word you say and highlights it in real time."
        case .classic:       return "Auto-scrolls at a constant speed. No microphone needed."
        case .silencePaused: return "Scrolls while you speak, pauses when you're silent."
        }
    }

    var icon: String {
        switch self {
        case .wordTracking:  return "text.word.spacing"
        case .classic:       return "arrow.down.circle"
        case .silencePaused: return "waveform.circle"
        }
    }
}

// MARK: - Font Family Preset

enum FontFamilyPreset: String, CaseIterable, Identifiable {
    case sans     = "Sans"
    case serif    = "Serif"
    case mono     = "Mono"
    case dyslexia = "Dyslexia"

    var id: String { rawValue }

    func font(size: CGFloat, weight: NSFont.Weight = .semibold) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor
        switch self {
        case .sans:
            return base
        case .serif:
            if let designed = descriptor.withDesign(.serif) {
                return NSFont(descriptor: designed, size: size) ?? base
            }
            return base
        case .mono:
            if let designed = descriptor.withDesign(.monospaced) {
                return NSFont(descriptor: designed, size: size) ?? base
            }
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .dyslexia:
            if let dyslexicFont = NSFont(name: "OpenDyslexic3", size: size) {
                return dyslexicFont
            }
            if let designed = descriptor.withDesign(.rounded) {
                return NSFont(descriptor: designed, size: size) ?? base
            }
            return base
        }
    }
}

// MARK: - Font Size Preset

enum FontSizePreset: String, CaseIterable, Identifiable {
    case xs = "XS"
    case sm = "SM"
    case lg = "LG"
    case xl = "XL"

    var id: String { rawValue }

    var pointSize: CGFloat {
        switch self {
        case .xs: return 14
        case .sm: return 16
        case .lg: return 20
        case .xl: return 24
        }
    }
}

// MARK: - Overlay Mode

enum OverlayDisplayMode: String, CaseIterable, Identifiable {
    case notch      = "Notch"
    case floating   = "Floating"
    case fullscreen = "Fullscreen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notch:      return "rectangle.topthird.inset.filled"
        case .floating:   return "macwindow.on.rectangle"
        case .fullscreen: return "rectangle.fill"
        }
    }

    var description: String {
        switch self {
        case .notch:      return "Anchored below the notch at the top of your screen."
        case .floating:   return "A draggable window you can place anywhere."
        case .fullscreen: return "Fullscreen teleprompter on the selected display."
        }
    }
}

// MARK: - Scrolling Controller

final class ScrollingController: ObservableObject {
    // Scroll state
    @Published var currentLineIndex: Int = 0
    @Published var scrollOffset: CGFloat = 0
    @Published var isScrolling: Bool = false
    @Published var isPausedByHover: Bool = false
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: Int = 3
    @Published var totalLines: Int = 0
    @Published var progress: Double = 0

    // Settings
    @Published var mode: ScrollMode = .auto
    @Published var listeningMode: ListeningMode = .wordTracking
    @Published var wordsPerMinute: Double = 150
    @Published var useCountdown: Bool = true

    // Font settings
    @Published var fontFamilyPreset: FontFamilyPreset = .sans
    @Published var fontSizePreset: FontSizePreset = .lg

    // Overlay mode
    @Published var overlayDisplayMode: OverlayDisplayMode = .notch

    // Word tracking (for word-level highlight mode)
    @Published var recognizedCharCount: Int = 0

    // Timer-based scroll progress (for classic / silence-paused)
    @Published var timerWordProgress: Double = 0

    // Multi-page
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 1

    private var autoScrollTimer: Timer?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var scrollSpeed: CGFloat {
        CGFloat(wordsPerMinute) / 60.0 * 20.0
    }

    var lineAdvanceInterval: TimeInterval {
        60.0 / wordsPerMinute * 8.0
    }

    // Words per second for timer-based modes
    var wordsPerSecond: Double {
        wordsPerMinute / 60.0
    }

    func startAutoScroll(skipCountdown: Bool = false) {
        guard mode == .auto || mode == .voice else { return }

        if !skipCountdown && useCountdown && !isCountingDown && !isScrolling {
            startCountdown()
            return
        }

        isScrolling = true
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, !self.isPausedByHover else { return }
            DispatchQueue.main.async {
                self.scrollOffset += self.scrollSpeed / 60.0
                self.updateProgress()
            }
        }
    }

    private func startCountdown() {
        isCountingDown = true
        countdownValue = 3

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.countdownValue -= 1
                if self.countdownValue <= 0 {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.isCountingDown = false
                    self.startAutoScroll(skipCountdown: true)
                }
            }
        }
    }

    func stopAutoScroll() {
        isScrolling = false
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
    }

    func toggleAutoScroll() {
        if isScrolling || isCountingDown {
            stopAutoScroll()
        } else {
            startAutoScroll()
        }
    }

    func hoverPause() {
        guard isScrolling else { return }
        isPausedByHover = true
    }

    func hoverResume() {
        isPausedByHover = false
    }

    func scrollUp(by amount: CGFloat = 30) {
        scrollOffset = max(0, scrollOffset - amount)
        updateLineIndex()
        updateProgress()
    }

    func scrollDown(by amount: CGFloat = 30) {
        scrollOffset += amount
        updateLineIndex()
        updateProgress()
    }

    func advanceLine() {
        guard totalLines > 0 else { return }
        currentLineIndex = min(totalLines - 1, currentLineIndex + 1)
        updateProgress()
    }

    func previousLine() {
        currentLineIndex = max(0, currentLineIndex - 1)
        updateProgress()
    }

    func reset() {
        stopAutoScroll()
        scrollOffset = 0
        currentLineIndex = 0
        progress = 0
        isPausedByHover = false
        recognizedCharCount = 0
        timerWordProgress = 0
    }

    func setOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
        updateLineIndex()
        updateProgress()
    }

    func adjustSpeed(delta: Double) {
        wordsPerMinute = max(50, min(400, wordsPerMinute + delta))
    }

    func setTotalLines(_ count: Int) {
        totalLines = max(1, count)
        updateProgress()
    }

    private func updateLineIndex() {
        guard totalLines > 0 else { return }
        let lineHeight: CGFloat = 30
        currentLineIndex = min(totalLines - 1, max(0, Int(scrollOffset / lineHeight)))
    }

    private func updateProgress() {
        guard totalLines > 1 else {
            progress = 0
            return
        }
        progress = Double(currentLineIndex) / Double(totalLines - 1)
    }
}
