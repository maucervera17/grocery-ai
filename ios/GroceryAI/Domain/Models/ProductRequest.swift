import Foundation

struct ProductRequest: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: ProductUnit
    var notes: String?
    var categoryID: ProductCategory?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        unit: ProductUnit = .piece,
        notes: String? = nil,
        categoryID: ProductCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
        self.categoryID = categoryID
    }

    private enum CodingKeys: String, CodingKey {
        case id = "client_item_id"
        case name
        case quantity
        case unit
        case notes
        case categoryID = "category_id"
    }
}
