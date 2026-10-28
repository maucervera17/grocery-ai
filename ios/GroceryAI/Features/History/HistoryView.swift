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

struct SavingsStatisticsView: View {
    let ledger: SavingsLedger
    var onDelete: (UUID) -> Void = { _ in }
    var body: some View {
        List {
            Section("Tu ahorro con Barasu") {
                LabeledContent("Compras registradas",value:"\(ledger.purchases.count)")
                LabeledContent("Compras con referencia",value:"\(ledger.referencedPurchases)")
                LabeledContent("Diferencia acumulada",value:MoneyFormatter.string(cents:ledger.recordedDifference,currencyCode:"MXN"))
                Text("Total pagado declarado frente a tu precio habitual declarado. No prueba cuánto habrías gastado sin la app; no incluye comparaciones sin compra. Los valores negativos son gasto adicional. Se guarda en este dispositivo.").font(.footnote)
            }
            Section("Compras confirmadas") {
                ForEach(ledger.purchases) { purchase in
                    VStack(alignment:.leading,spacing:8) {
                        Text(purchase.date,style:.date).font(.headline)
                        Text("\(purchase.products.count) productos · pagaste \(MoneyFormatter.string(cents:purchase.paidCents,currencyCode:"MXN"))")
                        if let delta = purchase.differenceCents {
                            Text("Diferencia: \(MoneyFormatter.string(cents:delta,currencyCode:"MXN"))")
                        } else { Text("Sin precio habitual completo: excluida de ahorro.") }
                    }.swipeActions { Button("Eliminar",role:.destructive) { onDelete(purchase.id) } }
                }
            }
        }.navigationTitle("Mi ahorro")
    }
}

struct SavedProductsView: View {
    @Bindable var appState: AppState
    @State private var status = ""
    var body: some View {
        List {
            Section {
                Text("Guarda ofertas para volver a la tienda y seguir su precio. El precio observado no garantiza que siga siendo el menor ni que haya existencias.").font(.footnote)
                if !status.isEmpty { Text(status).font(.footnote) }
            }
            ForEach(appState.savings.savedProducts ?? []) { product in
                VStack(alignment:.leading,spacing:10) {
                    HStack {
                        AsyncImage(url:URL(string:product.listing.imageUrl ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName:"basket") }.frame(width:48,height:56)
                        VStack(alignment:.leading) {
                            Text(product.listing.productName).font(.headline)
                            Text(product.listing.retailer)
                            Text(MoneyFormatter.string(cents:product.listing.priceCents,currencyCode:"MXN")).bold()
                        }
                    }
                    Text("Consultado: \(product.listing.checkedAt)").font(.caption)
                    Text(product.observations.last?.scope == "local" ? "Zona confirmada al consultar" : "Precio publicado · disponibilidad local sin confirmar").font(.caption)
                    if let change = product.changeCents { Text("Cambio de precio: \(MoneyFormatter.string(cents:change,currencyCode:"MXN"))").font(.footnote) }
                    if let url = URL(string:product.id) { Link("Ver en la tienda",destination:url) }
                    Button("Actualizar precio") { Task { status = "Consultando…"; status = await appState.refreshSaved(product) } }.disabled(appState.loadingState != .idle)
                }.swipeActions { Button("Quitar",role:.destructive) { appState.removeSaved(product.id) } }
            }
            Section {
                NavigationLink("Registros de ahorro anteriores") { SavingsStatisticsView(ledger:appState.savings,onDelete:appState.deletePurchase) }
            }
        }.navigationTitle("Mis guardados")
    }
}
