import Foundation

struct Script: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var pages: [String]          // multi-page support
    var createdAt: Date
    var updatedAt: Date

    // Legacy single-content init
    init(id: UUID = UUID(), title: String = "Untitled", content: String = "") {
        self.id = id
        self.title = title
        self.pages = [content]
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(id: UUID = UUID(), title: String = "Untitled", pages: [String]) {
        self.id = id
        self.title = title
        self.pages = pages.isEmpty ? [""] : pages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Backward-compat: treat first page as "content"
    var content: String {
        get { pages.first ?? "" }
        set {
            if pages.isEmpty { pages = [newValue] }
            else { pages[0] = newValue }
        }
    }

    mutating func updateContent(_ newContent: String) {
        if pages.isEmpty { pages = [newContent] }
        else { pages[0] = newContent }
        updatedAt = Date()
    }

    mutating func updatePage(_ index: Int, content: String) {
        guard index >= 0 && index < pages.count else { return }
        pages[index] = content
        updatedAt = Date()
    }

    var lines: [String] {
        content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    var wordCount: Int {
        pages.joined(separator: " ").split(separator: " ").count
    }

    func estimatedMinutes(at wpm: Double = 150) -> Int {
        max(1, Int(ceil(Double(wordCount) / wpm)))
    }
}

// MARK: - CJK-aware word splitting (ported from Textream)

extension Unicode.Scalar {
    var isCJK: Bool {
        let v = value
        return (v >= 0x4E00 && v <= 0x9FFF)
            || (v >= 0x3400 && v <= 0x4DBF)
            || (v >= 0x20000 && v <= 0x2A6DF)
            || (v >= 0xF900 && v <= 0xFAFF)
            || (v >= 0x3040 && v <= 0x309F)
            || (v >= 0x30A0 && v <= 0x30FF)
            || (v >= 0xAC00 && v <= 0xD7AF)
    }
}

func splitTextIntoWords(_ text: String) -> [String] {
    let tokens = text.replacingOccurrences(of: "\n", with: " ")
        .split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
        .map { String($0) }

    var result: [String] = []
    for token in tokens {
        guard token.unicodeScalars.contains(where: { $0.isCJK }) else {
            result.append(token)
            continue
        }
        var buffer = ""
        for char in token {
            if char.unicodeScalars.first.map({ $0.isCJK }) == true {
                if !buffer.isEmpty { result.append(buffer); buffer = "" }
                result.append(String(char))
            } else {
                buffer.append(char)
            }
        }
        if !buffer.isEmpty { result.append(buffer) }
    }
    return result
}

// MARK: - Script Templates

enum ScriptTemplate: String, CaseIterable, Identifiable {
    case blank = "Blank"
    case salesPitch = "Sales Pitch"
    case presentation = "Presentation"
    case interview = "Interview"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .blank: return "doc"
        case .salesPitch: return "chart.line.uptrend.xyaxis"
        case .presentation: return "person.wave.2"
        case .interview: return "mic"
        }
    }

    var script: Script {
        Script(title: rawValue, content: templateContent)
    }

    private var templateContent: String {
        switch self {
        case .blank:
            return ""
        case .salesPitch:
            return """
            [Opening]
            Hi, thanks for taking the time today.

            [Pain Point]
            I know that [problem] has been a challenge for your team.

            [Solution]
            That's exactly why we built [product]. It helps you [benefit] without [common objection].

            [Social Proof]
            Companies like [customer] have seen [metric] improvement since switching.

            [CTA]
            I'd love to set up a quick pilot. What does your calendar look like next week?

            [Pause]
            """
        case .presentation:
            return """
            [Opening]
            Good morning everyone. Today I want to talk about [topic].

            [Context]
            Over the past [timeframe], we've seen [trend or observation].

            [Key Point 1]
            First, let's look at [point]. The data shows [insight].

            [Key Point 2]
            Second, [point]. This matters because [reason].

            [Key Point 3]
            Finally, [point]. Here's what that means for us.

            [Summary]
            To wrap up: [recap the three points in one sentence each].

            [CTA]
            I'd love to hear your questions. Thank you.

            [Smile]
            """
        case .interview:
            return """
            [Intro]
            Welcome to the show. Today we have [guest name], who is [brief bio].

            [Q1]
            So tell us, how did you get started in [field]?

            [Pause]

            [Q2]
            What's been the biggest challenge you've faced?

            [Pause]

            [Q3]
            Where do you see [industry/topic] heading in the next few years?

            [Pause]

            [Q4]
            What advice would you give to someone just starting out?

            [Pause]

            [Closing]
            Thanks so much for joining us. Where can people find you online?

            [Smile]
            """
        }
    }
}

// MARK: - Cue Type

enum CueType {
    case pause
    case smile
    case cta
    case section(String)

    var label: String {
        switch self {
        case .pause: return "PAUSE"
        case .smile: return "SMILE"
        case .cta: return "CTA"
        case .section(let name): return name.uppercased()
        }
    }

    var color: String {
        switch self {
        case .pause: return "#FF9500"
        case .smile: return "#34C759"
        case .cta: return "#FF3B30"
        case .section: return "#5E5CE6"
        }
    }

    static func parse(_ line: String) -> CueType? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return nil }
        let inner = String(trimmed.dropFirst().dropLast()).lowercased()
        switch inner {
        case "pause": return .pause
        case "smile": return .smile
        case "cta": return .cta
        default: return .section(String(trimmed.dropFirst().dropLast()))
        }
    }
}
