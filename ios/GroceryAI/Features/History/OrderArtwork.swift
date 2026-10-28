import SwiftUI

struct OrderArtwork: View {
    let order: CompletedOrder
    var size: CGFloat = 64

    var body: some View {
        Image(artwork)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var artwork: ImageResource {
        let names = order.requestedItems
            .map(\.name)
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if names.contains("pollo") || names.contains("papel") {
            return .orderBasket
        }
        if names.contains("cafe") || names.contains("pasta") || names.contains("tortilla") {
            return .orderTote
        }
        return .orderBag
    }
}
