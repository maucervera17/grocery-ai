import SwiftUI

struct AgentView: View {
    @Bindable var appState: AppState

    @State private var input = ""
    @State private var presentedSheet: AgentSheet?
    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                        AgentStatusView(loadingState: appState.loadingState)

                        if appState.messages.isEmpty && appState.draft.isEmpty {
                            AgentEmptyStateView()
                                .frame(maxWidth: .infinity)
                                .containerRelativeFrame(.vertical, count: 5, span: 3, spacing: 0)
                        } else {
                            ForEach(appState.messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }

                            if !appState.draft.isEmpty {
                                DraftCard(
                                    draft: appState.draft,
                                    onEdit: editProduct,
                                    onDelete: appState.removeProducts,
                                    onCompare: showLocation
                                )
                                .id("draft")
                            }
                        }
                    }
                    .padding(AppSpacing.large)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: appState.messages.count) {
                    withAnimation(.snappy) {
                        if appState.draft.isEmpty {
                            proxy.scrollTo(appState.messages.last?.id, anchor: .bottom)
                        } else {
                            proxy.scrollTo("draft", anchor: .bottom)
                        }
                    }
                }
            }

            if case .failed(let message) = appState.loadingState {
                Button("Descartar error: \(message)", systemImage: "exclamationmark.circle", action: appState.clearError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.small)
            }

            if !appState.orders.isEmpty || !appState.frequentProducts.isEmpty {
                AgentQuickActionsView(
                    canRepeatLastOrder: !appState.orders.isEmpty,
                    onRepeatLastOrder: repeatLastOrder,
                    onAddFrequentProducts: showAddContent
                )
                .padding(.vertical, AppSpacing.extraSmall)
            }

            AgentComposer(
                text: $input,
                isFocused: $inputIsFocused,
                isLoading: appState.loadingState == .updatingDraft,
                onSend: send,
                onAddContent: showAddContent
            )
        }
        .navigationTitle("Tu súper")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Configuración", systemImage: "gearshape", action: showSettings)
            }
        }
        .sheet(item: $presentedSheet) { destination in
            AgentSheetView(destination: destination, appState: appState)
        }
        .fullScreenCover(item: $appState.comparisonPlan) { plan in
            NavigationStack {
                ComparisonResultView(plan: plan, onDone: appState.completeComparison)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") {
                                appState.comparisonPlan = nil
                            }
                        }
                    }
            }
        }
    }

    private func send() {
        let message = input
        input = ""
        inputIsFocused = false
        Task { await appState.send(message) }
    }

    private func editProduct(_ product: ProductRequest) {
        presentedSheet = .editProduct(product)
    }

    private func showAddContent() {
        presentedSheet = .addContent
    }

    private func showLocation() {
        presentedSheet = .location
    }

    private func showSettings() {
        presentedSheet = .settings
    }

    private func repeatLastOrder() {
        guard let order = appState.orders.first else { return }
        appState.repeatOrder(order)
    }
}
