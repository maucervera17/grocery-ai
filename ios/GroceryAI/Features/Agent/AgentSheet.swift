import Foundation

enum AgentSheet: Identifiable, Hashable {
    case addContent(AddContentSection)
    case editProduct(ProductRequest)
    case location
    case settings

    var id: String {
        switch self {
        case .addContent(let section):
            "add-content-\(section.rawValue)"
        case .editProduct(let product):
            "edit-product-\(product.id)"
        case .location:
            "location"
        case .settings:
            "settings"
        }
    }
}
