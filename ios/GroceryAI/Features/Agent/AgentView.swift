import SwiftUI

struct AgentView: View {
    @Bindable var appState: AppState

    @State private var input = ""
    @State private var presentedSheet: AgentSheet?
    @State private var editingProduct: ProductRequest?
    @State private var selectedOffer: PriceOffer?
    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.medium) {
                        ForEach(appState.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }

                        if let comparison = appState.productComparison {
                            PriceDiscoveryView(comparison:comparison) { selectedOffer = $0 }
                        }
                        if !appState.savings.products.isEmpty {
                            SavingsBasketView(appState:appState)
                        }
                        if !appState.draft.isEmpty {
                            DraftCard(
                                draft: appState.draft,
                                onEdit: { editingProduct = $0 },
                                onDelete: appState.removeProducts
                            )
                            .id("draft")
                        }
                    }
                    .padding(AppSpacing.large)
                }
                .onChange(of: appState.messages.count) {
                    withAnimation { proxy.scrollTo("draft", anchor: .bottom) }
                }
            }

            if case .failed(let message) = appState.loadingState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AppSpacing.large)
                    .onTapGesture { appState.clearError() }
            }

            AgentComposer(
                text: $input,
                isFocused: $inputIsFocused,
                isLoading: appState.loadingState == .updatingDraft,
                onSend: send,
                onAddFrequent: { presentedSheet = .frequentProducts },
                onAddPreviousOrder: { presentedSheet = .previousOrders }
            )
        }
        .navigationTitle("Barasu")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(appState.postalCode.isEmpty ? "Ubicación" : "CP \(appState.postalCode)", systemImage:"location") { presentedSheet = .settings }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Comparar", systemImage: "cart.badge.questionmark") {
                    presentedSheet = .location
                }
                .disabled(appState.draft.isEmpty)
            }
        }
        .sheet(item: $selectedOffer) { offer in
            SelectionEditor(offer:offer) { packages, cents in
                appState.selectOffer(offer,packages:packages,usualCents:cents)
                selectedOffer = nil
            }
        }
        .sheet(item: $editingProduct) { product in
            ProductEditorView(product: product) { updated in
                appState.updateProduct(updated)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $presentedSheet) { sheet in
            sheetContent(sheet)
        }
        .fullScreenCover(isPresented: Binding(
            get: { appState.comparisonPlan != nil },
            set: { if !$0 { appState.comparisonPlan = nil } }
        )) {
            if let plan = appState.comparisonPlan {
                NavigationStack {
                    ComparisonResultView(plan: plan) {
                        appState.completeComparison()
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { appState.comparisonPlan = nil }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AgentSheet) -> some View {
        switch sheet {
        case .frequentProducts:
            ProductPickerView(products: appState.frequentProducts) { product in
                appState.addProduct(product)
            }
        case .previousOrders:
            PreviousOrderPickerView(orders: appState.orders) { order in
                appState.repeatOrder(order)
                presentedSheet = nil
            }
        case .settings:
            NavigationStack {
                VStack {
                    Toggle("Verificar disponibilidad en mi CP",isOn:$appState.localPrices).padding()
                    Text("Al desactivar se muestran precios publicados, sin confirmar existencias locales.").font(.footnote).padding(.horizontal)
                    LocationRequestView(initialPostalCode:appState.postalCode) { code in
                        appState.setLocation(code, verifyLocal:appState.localPrices)
                        presentedSheet = nil
                    }
                }
            }
        case .location:
            NavigationStack {
                if appState.loadingState == .comparing {
                    ComparisonLoadingView()
                } else {
                    LocationRequestView(initialPostalCode: appState.postalCode) { postalCode in
                        Task {
                            await appState.compare(postalCode: postalCode)
                            if appState.comparisonPlan != nil {
                                presentedSheet = nil
                            }
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    private func send() {
        let message = input
        input = ""
        inputIsFocused = false
        Task { await appState.send(message) }
    }
}

private enum AgentSheet: String, Identifiable {
    case frequentProducts
    case previousOrders
    case location
    case settings

    var id: String { rawValue }
}

private struct PriceDiscoveryView: View {
    let comparison: ProductPriceComparison
    let onSelect: (PriceOffer) -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(comparison.query).font(.title2.bold())
            Text(comparison.scope == "local" ? "Ubicación confirmada al consultar; sujeta a cambios." : "Precios publicados. Disponibilidad local sin confirmar.").font(.footnote)
            ForEach(comparison.offers) { offer in
                SurfaceCard {
                    VStack(alignment:.leading,spacing:10) {
                        HStack {
                            AsyncImage(url:URL(string:offer.listing.imageUrl ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName:"basket") }.frame(width:56,height:64)
                            VStack(alignment:.leading) {
                                Text(offer.listing.productName).font(.headline)
                                Text(offer.listing.retailer).font(.subheadline)
                                Text(MoneyFormatter.string(cents:offer.listing.priceCents,currencyCode:"MXN")).bold()
                            }
                        }
                        if let url = URL(string:offer.listing.productUrl) { Link("Ver producto",destination:url) }
                        Button("Añadir a mi cesta",systemImage:"plus.circle") { onSelect(offer) }.disabled(comparison.data_mode != "live")
                    }
                }
            }
        }
    }
}
private struct SelectionEditor: View {
    let offer: PriceOffer
    let onSave: (Int,Int?) -> Void
    @State private var packages = 1
    @State private var usualPrice = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Producto elegido") {
                    Text(offer.listing.productName)
                    Text(offer.listing.retailer)
                    Stepper("\(packages) presentaciones",value:$packages,in:1...99)
                }
                Section("Tu precio habitual por esta misma presentación") {
                    TextField("Importe en MXN (opcional)",text:$usualPrice).keyboardType(.decimalPad)
                    Text("Usa el precio que normalmente pagas por la misma cantidad y producto. No se deduce un precio habitual de las ofertas más caras.").font(.footnote)
                }
                Section("Resumen estimado") {
                    LabeledContent("Total",value:MoneyFormatter.string(cents:offer.listing.priceCents*packages,currencyCode:"MXN"))
                    if let cents = SavingsLedger.cents(usualPrice) {
                        LabeledContent("Diferencia vs habitual",value:MoneyFormatter.string(cents:(cents-offer.listing.priceCents)*packages,currencyCode:"MXN"))
                        Text("Una diferencia negativa significa que pagarías más.").font(.footnote)
                    } else { Text("Sin referencia: no calculamos ahorro.").font(.footnote) }
                    Button("Añadir selección") { onSave(packages,SavingsLedger.cents(usualPrice)) }.disabled(!usualPrice.isEmpty && SavingsLedger.cents(usualPrice)==nil)
                }
            }.navigationTitle("Tu selección")
        }
    }
}
private struct SavingsBasketView: View {
    @Bindable var appState: AppState
    @State private var checkout = false
    @State private var paid = ""
    var body: some View {
        SurfaceCard {
            VStack(alignment:.leading,spacing:12) {
                Text("Tu cesta Barasu").font(.title2.bold())
                ForEach(appState.savings.products) { item in
                    HStack {
                        Text("\(item.packages) × \(item.listing.productName)")
                        Spacer()
                        Button("Quitar",role:.destructive) { appState.removeSelection(item.id) }
                    }.font(.footnote)
                }
                Text("Total estimado: \(MoneyFormatter.string(cents:appState.savings.estimatedTotal,currencyCode:"MXN"))")
                if let delta = appState.savings.estimatedDifference {
                    Text("Diferencia vs habitual: \(MoneyFormatter.string(cents:delta,currencyCode:"MXN"))").bold()
                } else { Text("Completa tu precio habitual de cada producto para estimar el ahorro.").font(.footnote) }
                Button("Registrar compra realizada") { paid = ""; checkout = true }
            }
        }
        .sheet(isPresented:$checkout) {
            NavigationStack {
                Form {
                    Text("Confirma el total que pagaste por los productos de esta cesta. No incluyas otros artículos ni envío; la referencia tampoco los incluye.")
                    TextField("Total pagado en MXN",text:$paid).keyboardType(.decimalPad)
                    if let cents = SavingsLedger.cents(paid), let reference = appState.savings.referenceTotal {
                        LabeledContent("Diferencia registrada",value:MoneyFormatter.string(cents:reference-cents,currencyCode:"MXN"))
                    }
                    Button("Confirmar compra y guardar") {
                        if let cents = SavingsLedger.cents(paid) { appState.confirmPurchase(paidCents:cents); checkout = false }
                    }.disabled(SavingsLedger.cents(paid)==nil || appState.savings.products.isEmpty)
                }.navigationTitle("Compra realizada")
            }
        }
    }
}
