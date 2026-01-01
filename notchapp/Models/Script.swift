import Foundation

struct Script: Identifiable, Codable {
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
}
