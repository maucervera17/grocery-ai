import SwiftUI
import Combine
import ElevenLabs

struct AgentView: View {
    @Bindable var appState: AppState

    @State private var input = ""
    @State private var showVoice = false
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
                            PriceDiscoveryView(comparison:comparison) { appState.saveDiscovery($0,comparison:comparison); appState.selectedTab = .savings }
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
        .sheet(isPresented:$showVoice) { BarasuVoiceView(appState:appState) }
        .navigationTitle("Barasu")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(appState.postalCode.isEmpty ? "Ubicación" : "CP \(appState.postalCode)", systemImage:"location") { presentedSheet = .settings }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Voz",systemImage:"waveform") { showVoice = true }
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
                        if let url = URL(string:offer.listing.productUrl) { Link("Ver en la tienda",destination:url) }
                        Button("Guardar en Barasu",systemImage:"heart") { onSelect(offer) }.disabled(comparison.data_mode != "live")
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

@MainActor
private final class BarasuVoiceModel: ObservableObject {
    @Published var conversation: Conversation?
    @Published var status = "Listo para conversar"
    @Published var connecting = false
    private var connectionTask: Task<Void,Never>?
    private var toolsTask: Task<Void,Never>?
    private var generation = UUID()
    func start(appState: AppState) {
        guard !connecting, conversation == nil else { return }
        connecting = true; status = "Conectando…"
        let id = UUID(); generation = id
        connectionTask = Task {
            do {
                var request = URLRequest(url:APIConfiguration.baseURL.appendingPathComponent("v1/voice/session"))
                request.httpMethod = "POST"; request.timeoutInterval = 15
                let (data,response) = try await URLSession.shared.data(for:request)
                struct Session: Decodable { var conversation_token: String }
                struct Failure: Decodable { var message: String }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw GroceryAPIError(message:(try? JSONDecoder().decode(Failure.self,from:data).message) ?? "No se pudo iniciar la voz.")
                }
                let token = try JSONDecoder().decode(Session.self,from:data).conversation_token
                try Task.checkCancellation()
                let connected = try await ElevenLabs.startConversation(conversationToken:token)
                guard !Task.isCancelled, generation == id else { await connected.endConversation(); return }
                conversation = connected; connecting = false; status = "Conversación activa"
                toolsTask = Task { [weak self] in
                    var handled = Set<String>()
                    for await calls in connected.$pendingToolCalls.values {
                        guard !Task.isCancelled, self?.generation == id else { return }
                        for call in calls where !handled.contains(call.toolCallId) {
                            handled.insert(call.toolCallId)
                            let parameters = try? call.getParameters()
                            let result: String
                            if call.toolName == "barasu_search", let message = parameters?["message"] as? String, let action = parameters?["action"] as? String {
                                result = await appState.voiceSearch(action:action,message:message)
                            } else if call.toolName == "barasu_save", let url = parameters?["product_url"] as? String,
                                      let comparison = appState.productComparison, comparison.data_mode == "live",
                                      let offer = comparison.offers.first(where: { $0.id == url }) {
                                appState.saveDiscovery(offer,comparison:comparison)
                                result = "Guardado en Barasu: " + offer.listing.productName
                            } else { result = "Herramienta o producto no disponible. No se realizaron cambios." }
                            guard !Task.isCancelled, self?.generation == id else { return }
                            try? await connected.sendToolResult(for:call.toolCallId,result:result)
                        }
                    }
                }
            } catch {
                guard generation == id else { return }
                connecting = false; status = error is CancellationError ? "Voz finalizada" : error.localizedDescription
            }
        }
    }
    func end() async {
        generation = UUID(); connectionTask?.cancel(); toolsTask?.cancel()
        let current = conversation; conversation = nil; connecting = false; status = "Voz finalizada"
        await current?.endConversation()
    }
}

private struct BarasuVoiceView: View {
    let appState: AppState
    @StateObject private var voice = BarasuVoiceModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing:20) {
                Image(systemName:"waveform.circle.fill").font(.system(size:64)).foregroundStyle(.green)
                Text("Habla con Barasu").font(.title2.bold())
                Text("Al iniciar, ElevenLabs procesa tu audio y transcripción. Puedes interrumpir al agente. Guardar productos no realiza compras.").font(.footnote)
                Text(voice.status).accessibilityAddTraits(.updatesFrequently)
                if let conversation = voice.conversation {
                    NativeVoiceConversation(conversation:conversation)
                    Button("Terminar y ver resultados") { Task { await voice.end(); dismiss() } }
                } else {
                    Button("Iniciar conversación") { voice.start(appState:appState) }.disabled(voice.connecting)
                }
                if voice.connecting { Button("Cancelar conexión") { Task { await voice.end() } } }
            }.padding().navigationTitle("Modo de voz")
                .toolbar { Button("Cerrar") { Task { await voice.end(); dismiss() } } }
        }
        .onDisappear { Task { await voice.end() } }
        .onChange(of:scenePhase) { _,phase in if phase != .active { Task { await voice.end() } } }
    }
}
private struct NativeVoiceConversation: View {
    @ObservedObject var conversation: Conversation
    var body: some View {
        VStack {
            Text(String(describing:conversation.agentState))
            ScrollView {
                ForEach(conversation.messages) { message in
                    Text(message.content).frame(maxWidth:.infinity,alignment:.leading).padding(8)
                }
            }
            Button(conversation.isMuted ? "Activar micrófono" : "Silenciar") { Task { try? await conversation.toggleMute() } }
        }
    }
}
