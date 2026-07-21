import Foundation

struct ChecklistItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}
struct ChecklistProject: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var items: [ChecklistItem]

    init(id: UUID = UUID(), title: String, items: [ChecklistItem] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}
