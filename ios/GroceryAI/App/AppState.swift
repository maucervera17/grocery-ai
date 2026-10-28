import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .agent
    var draft = ShoppingDraft()
    var messages = MockFixtures.welcomeMessages
    var orders: [CompletedOrder] = MockFixtures.previousOrders
    var postalCode = ""
    var loadingState: ChatLoadingState = .idle
    var comparisonPlan: ComparisonPlan?

    private let agentService: any AgentServicing
    private let comparisonService: any ComparisonServicing
    private var modelContext: ModelContext?
    private var record: LocalAppStateRecord?

    init(
        agentService: any AgentServicing = MockAgentService(),
        comparisonService: any ComparisonServicing = MockComparisonService()
    ) {
        self.agentService = agentService
        self.comparisonService = comparisonService
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
        do {
            let response = try await agentService.updateDraft(
                message: trimmed,
                currentItems: draft.items
            )
            draft.replaceItems(with: response.draftItems)
            messages.append(ChatMessage(role: .agent, text: response.reply, kind: .draftUpdate))
            loadingState = .idle
            persist()
        } catch {
            let message = "No pude interpretar esa lista. Prueba con: 2 litros de leche, 12 huevos."
            messages.append(ChatMessage(role: .agent, text: message, kind: .error))
            loadingState = .failed(message: message)
        }
    }

    func updateProduct(_ product: ProductRequest) {
        guard let index = draft.items.firstIndex(where: { $0.id == product.id }) else { return }
        draft.items[index] = product
        draft.updatedAt = .now
        persist()
    }

    func removeProducts(at offsets: IndexSet) {
        draft.items.remove(atOffsets: offsets)
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
        draft.updatedAt = .now
        persist()
    }

    func repeatOrder(_ order: CompletedOrder) {
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
        self.postalCode = postalCode
        loadingState = .comparing
        do {
            try await Task.sleep(for: .milliseconds(900))
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
        guard let comparisonPlan else { return }
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
}
