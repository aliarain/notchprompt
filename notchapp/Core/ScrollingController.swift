import Foundation
import Combine

enum ScrollMode: String, CaseIterable {
    case manual = "Manual"
    case auto = "Auto"
    case voice = "Voice"
}

final class ScrollingController: ObservableObject {
    @Published var scrollOffset: CGFloat = 0
    @Published var mode: ScrollMode = .manual
    @Published var wordsPerMinute: Double = 150
    @Published var isScrolling: Bool = false

    private var autoScrollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var scrollSpeed: CGFloat {
        CGFloat(wordsPerMinute) / 60.0 * 20.0
    }

    func startAutoScroll() {
        guard mode == .auto || mode == .voice else { return }
        isScrolling = true
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.scrollOffset += self.scrollSpeed / 60.0
        }
    }

    func stopAutoScroll() {
        isScrolling = false
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    func toggleAutoScroll() {
        if isScrolling {
            stopAutoScroll()
        } else {
            startAutoScroll()
        }
    }

    func scrollUp(by amount: CGFloat = 30) {
        scrollOffset = max(0, scrollOffset - amount)
    }

    func scrollDown(by amount: CGFloat = 30) {
        scrollOffset += amount
    }

    func reset() {
        stopAutoScroll()
        scrollOffset = 0
    }

    func setOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
    }

    func adjustSpeed(delta: Double) {
        wordsPerMinute = max(50, min(400, wordsPerMinute + delta))
    }
}
