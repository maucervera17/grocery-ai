import Foundation

struct SelectableProduct: Identifiable {
    var product: ProductRequest
    var isSelected: Bool

    var id: UUID { product.id }

    var quantityStep: Double {
        switch product.unit {
        case .gram, .milliliter:
            100
        case .kilogram, .liter:
            0.5
        case .piece, .package, .dozen:
            1
        }
    }
}
