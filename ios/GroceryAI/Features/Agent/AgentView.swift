import SwiftUI

struct AgentView: View {
    @Bindable var appState: AppState

    @State private var input = ""
    @State private var presentedSheet: AgentSheet?
    @State private var editingProduct: ProductRequest?
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
        .navigationTitle("Mi súper")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Comparar", systemImage: "cart.badge.questionmark") {
                    presentedSheet = .location
                }
                .disabled(appState.draft.isEmpty)
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

    var id: String { rawValue }
}
