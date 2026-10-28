import SwiftUI

struct HistoryView: View {
    let orders: [CompletedOrder]
    let frequentProducts: [FrequentProductOption]
    let onRepeatOrder: (CompletedOrder) -> Void

    @State private var selection: HistorySection = .orders
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Contenido del historial", selection: $selection) {
                ForEach(HistorySection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)

            switch selection {
            case .orders:
                OrderHistoryList(
                    orders: filteredOrders,
                    isSearching: !searchText.isEmpty,
                    onRepeatOrder: onRepeatOrder
                )
            case .products:
                ProductHistoryList(
                    products: filteredProducts,
                    isSearching: !searchText.isEmpty
                )
            }
        }
        .navigationTitle("Historial")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText, prompt: "Buscar en el historial")
    }

    private var filteredOrders: [CompletedOrder] {
        guard !searchText.isEmpty else { return orders }
        return orders.filter { order in
            order.requestedItems.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
                || order.completedAt.formatted(date: .abbreviated, time: .omitted)
                    .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredProducts: [FrequentProductOption] {
        guard !searchText.isEmpty else { return frequentProducts }
        return frequentProducts.filter {
            $0.product.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView(
            orders: MockFixtures.previousOrders,
            frequentProducts: [
                FrequentProductOption(product: MockFixtures.milk, imageURL: MockFixtures.milkLine.imageURL, frequency: 3),
                FrequentProductOption(product: MockFixtures.eggs, imageURL: MockFixtures.eggsLine.imageURL, frequency: 2),
                FrequentProductOption(product: MockFixtures.rice, imageURL: MockFixtures.riceLine.imageURL, frequency: 1)
            ],
            onRepeatOrder: { _ in }
        )
    }
}
