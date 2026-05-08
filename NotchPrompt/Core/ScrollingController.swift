import Foundation
import Combine
import AppKit

// MARK: - Scroll / Listening Mode

enum ScrollMode: String, CaseIterable {
    case manual = "Manual"
    case auto   = "Auto"
    case voice  = "Voice"
}

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
            if let d = descriptor.withDesign(.serif) { return NSFont(descriptor: d, size: size) ?? base }
            return base
        case .mono:
            if let d = descriptor.withDesign(.monospaced) { return NSFont(descriptor: d, size: size) ?? base }
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .dyslexia:
            if let f = NSFont(name: "OpenDyslexic3", size: size) { return f }
            if let d = descriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? base }
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

// MARK: - Cue Brightness

enum CueBrightness: String, CaseIterable, Identifiable {
    case dim, low, medium, bright

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var unreadOpacity: Double {
        switch self { case .dim: return 0.2; case .low: return 0.35; case .medium: return 0.5; case .bright: return 0.8 }
    }
    var readOpacity: Double {
        switch self { case .dim: return 0.5; case .low: return 0.6; case .medium: return 0.7; case .bright: return 1.0 }
    }
}

// MARK: - Overlay Display Mode

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

// MARK: - UserDefaults Keys

private enum UDKey {
    static let listeningMode    = "sc.listeningMode"
    static let scrollMode       = "sc.scrollMode"
    static let wordsPerMinute   = "sc.wordsPerMinute"
    static let useCountdown     = "sc.useCountdown"
    static let fontFamily       = "sc.fontFamily"
    static let fontSize         = "sc.fontSize"
    static let overlayMode      = "overlay.displayMode"
    static let cueColorHex      = "overlay.cueColorHex"
    static let cueBrightness    = "overlay.cueBrightness"
    static let speechLocale     = "speech.locale"
    static let micUID           = "speech.micUID"
}

// MARK: - ScrollingController

final class ScrollingController: ObservableObject {

    // MARK: Persisted settings — every didSet writes to UserDefaults

