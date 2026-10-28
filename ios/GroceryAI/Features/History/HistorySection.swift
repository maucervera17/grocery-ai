import Foundation

enum HistorySection: String, CaseIterable, Identifiable {
    case orders
    case products

    var id: Self { self }

    var title: String {
        switch self {
        case .orders:
            "Compras"
        case .products:
            "Productos"
        }
    }
}
