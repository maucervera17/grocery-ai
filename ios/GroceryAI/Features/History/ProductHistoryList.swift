import SwiftUI

struct ProductHistoryList: View {
    let products: [ProductRequest]
    let isSearching: Bool

    var body: some View {
        if products.isEmpty {
            if isSearching {
                ContentUnavailableView.search
            } else {
                ContentUnavailableView(
                    "Sin productos frecuentes",
                    systemImage: "basket",
                    description: Text("Los productos aparecerán después de completar comparaciones.")
                )
            }
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.medium) {
                    ForEach(products) { product in
                        ProductHistoryRow(product: product)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.medium)
            }
        }
    }
}
