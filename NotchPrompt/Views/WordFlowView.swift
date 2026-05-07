import SwiftUI
import AppKit

// MARK: - Word Item

struct WordItem: Identifiable {
    let id: Int
    let word: String
    let charOffset: Int
    let isAnnotation: Bool
}

// MARK: - Preference Key for word Y positions

struct WordYPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Scroll Wheel Handler

struct ScrollWheelView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void
    var onScrollEnd: (() -> Void)?

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        view.onScrollEnd = onScrollEnd
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onScrollEnd = onScrollEnd
    }
}

class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    var onScrollEnd: (() -> Void)?
    private var scrollMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }
                let delta = event.scrollingDeltaY
                let scaled = event.hasPreciseScrollingDeltas ? delta : delta * 10
                self.onScroll?(scaled)
                if event.phase == .ended || event.momentumPhase == .ended {
                    self.onScrollEnd?()
                }
                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let monitor = scrollMonitor { NSEvent.removeMonitor(monitor); scrollMonitor = nil }
        super.removeFromSuperview()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Word Flow Layout

struct WordFlowLayout: View {
    let words: [String]
    let highlightedCharCount: Int
    let font: NSFont
    var highlightColor: Color = .white
    var cueColor: Color = Color(hex: "DAFFAA")
    var cueUnreadOpacity: Double = 0.25
    var cueReadOpacity: Double = 0.55
    var highlightWords: Bool = true
    let containerWidth: CGFloat
    var onWordTap: ((Int) -> Void)? = nil
    var scrollOffset: CGFloat = 0
    var viewportHeight: CGFloat = 0

    private var lineSpacing: CGFloat {
        let intrinsicHeight = font.ascender - font.descender + font.leading
        let ratio = intrinsicHeight / font.pointSize
        return ratio > 1.5 ? 2 : 8
    }

    // Layout cache
    private static var _cacheKey: String = ""
    private static var _cachedItems: [WordItem] = []
    private static var _cachedLines: [[WordItem]] = []

    private func cachedLayout() -> ([WordItem], [[WordItem]]) {
        let key = "\(words.count)|\(words.first ?? "")|\(words.last ?? "")|\(font.pointSize)|\(Int(containerWidth))"
        if key == Self._cacheKey {
            return (Self._cachedItems, Self._cachedLines)
        }
        let items = buildItems()
        let lines = buildLines(items: items)
        Self._cacheKey = key
        Self._cachedItems = items
        Self._cachedLines = lines
        return (items, lines)
    }

    private func nextWordIndex(items: [WordItem]) -> Int {
        for item in items {
            if item.isAnnotation { continue }
            let charsIntoWord = highlightedCharCount - item.charOffset
            let litCount = max(0, min(item.word.count, charsIntoWord))
            let letterCount = max(1, item.word.filter { $0.isLetter || $0.isNumber }.count)
            if litCount < letterCount { return item.id }
        }
        return -1
    }

