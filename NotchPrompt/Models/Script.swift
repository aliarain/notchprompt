import Foundation

struct Script: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "Untitled", content: String = "") {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        updatedAt = Date()
    }

    var lines: [String] {
        content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    func estimatedMinutes(at wpm: Double = 150) -> Int {
        max(1, Int(ceil(Double(wordCount) / wpm)))
    }
}

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
