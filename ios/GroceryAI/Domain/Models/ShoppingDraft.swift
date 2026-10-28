import Foundation

struct ShoppingDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var items: [ProductRequest]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        items: [ProductRequest] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool { items.isEmpty }

    mutating func replaceItems(with newItems: [ProductRequest], at date: Date = .now) {
        items = newItems
        updatedAt = date
    }
}