    var body: some View {
        let (items, lines) = cachedLayout()
        let nextIdx = nextWordIndex(items: items)
        let totalLines = lines.count
        let lineH = ceil(font.ascender - font.descender + font.leading) + lineSpacing
        let canCull = viewportHeight > 0 && totalLines > 0
        let buffer: CGFloat = 400
        let startLine = canCull ? max(0, min(totalLines, Int(floor((-scrollOffset - buffer) / lineH)))) : 0
        let endLine = canCull ? max(startLine, min(totalLines, Int(ceil((viewportHeight - scrollOffset + buffer) / lineH)))) : totalLines

        VStack(alignment: .leading, spacing: lineSpacing) {
            if startLine > 0 {
                Color.clear.frame(height: CGFloat(startLine) * lineH)
            }
            ForEach(startLine..<endLine, id: \.self) { lineIdx in
                HStack(spacing: 0) {
                    ForEach(lines[lineIdx], id: \.id) { item in
                        wordView(for: item, isNextWord: item.id == nextIdx)
                            .id(item.id)
                    }
                }
            }
            if endLine < totalLines {
                Color.clear.frame(height: CGFloat(totalLines - endLine) * lineH)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: "flowLayout")
    }

    @ViewBuilder
    private func wordView(for item: WordItem, isNextWord: Bool) -> some View {
        let wordLen = item.word.count
        let charsIntoWord = highlightedCharCount - item.charOffset
        let litCount = max(0, min(wordLen, charsIntoWord))
        let letterCount = max(1, item.word.filter { $0.isLetter || $0.isNumber }.count)
        let isFullyLit = litCount >= letterCount
        let isCurrentWord = isNextWord || (charsIntoWord >= 0 && !isFullyLit)

        if !highlightWords {
            let uniformColor: Color = item.isAnnotation
                ? cueColor.opacity(cueUnreadOpacity)
                : highlightColor

            Text(item.word + " ")
                .font(item.isAnnotation ? Font(font).italic() : Font(font))
                .foregroundStyle(uniformColor)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: WordYPreferenceKey.self,
                            value: [item.id: geo.frame(in: .named("flowLayout")).midY]
                        )
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture { onWordTap?(item.charOffset) }
        } else if item.isAnnotation {
            let annotationColor: Color = isFullyLit
                ? cueColor.opacity(cueReadOpacity)
                : cueColor.opacity(cueUnreadOpacity)

            Text(item.word + " ")
                .font(Font(font).italic())
                .foregroundStyle(annotationColor)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: WordYPreferenceKey.self,
                            value: [item.id: geo.frame(in: .named("flowLayout")).midY]
                        )
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture { onWordTap?(item.charOffset) }
        } else {
            let dimColor: Color = isCurrentWord
                ? highlightColor.opacity(0.6)
                : highlightColor
            let wordColor: Color = isFullyLit ? highlightColor.opacity(0.3) : dimColor

            Text(item.word + " ")
                .font(Font(font))
                .foregroundStyle(wordColor)
                .underline(isCurrentWord, color: wordColor)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: WordYPreferenceKey.self,
                            value: [item.id: geo.frame(in: .named("flowLayout")).midY]
                        )
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture { onWordTap?(item.charOffset) }
        }
    }

    private func buildItems() -> [WordItem] {
        var items: [WordItem] = []
        var offset = 0
        for (i, word) in words.enumerated() {
            let isAnnotation = Self.isAnnotationWord(word)
            items.append(WordItem(id: i, word: word, charOffset: offset, isAnnotation: isAnnotation))
            offset += word.count + 1
        }
        return items
    }

    static func isAnnotationWord(_ word: String) -> Bool {
        if word.hasPrefix("[") && word.hasSuffix("]") { return true }
        return word.filter { $0.isLetter || $0.isNumber }.isEmpty
    }

    private func buildLines(items: [WordItem]) -> [[WordItem]] {
        var lines: [[WordItem]] = [[]]
        var currentLineWidth: CGFloat = 0
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width

        for item in items {
            let wordWidth = (item.word as NSString).size(withAttributes: [.font: font]).width + spaceWidth
            if currentLineWidth + wordWidth > containerWidth && !lines[lines.count - 1].isEmpty {
                lines.append([])
                currentLineWidth = 0
            }
            lines[lines.count - 1].append(item)
            currentLineWidth += wordWidth
        }
        return lines
    }
}

// MARK: - Speech Scroll View (main teleprompter display)

struct SpeechScrollView: View {
    let words: [String]
    let highlightedCharCount: Int
    var font: NSFont = .systemFont(ofSize: 18, weight: .semibold)
    var highlightColor: Color = .white
    var cueColor: Color = Color(hex: "DAFFAA")
    var cueUnreadOpacity: Double = 0.25
    var cueReadOpacity: Double = 0.55
    var onWordTap: ((Int) -> Void)? = nil
    var onManualScroll: ((Bool, Double) -> Void)? = nil
    var smoothScroll: Bool = false
    var smoothWordProgress: Double = 0
    var isListening: Bool = true

    @State private var scrollOffset: CGFloat = 0
    @State private var manualOffset: CGFloat = 0
    @State private var wordYPositions: [Int: CGFloat] = [:]
    @State private var containerHeight: CGFloat = 0
    @State private var isUserScrolling: Bool = false

