import Foundation

struct SelectableProduct: Identifiable {
    var product: ProductRequest
    var imageURL: URL?
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

    var maximumQuantity: Double {
        switch product.unit {
        case .gram, .milliliter:
            10_000
        default:
            100
        }
    }
}
