import Foundation

struct ProductRequest: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: ProductUnit
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        unit: ProductUnit = .piece,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id = "client_item_id"
        case name
        case quantity
        case unit
        case notes
    }
}