    @Published var listeningMode: ListeningMode = .wordTracking {
        didSet { UserDefaults.standard.set(listeningMode.rawValue, forKey: UDKey.listeningMode) }
    }
    @Published var mode: ScrollMode = .auto {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: UDKey.scrollMode) }
    }
    @Published var wordsPerMinute: Double = 150 {
        didSet { UserDefaults.standard.set(wordsPerMinute, forKey: UDKey.wordsPerMinute) }
    }
    @Published var useCountdown: Bool = true {
        didSet { UserDefaults.standard.set(useCountdown, forKey: UDKey.useCountdown) }
    }
    @Published var fontFamilyPreset: FontFamilyPreset = .sans {
        didSet { UserDefaults.standard.set(fontFamilyPreset.rawValue, forKey: UDKey.fontFamily) }
    }
    @Published var fontSizePreset: FontSizePreset = .lg {
        didSet { UserDefaults.standard.set(fontSizePreset.rawValue, forKey: UDKey.fontSize) }
    }
    @Published var overlayDisplayMode: OverlayDisplayMode = .notch {
        didSet { UserDefaults.standard.set(overlayDisplayMode.rawValue, forKey: UDKey.overlayMode) }
    }
    @Published var cueColorHex: String = "DAFFAA" {
        didSet { UserDefaults.standard.set(cueColorHex, forKey: UDKey.cueColorHex) }
    }
    @Published var cueBrightness: CueBrightness = .medium {
        didSet { UserDefaults.standard.set(cueBrightness.rawValue, forKey: UDKey.cueBrightness) }
    }
    @Published var speechLocale: String = "en-US" {
        didSet { UserDefaults.standard.set(speechLocale, forKey: UDKey.speechLocale) }
    }
    @Published var selectedMicUID: String = "" {
        didSet { UserDefaults.standard.set(selectedMicUID, forKey: UDKey.micUID) }
    }

    // MARK: Runtime state (not persisted)

    @Published var currentLineIndex: Int = 0
    @Published var scrollOffset: CGFloat = 0
    @Published var isScrolling: Bool = false
    @Published var isPausedByHover: Bool = false
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: Int = 3
    @Published var totalLines: Int = 0
    @Published var progress: Double = 0
    @Published var recognizedCharCount: Int = 0
    @Published var timerWordProgress: Double = 0
    @Published var currentPageIndex: Int = 0
    @Published var totalPages: Int = 1

    private var autoScrollTimer: Timer?
    private var countdownTimer: Timer?

    // MARK: Init — restore all persisted settings

    init() {
        let ud = UserDefaults.standard

        if let raw = ud.string(forKey: UDKey.listeningMode),
           let v = ListeningMode(rawValue: raw) { listeningMode = v }

        if let raw = ud.string(forKey: UDKey.scrollMode),
           let v = ScrollMode(rawValue: raw) { mode = v }

        let wpm = ud.double(forKey: UDKey.wordsPerMinute)
        if wpm > 0 { wordsPerMinute = wpm }

        if ud.object(forKey: UDKey.useCountdown) != nil {
            useCountdown = ud.bool(forKey: UDKey.useCountdown)
        }

        if let raw = ud.string(forKey: UDKey.fontFamily),
           let v = FontFamilyPreset(rawValue: raw) { fontFamilyPreset = v }

        if let raw = ud.string(forKey: UDKey.fontSize),
           let v = FontSizePreset(rawValue: raw) { fontSizePreset = v }

        if let raw = ud.string(forKey: UDKey.overlayMode),
           let v = OverlayDisplayMode(rawValue: raw) { overlayDisplayMode = v }

        if let raw = ud.string(forKey: UDKey.cueColorHex) { cueColorHex = raw }

        if let raw = ud.string(forKey: UDKey.cueBrightness),
           let v = CueBrightness(rawValue: raw) { cueBrightness = v }

        if let raw = ud.string(forKey: UDKey.speechLocale) { speechLocale = raw }

        if let raw = ud.string(forKey: UDKey.micUID) { selectedMicUID = raw }
    }

    // MARK: Computed

    var scrollSpeed: CGFloat { CGFloat(wordsPerMinute) / 60.0 * 20.0 }
    var wordsPerSecond: Double { wordsPerMinute / 60.0 }

    // MARK: Scroll control

    func startAutoScroll(skipCountdown: Bool = false) {
        guard mode == .auto || mode == .voice else { return }
        if !skipCountdown && useCountdown && !isCountingDown && !isScrolling {
            startCountdown(); return
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
        autoScrollTimer?.invalidate(); autoScrollTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        isCountingDown = false
    }

    func toggleAutoScroll() {
        if isScrolling || isCountingDown { stopAutoScroll() } else { startAutoScroll() }
    }

    func hoverPause() { guard isScrolling else { return }; isPausedByHover = true }
    func hoverResume() { isPausedByHover = false }

    func scrollUp(by amount: CGFloat = 30) {
        scrollOffset = max(0, scrollOffset - amount); updateLineIndex(); updateProgress()
    }
    func scrollDown(by amount: CGFloat = 30) {
        scrollOffset += amount; updateLineIndex(); updateProgress()
    }

    func reset() {
        stopAutoScroll()
        scrollOffset = 0; currentLineIndex = 0; progress = 0
        isPausedByHover = false; recognizedCharCount = 0; timerWordProgress = 0
    }

    func adjustSpeed(delta: Double) {
        wordsPerMinute = max(50, min(400, wordsPerMinute + delta))
    }

    func setTotalLines(_ count: Int) {
        totalLines = max(1, count); updateProgress()
    }

    private func updateLineIndex() {
        guard totalLines > 0 else { return }
        currentLineIndex = min(totalLines - 1, max(0, Int(scrollOffset / 30)))
    }

    private func updateProgress() {
        guard totalLines > 1 else { progress = 0; return }
        progress = Double(currentLineIndex) / Double(totalLines - 1)
    }
}