    var body: some View {
        GeometryReader { geo in
            WordFlowLayout(
                words: words,
                highlightedCharCount: highlightedCharCount,
                font: font,
                highlightColor: highlightColor,
                cueColor: cueColor,
                cueUnreadOpacity: cueUnreadOpacity,
                cueReadOpacity: cueReadOpacity,
                highlightWords: !smoothScroll,
                containerWidth: geo.size.width,
                onWordTap: { charOffset in
                    manualOffset = 0
                    onWordTap?(charOffset)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        recalcCenter(containerHeight: containerHeight)
                    }
                },
                scrollOffset: scrollOffset + manualOffset,
                viewportHeight: geo.size.height
            )
            .onPreferenceChange(WordYPreferenceKey.self) { positions in
                let wasEmpty = wordYPositions.isEmpty
                wordYPositions = positions
                if wasEmpty && !positions.isEmpty {
                    recalcCenter(containerHeight: containerHeight)
                }
            }
            .offset(y: scrollOffset + manualOffset)
            .animation(smoothScroll ? .linear(duration: 0.06) : .easeOut(duration: 0.5), value: scrollOffset)
            .animation(.easeOut(duration: 0.15), value: manualOffset)
            .onChange(of: geo.size.height) { _, newHeight in
                containerHeight = newHeight
                if highlightedCharCount == 0 && smoothWordProgress == 0 {
                    let lineHeight = font.pointSize * 1.4
                    scrollOffset = newHeight * 0.5 - lineHeight * 0.5
                } else if isListening {
                    recalcCenter(containerHeight: newHeight)
                }
            }
            .onChange(of: highlightedCharCount) { _, _ in
                if isListening && !smoothScroll {
                    manualOffset = 0
                    recalcCenter(containerHeight: containerHeight)
                }
            }
            .onChange(of: smoothWordProgress) { _, _ in
                if isListening && smoothScroll {
                    manualOffset = 0
                    recalcCenter(containerHeight: containerHeight)
                }
            }
            .onChange(of: isListening) { _, listening in
                if listening { manualOffset = 0; recalcCenter(containerHeight: containerHeight) }
            }
            .onChange(of: words) { _, _ in
                let lineHeight = font.pointSize * 1.4
                scrollOffset = containerHeight * 0.5 - lineHeight * 0.5
                manualOffset = 0
                wordYPositions = [:]
            }
            .onAppear {
                containerHeight = geo.size.height
                let lineHeight = font.pointSize * 1.4
                scrollOffset = containerHeight * 0.5 - lineHeight * 0.5
            }
            .overlay(
                ScrollWheelView(
                    onScroll: { delta in
                        let canScroll = smoothScroll ? isListening : !isListening
                        guard canScroll else { return }
                        if smoothScroll && !isUserScrolling {
                            isUserScrolling = true
                            onManualScroll?(true, 0)
                        }
                        let maxY = wordYPositions.values.max() ?? 0
                        let maxUp = containerHeight * 0.5
                        let maxDown = max(0, maxY - containerHeight * 0.5)
                        let newOffset = manualOffset + delta
                        let upperBound = maxUp
                        let lowerBound = -maxDown
                        if newOffset > upperBound {
                            manualOffset = upperBound + (newOffset - upperBound) * 0.2
                        } else if newOffset < lowerBound {
                            manualOffset = lowerBound - (lowerBound - newOffset) * 0.2
                        } else {
                            manualOffset = newOffset
                        }
                    },
                    onScrollEnd: {
                        if smoothScroll && isUserScrolling {
                            let newProgress = wordProgressAtCurrentOffset()
                            withAnimation(.easeOut(duration: 0.15)) { manualOffset = 0 }
                            isUserScrolling = false
                            onManualScroll?(false, newProgress)
                        } else {
                            let maxY = wordYPositions.values.max() ?? 0
                            let upperBound = containerHeight * 0.5
                            let lowerBound = -max(0, maxY - containerHeight * 0.5)
                            if manualOffset > upperBound || manualOffset < lowerBound {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    manualOffset = min(upperBound, max(lowerBound, manualOffset))
                                }
                            }
                        }
                    }
                )
            )
        }
        .clipped()
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.05),
                    .init(color: .white, location: 0.95),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func recalcCenter(containerHeight: CGFloat) {
        let center = containerHeight * 0.5
        if smoothScroll {
            let bottomAnchor = containerHeight - 20
            let wordIdx = Int(smoothWordProgress)
            let fraction = smoothWordProgress - Double(wordIdx)
            let clampedIdx = max(0, min(wordIdx, words.count - 1))
            guard let wordY = wordYPositions[clampedIdx] else { return }
            let nextY = wordYPositions[clampedIdx + 1] ?? wordY
            let interpolatedY = wordY + (nextY - wordY) * CGFloat(fraction)
            scrollOffset = bottomAnchor - interpolatedY
        } else {
            let wordIdx = activeWordIndex()
            if let wordY = wordYPositions[wordIdx] {
                let target = center - wordY
                if abs(scrollOffset - target) > 1 { scrollOffset = target }
            }
        }
    }

    private func wordProgressAtCurrentOffset() -> Double {
        let center = containerHeight * 0.5
        let targetY = center - (scrollOffset + manualOffset)
        let sorted = wordYPositions.sorted { $0.key < $1.key }
        guard !sorted.isEmpty else { return smoothWordProgress }
        for i in 0..<sorted.count {
            let (wordIdx, wordY) = sorted[i]
            if i + 1 < sorted.count {
                let (_, nextY) = sorted[i + 1]
                if targetY >= wordY && targetY <= nextY {
                    let frac = (nextY - wordY) > 0 ? Double(targetY - wordY) / Double(nextY - wordY) : 0
                    return Double(wordIdx) + frac
                }
            } else if targetY >= wordY {
                return Double(wordIdx)
            }
        }
        if targetY < (sorted.first?.value ?? 0) { return 0 }
        return Double(words.count)
    }

    private func activeWordIndex() -> Int {
        var offset = 0
        for (i, word) in words.enumerated() {
            let end = offset + word.count
            if highlightedCharCount <= end { return i }
            offset = end + 1
        }
        return max(0, words.count - 1)
    }
}

// MARK: - Elapsed Time View

struct ElapsedTimeView: View {
    let fontSize: CGFloat
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            Text(String(format: "%02d:%02d", minutes, seconds))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Audio Waveform + Progress

struct AudioWaveformProgressView: View {
    let levels: [CGFloat]
    let progress: Double

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                let barProgress = Double(index) / Double(max(1, levels.count - 1))
                let isLit = barProgress <= progress
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isLit ? Color(hex: "DAFFAA").opacity(0.9) : Color.white.opacity(0.15))
                    .frame(width: 3, height: max(3, level * 28))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}

struct AudioWaveformView: View {
    let levels: [CGFloat]
    var color: Color = .white

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color.opacity(0.4 + Double(level) * 0.6))
                    .frame(width: 3, height: max(3, level * 28 + 3))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}
