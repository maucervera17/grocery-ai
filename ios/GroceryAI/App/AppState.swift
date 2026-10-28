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
    private var failedInput: String?

    init(
        agentService: any AgentServicing = GroceryAPIClient(),
        comparisonService: any ComparisonServicing = GroceryAPIClient()
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

    @discardableResult
    func send(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, loadingState != .updatingDraft, loadingState != .comparing else {
            return false
        }

        let isRetry = failedInput == trimmed
        if isRetry {
            if messages.last?.kind == .error {
                messages.removeLast()
            }
        } else {
            messages.append(ChatMessage(role: .user, text: trimmed))
        }
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
            failedInput = nil
            persist()
            return true
        } catch {
            let message = "No pude actualizar la lista. Revisa tu conexión o intenta de nuevo."
            messages.append(ChatMessage(role: .agent, text: message, kind: .error))
            loadingState = .failed(message: message)
            failedInput = trimmed
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
