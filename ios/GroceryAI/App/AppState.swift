import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .agent
    var draft = ShoppingDraft()
    var messages: [ChatMessage] = []
    var orders: [CompletedOrder] = []
    var postalCode = ""
    var loadingState: ChatLoadingState = .idle
    var comparisonPlan: ComparisonPlan?

    private let agentService: any AgentServicing
    private let comparisonService: any ComparisonServicing
    private var modelContext: ModelContext?
    private var record: LocalAppStateRecord?

    init(
        agentService: any AgentServicing = GroceryAPIClient(),
        comparisonService: any ComparisonServicing = GroceryAPIClient()
    ) {
        self.agentService = agentService
        self.comparisonService = comparisonService
    }

    var frequentProductOptions: [FrequentProductOption] {
        var productsByName: [String: FrequentProductOption] = [:]

        for order in orders {
            let lines = order.stores.flatMap(\.items)
            for product in order.requestedItems {
                let key = product.name.folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: Locale(identifier: "es_MX")
                )
                let previous = productsByName[key]
                let imageURL = previous?.imageURL
                    ?? lines.first(where: { $0.clientItemID == product.id })?.imageURL
                productsByName[key] = FrequentProductOption(
                    product: previous?.product ?? product,
                    imageURL: imageURL,
                    frequency: (previous?.frequency ?? 0) + 1
                )
            }
        }

        return productsByName.values
            .sorted { lhs, rhs in
                lhs.frequency == rhs.frequency
                    ? lhs.product.name < rhs.product.name
                    : lhs.frequency > rhs.frequency
            }
    }

    var frequentProducts: [ProductRequest] {
        frequentProductOptions.map(\.product)
    }

    var draftProductImageURLs: [UUID: URL] {
        let storedImages = frequentProductOptions.reduce(into: [String: URL]()) { images, option in
            guard let imageURL = option.imageURL else { return }
            images[normalizedProductName(option.product.name)] = imageURL
        }

        var result = draft.items.reduce(into: [UUID: URL]()) { images, product in
            images[product.id] = storedImages[normalizedProductName(product.name)]
        }

        for line in comparisonPlan?.stores.flatMap(\.items) ?? [] {
            if let imageURL = line.imageURL {
                result[line.clientItemID] = imageURL
            }
        }

        return result
    }

    var canStartNewList: Bool {
        loadingState == .idle && (!draft.isEmpty || !messages.isEmpty || comparisonPlan != nil)
    }

    func configurePersistence(_ context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context

        let descriptor = FetchDescriptor<LocalAppStateRecord>()
        if let stored = try? context.fetch(descriptor).first {
            record = stored
            restore(from: stored)
            seedDemoContentIfNeeded()
            persist()
        } else {
            let newRecord = LocalAppStateRecord()
            context.insert(newRecord)
            record = newRecord
            seedDemoContentIfNeeded()
            persist()
        }
    }

    @discardableResult
    func send(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, loadingState != .updatingDraft, loadingState != .comparing else {
            return false
        }

        messages.append(ChatMessage(role: .user, text: trimmed))
        loadingState = .updatingDraft
        do {
            let response = try await agentService.updateDraft(
                message: trimmed,
                currentItems: draft.items
            )
            comparisonPlan = nil
            draft.replaceItems(with: response.draftItems)
            messages.append(ChatMessage(role: .agent, text: response.reply, kind: .draftUpdate))
            loadingState = .idle
            persist()
            return true
        } catch {
            loadingState = .failed(message: error.localizedDescription)
            persist()
            return false
        }
    }

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

    func addProducts(_ products: [ProductRequest]) {
        guard !products.isEmpty else { return }

        for product in products {
            if let index = draft.items.firstIndex(where: {
                $0.name.localizedCaseInsensitiveCompare(product.name) == .orderedSame && $0.unit == product.unit
            }) {
                draft.items[index].quantity = product.quantity
                draft.items[index].notes = product.notes
            } else {
                draft.items.append(ProductRequest(
                    name: product.name,
                    quantity: product.quantity,
                    unit: product.unit,
                    notes: product.notes
                ))
            }
        }

        comparisonPlan = nil
        draft.updatedAt = .now
        let count = products.count
        messages.append(ChatMessage(
            role: .agent,
            text: count == 1 ? "Agregué 1 producto al borrador." : "Agregué \(count) productos al borrador.",
            kind: .draftUpdate
        ))
        loadingState = .idle
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
        ComparisonDiagnostics.event(
            "App comparison requested: items=\(draft.items.count), postalCodeLength=\(postalCode.count)"
        )
        self.postalCode = postalCode
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
            ComparisonDiagnostics.error("App comparison failed: \(error.localizedDescription)")
            loadingState = .failed(message: error.localizedDescription)
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

    func startNewList() {
        guard loadingState == .idle else { return }
        draft = ShoppingDraft()
        messages = []
        comparisonPlan = nil
        selectedTab = .agent
        persist()
    }

    func clearError() {
        if case .failed = loadingState {
            loadingState = .idle
        }
    }

    func appendVoiceMessage(role: ChatRole, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: role, text: trimmed))
        persist()
    }

    func updateDraftFromVoice(_ message: String) async -> VoiceDraftToolResult {
        guard loadingState == .idle else {
            return VoiceDraftToolResult(
                reply: "Hay otra operación en curso.",
                status: "busy",
                draftItems: draft.items
            )
        }

        loadingState = .updatingDraft
        do {
            let response = try await agentService.updateDraft(
                message: message,
                currentItems: draft.items
            )
            comparisonPlan = nil
            draft.replaceItems(with: response.draftItems)
            loadingState = .idle
            persist()
            return VoiceDraftToolResult(
                reply: response.reply,
                status: response.status.rawValue,
                draftItems: response.draftItems
            )
        } catch {
            loadingState = .idle
            return VoiceDraftToolResult(
                reply: "No pude actualizar la lista. Se conservó el borrador anterior.",
                status: "error",
                draftItems: draft.items
            )
        }
    }

    func compareFromVoice() async -> VoiceComparisonToolResult {
        guard loadingState == .idle else {
            return VoiceComparisonToolResult(
                reply: "Hay otra operación en curso.",
                status: "busy",
                totalPriceCents: nil,
                storeCount: 0,
                unmatchedCount: draft.items.count
            )
        }
        guard !draft.isEmpty else {
            return VoiceComparisonToolResult(
                reply: "La lista está vacía. Primero agrega productos.",
                status: "empty",
                totalPriceCents: nil,
                storeCount: 0,
                unmatchedCount: 0
            )
        }

        comparisonPlan = nil
        loadingState = .comparing
        ComparisonDiagnostics.event(
            "Voice comparison requested: items=\(draft.items.count), postalCodeLength=\(postalCode.count)"
        )
        do {
            let plan = try await comparisonService.compare(
                items: draft.items,
                postalCode: postalCode
            )
            comparisonPlan = plan
            loadingState = .idle
            persist()
            let matched = plan.stores.reduce(0) { $0 + $1.items.count }
            let retailers = plan.stores.map(\.retailer).joined(separator: " y ")
            let amount = String(format: "$%.2f", Double(plan.totalPriceCents) / 100)
            let missing = plan.unmatchedItems.map { $0.requestedItem.name }
            let missingNote = missing.isEmpty ? "" : " Quedan sin opción: \(missing.joined(separator: ", "))."
            let summary = matched > 0
                ? "Encontré \(matched) de \(draft.items.count) productos en \(retailers), por \(amount) en total. Son precios publicados; confirma precio y existencias en la tienda.\(missingNote)"
                : "No encontré precios publicados comparables para esta lista. Prueba con una marca o presentación específica."
            return VoiceComparisonToolResult(
                reply: summary,
                status: plan.responseStatus?.rawValue ?? "complete",
                totalPriceCents: plan.totalPriceCents,
                storeCount: plan.stores.count,
                unmatchedCount: plan.unmatchedItems.count
            )
        } catch {
            loadingState = .idle
            ComparisonDiagnostics.error("Voice comparison failed: \(error.localizedDescription)")
            return VoiceComparisonToolResult(
                reply: "La comparación no terminó: \(error.localizedDescription). Conservé todos tus productos.",
                status: "error",
                totalPriceCents: nil,
                storeCount: 0,
                unmatchedCount: draft.items.count
            )
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
    }

    private func persist() {
        guard let record, let modelContext else { return }
        let encoder = JSONEncoder()
        record.draftData = (try? encoder.encode(draft)) ?? Data()
        record.ordersData = (try? encoder.encode(orders)) ?? Data()
        record.messagesData = (try? encoder.encode(messages)) ?? Data()
        record.postalCode = postalCode
        try? modelContext.save()
    }

    private func seedDemoContentIfNeeded() {
        guard APIConfiguration.seedsDemoContent,
              draft.isEmpty,
              orders.isEmpty,
              messages.isEmpty else { return }
        orders = MockFixtures.previousOrders
        messages = MockFixtures.welcomeMessages
    }

    private func normalizedProductName(_ name: String) -> String {
        name.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "es_MX")
        )
    }
}
