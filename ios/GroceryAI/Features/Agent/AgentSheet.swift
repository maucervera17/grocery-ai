import Foundation

enum AgentSheet: Identifiable, Hashable {
    case addContent
    case editProduct(ProductRequest)
    case location
    case settings

    var id: String {
        switch self {
        case .addContent:
            "add-content"
        case .editProduct(let product):
            "edit-product-\(product.id)"
        case .location:
            "location"
        case .settings:
            "settings"
        }
    }
}
