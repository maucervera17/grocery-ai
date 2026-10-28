import SwiftUI

struct HistoryView: View {
    let orders: [CompletedOrder]
    let frequentProducts: [ProductRequest]
    let onRepeatOrder: (CompletedOrder) -> Void

    @State private var selection: HistorySection = .orders

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
                ordersContent
            case .products:
                productsContent
            }
        }
        .navigationTitle("Historial")
    }

    @ViewBuilder
    private var ordersContent: some View {
        if orders.isEmpty {
            ContentUnavailableView(
                "Sin compras anteriores",
                systemImage: "clock.arrow.circlepath",
                description: Text("Las comparaciones completadas aparecerán aquí.")
            )
        } else {
            List(orders) { order in
                NavigationLink {
                    OrderDetailView(order: order, onRepeat: onRepeatOrder)
                } label: {
                    OrderHistoryRow(order: order)
                }
                .accessibilityHint("Abre el detalle de la compra")
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var productsContent: some View {
        if frequentProducts.isEmpty {
            ContentUnavailableView(
                "Sin productos frecuentes",
                systemImage: "basket",
                description: Text("Los productos aparecerán después de completar comparaciones.")
            )
        } else {
            List(frequentProducts) { product in
                ProductHistoryRow(product: product)
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView(
            orders: MockFixtures.previousOrders,
            frequentProducts: [MockFixtures.milk, MockFixtures.eggs, MockFixtures.rice],
            onRepeatOrder: { _ in }
        )
    }
}
