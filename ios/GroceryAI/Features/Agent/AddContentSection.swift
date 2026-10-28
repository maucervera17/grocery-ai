import Foundation

enum AddContentSection: String, CaseIterable, Identifiable {
    case products
    case orders

    var id: Self { self }

    var title: String {
        switch self {
        case .products:
            "Productos"
        case .orders:
            "Compras"
        }
    }
}
