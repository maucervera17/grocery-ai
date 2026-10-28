import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .agent
    var draft = ShoppingDraft()
    var messages = MockFixtures.welcomeMessages
    var orders: [CompletedOrder] = []
    var postalCode = ""
    var localPrices = false
    var productComparison: ProductPriceComparison?
    var savings = SavingsLedger()
    var loadingState: ChatLoadingState = .idle
    var comparisonPlan: ComparisonPlan?

    private let agentService: any AgentServicing
    private let comparisonService: any ComparisonServicing
    private let productPriceService: any ProductPriceServicing
    private var modelContext: ModelContext?
    private var record: LocalAppStateRecord?

    init(
        agentService: any AgentServicing = GroceryAPIClient(),
        comparisonService: any ComparisonServicing = GroceryAPIClient(),
        productPriceService: any ProductPriceServicing = GroceryAPIClient()
    ) {
        self.agentService = agentService
        self.comparisonService = comparisonService
        self.productPriceService = productPriceService
    }

    var frequentProducts: [ProductRequest] {
        var productsByName: [String: (product: ProductRequest, count: Int)] = [:]
        for product in orders.flatMap(\.requestedItems) {
            let key = product.name.folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "es_MX")
            )
            let previous = productsByName[key]
            productsByName[key] = (product, (previous?.count ?? 0) + 1)
        }
        return productsByName.values
            .sorted { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.product.name < rhs.product.name
                    : lhs.count > rhs.count
            }
            .map(\.product)
    }

    func configurePersistence(_ context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context

        let descriptor = FetchDescriptor<LocalAppStateRecord>()
        if let stored = try? context.fetch(descriptor).first {
            record = stored
            restore(from: stored)
        } else {
            let newRecord = LocalAppStateRecord()
            context.insert(newRecord)
            record = newRecord
            persist()
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, loadingState == .idle else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        loadingState = .updatingDraft
        productComparison = nil
        do {
            if trimmed.range(of:"precio|barat[oa]|cu[aá]nto cuesta|compar[aá]",options:[.regularExpression,.caseInsensitive]) != nil {
                let (reply, result) = try await productPriceService.productPrices(message:trimmed,items:draft.items,postalCode:postalCode,local:localPrices)
                productComparison = result
                messages.append(ChatMessage(role:.agent,text:reply,kind:.comparison))
                loadingState = .idle
                persist()
                return
            }
            let response = try await agentService.updateDraft(
                message: trimmed,
                currentItems: draft.items
            )
            comparisonPlan = nil
            draft.replaceItems(with: response.draftItems)
            messages.append(ChatMessage(role: .agent, text: response.reply, kind: .draftUpdate))
            loadingState = .idle
            persist()
        } catch {
            let message = error.localizedDescription
            messages.append(ChatMessage(role: .agent, text: message, kind: .error))
            loadingState = .failed(message: message)
        }
    }

    func setLocation(_ code: String, verifyLocal: Bool = true) {
        guard code.range(of:"^[0-9]{5}$",options:.regularExpression) != nil else { return }
        if postalCode != code {
            postalCode = code
            comparisonPlan = nil
            productComparison = nil
            // Confirmed purchases remain history; provisional local selections are invalidated.
            savings.products = []
            savings.basketID = UUID()
        }
        localPrices = verifyLocal
        persist()
    }
    func saveDiscovery(_ offer: PriceOffer, comparison: ProductPriceComparison) {
        guard comparison.data_mode == "live" else { return }
        var saved = savings.savedProducts ?? []
        var entry = saved.first { $0.id == offer.id } ?? SavedDiscovery(listing:offer.listing,query:comparison.query,observations:[])
        let observed = SavedPriceObservation(priceCents:offer.listing.priceCents,checkedAt:offer.listing.checkedAt,scope:comparison.scope,postalCode:comparison.requested_postal_code)
        if !entry.observations.contains(where: { $0.checkedAt == observed.checkedAt && $0.scope == observed.scope && $0.postalCode == observed.postalCode }) { entry.observations.append(observed) }
        entry.observations = Array(entry.observations.suffix(60))
        entry.listing = offer.listing
        saved.removeAll { $0.id == entry.id }; saved.insert(entry,at:0)
        savings.savedProducts = saved; persist()
    }
    func removeSaved(_ id: String) { savings.savedProducts?.removeAll { $0.id == id }; persist() }
    func refreshSaved(_ product: SavedDiscovery) async -> String {
        guard loadingState == .idle else { return "Espera la consulta en curso." }
        loadingState = .updatingDraft
        defer { loadingState = .idle }
        do {
            let (_, result) = try await productPriceService.productPrices(message:product.query,items:[],postalCode:product.observations.last?.postalCode ?? "",local:product.observations.last?.scope == "local")
            guard let result, let offer = result.offers.first(where: { $0.id == product.id }) else { return "No se pudo actualizar. Conservamos el precio y fecha anteriores." }
            saveDiscovery(offer,comparison:result)
            return "Precio actualizado desde la fuente."
        } catch { return "No se pudo actualizar. Conservamos el precio y fecha anteriores." }
    }
    func voiceSearch(action: String, message: String) async -> String {
        guard loadingState == .idle, !message.isEmpty, message.count <= 2000 else { return "Espera la consulta actual o revisa el mensaje." }
        loadingState = .updatingDraft
        defer { loadingState = .idle }
        do {
            if action == "product_prices" {
                let (reply,result) = try await productPriceService.productPrices(message:message,items:draft.items,postalCode:postalCode,local:localPrices)
                productComparison = result
                struct VoiceResult: Encodable { let reply: String; let comparison: ProductPriceComparison? }
                return String(decoding:try JSONEncoder().encode(VoiceResult(reply:reply,comparison:result)),as:UTF8.self)
            } else if action == "update_draft" {
                let result = try await agentService.updateDraft(message:message,currentItems:draft.items)
                draft.replaceItems(with:result.draftItems);persist()
                return result.reply
            }
            return "Acción no admitida. No se realizaron cambios."
        } catch { return "La consulta falló. No hay nuevos precios confirmados." }
    }
    func selectOffer(_ offer: PriceOffer, packages: Int, usualCents: Int?) {
        guard productComparison?.data_mode == "live", (1...99).contains(packages), (0...100_000_000).contains(offer.listing.priceCents),
              usualCents == nil || (0...100_000_000).contains(usualCents!) else { return }
        let item = SelectedProduct(listing:offer.listing,packages:packages,usualPriceCents:usualCents)
        if let index = savings.products.firstIndex(where: { $0.listing.productUrl == offer.id }) { savings.products[index] = item }
        else { savings.products.append(item) }
        persist()
    }
    func removeSelection(_ id: UUID) { savings.products.removeAll { $0.id == id }; persist() }
    func deletePurchase(_ id: UUID) { savings.purchases.removeAll { $0.id == id }; persist() }
    func confirmPurchase(paidCents: Int) { savings.confirm(paidCents:paidCents); persist() }

    func updateProduct(_ product: ProductRequest) {
        guard let index = draft.items.firstIndex(where: { $0.id == product.id }) else { return }
        draft.items[index] = product
        comparisonPlan = nil
        draft.updatedAt = .now
        persist()
    }

    func removeProducts(at offsets: IndexSet) {
        draft.items.remove(atOffsets: offsets)
        comparisonPlan = nil
        draft.updatedAt = .now
        persist()
    }

    func addProduct(_ product: ProductRequest) {
        if let index = draft.items.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(product.name) == .orderedSame && $0.unit == product.unit
        }) {
            draft.items[index].quantity += product.quantity
        } else {
            draft.items.append(ProductRequest(
                name: product.name,
                quantity: product.quantity,
                unit: product.unit,
                notes: product.notes
            ))
        }
        comparisonPlan = nil
        draft.updatedAt = .now
        persist()
    }

    func repeatOrder(_ order: CompletedOrder) {
        comparisonPlan = nil
        draft.replaceItems(with: order.requestedItems.map {
            ProductRequest(name: $0.name, quantity: $0.quantity, unit: $0.unit, notes: $0.notes)
        })
        messages.append(ChatMessage(
            role: .agent,
            text: "Agregué los productos de tu compra anterior al borrador.",
            kind: .draftUpdate
        ))
        selectedTab = .agent
        persist()
    }

    func compare(postalCode: String) async {
        guard loadingState == .idle else { return }
        setLocation(postalCode)
        comparisonPlan = nil
        loadingState = .comparing
        do {
            comparisonPlan = try await comparisonService.compare(
                items: draft.items,
                postalCode: postalCode
            )
            loadingState = .idle
            persist()
        } catch {
            loadingState = .failed(message: "No fue posible crear la comparación.")
        }
    }

    func completeComparison() {
        guard let comparisonPlan, comparisonPlan.responseStatus != .partial, comparisonPlan.responseStatus != .error else { return }
        orders.insert(CompletedOrder(requestedItems: draft.items, plan: comparisonPlan), at: 0)
        messages.append(ChatMessage(
            role: .agent,
            text: "Guardé la comparación en tu historial.",
            kind: .comparison
        ))
        draft = ShoppingDraft()
        self.comparisonPlan = nil
        persist()
    }

    func clearError() {
        if case .failed = loadingState {
            loadingState = .idle
        }
    }

    private func restore(from record: LocalAppStateRecord) {
        let decoder = JSONDecoder()
        if let storedDraft = try? decoder.decode(ShoppingDraft.self, from: record.draftData) {
            draft = storedDraft
        }
        if let storedOrders = try? decoder.decode([CompletedOrder].self, from: record.ordersData) {
            orders = storedOrders
        }
        if let storedMessages = try? decoder.decode([ChatMessage].self, from: record.messagesData) {
            messages = storedMessages
        }
        postalCode = record.postalCode
        if let data = record.savingsData, let ledger = try? decoder.decode(SavingsLedger.self,from:data) { savings = ledger }
    }

    private func persist() {
        guard let record, let modelContext else { return }
        let encoder = JSONEncoder()
        record.draftData = (try? encoder.encode(draft)) ?? Data()
        record.ordersData = (try? encoder.encode(orders)) ?? Data()
        record.messagesData = (try? encoder.encode(messages)) ?? Data()
        record.postalCode = postalCode
        record.savingsData = try? encoder.encode(savings)
        try? modelContext.save()
    }
}
