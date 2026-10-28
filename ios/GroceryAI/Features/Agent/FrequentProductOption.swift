import Foundation

struct FrequentProductOption: Identifiable, Hashable {
    let product: ProductRequest
    let imageURL: URL?
    let frequency: Int

    var id: UUID { product.id }
}
