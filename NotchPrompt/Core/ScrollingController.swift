import Foundation
import Combine

enum ScrollMode: String, CaseIterable {
    case manual = "Manual"
    case auto = "Auto"
    case voice = "Voice"
}

final class ScrollingController: ObservableObject {
    @Published var currentLineIndex: Int = 0
    @Published var scrollOffset: CGFloat = 0
    @Published var mode: ScrollMode = .auto
    @Published var wordsPerMinute: Double = 150
    @Published var isScrolling: Bool = false
    @Published var isPausedByHover: Bool = false
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: Int = 3
    @Published var totalLines: Int = 0
    @Published var progress: Double = 0

    private var autoScrollTimer: Timer?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    @Published var useCountdown: Bool = true

    var scrollSpeed: CGFloat {
        CGFloat(wordsPerMinute) / 60.0 * 20.0
    }

    var lineAdvanceInterval: TimeInterval {
        60.0 / wordsPerMinute * 8.0
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
