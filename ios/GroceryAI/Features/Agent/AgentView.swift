import SwiftUI

struct AgentView: View {
    @Bindable var appState: AppState
    @Bindable var composerState: AgentComposerState
    @Bindable var voiceController: VoiceConversationController

    @State private var composerContentMargin = AppControlSize.composer + (AppSpacing.medium * 2)
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isShowingNewListConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                if appState.messages.isEmpty && appState.draft.isEmpty {
                    AgentEmptyStateView()
                        .containerRelativeFrame(.vertical) { length, _ in
                            max(0, length - scrollClearance)
                        }
                } else {
                    ForEach(appState.messages) { message in
                        ChatMessageBubble(message: message)
                            .id(message.id)
                    }

                    switch appState.loadingState {
                    case .updatingDraft, .comparing:
                        AgentActivityIndicatorView(loadingState: appState.loadingState)
                            .id("agent-activity")
                    case .idle, .failed:
                        EmptyView()
                    }

                    if !appState.draft.isEmpty {
                        DraftCard(
                            draft: appState.draft,
                            imageURLs: appState.draftProductImageURLs,
                            onEdit: editProduct,
                            onDelete: appState.removeProducts,
                            onCompare: showLocation
                        )
                        .id("draft")
                    }
                }

                Color.clear
                    .frame(height: scrollClearance)
                    .id("composer-clearance")
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.large)
        }
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.top, for: .alignment)
        .scrollPosition($scrollPosition)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: appState.messages.count) {
            withAnimation(.snappy) {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
        .onChange(of: composerContentMargin) { previousHeight, height in
            guard height > previousHeight else { return }
            Task { @MainActor in
                await Task.yield()
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                BottomContentFade()
                    .frame(height: composerContentMargin + AppControlSize.bottomContentFadeExtension)
                    .ignoresSafeArea(edges: .bottom)

                AgentComposerOverlay(
                    appState: appState,
                    composerState: composerState,
                    voiceController: voiceController
                )
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { measuredHeight in
                        updateComposerContentMargin(measuredHeight)
                    }
            }
        }
        .navigationTitle("Barasu")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Nueva lista", systemImage: "square.and.pencil", action: showNewListConfirmation)
                    .labelStyle(.iconOnly)
                    .disabled(!appState.canStartNewList)
                    .confirmationDialog(
                        "¿Empezar una nueva lista?",
                        isPresented: $isShowingNewListConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Nueva lista", role: .destructive, action: startNewList)
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Se eliminarán el borrador y los mensajes actuales. Tu historial de compras se conservará.")
                    }

                Button("Configuración", systemImage: "gearshape", action: showSettings)
                    .labelStyle(.iconOnly)
            }
        }
        .sheet(item: $composerState.presentedSheet) { destination in
            AgentSheetView(destination: destination, appState: appState)
        }
        .fullScreenCover(item: $appState.comparisonPlan) { plan in
            NavigationStack {
                ComparisonResultView(plan: plan, onDone: appState.completeComparison)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar", systemImage: "xmark") {
                                appState.comparisonPlan = nil
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
            }
        }
    }

    private func editProduct(_ product: ProductRequest) {
        composerState.presentedSheet = .editProduct(product)
    }

    private func showLocation() {
        composerState.presentedSheet = .location
    }

    private func showSettings() {
        composerState.presentedSheet = .settings
    }

    private func showNewListConfirmation() {
        isShowingNewListConfirmation = true
    }

    private func updateComposerContentMargin(_ measuredHeight: CGFloat) {
        composerContentMargin = max(composerContentMargin, measuredHeight)
    }

    private var scrollClearance: CGFloat {
        composerContentMargin + AppControlSize.composerScrollClearance
    }

    private func startNewList() {
        Task {
            await voiceController.endConversation()
            composerState.text = ""
            composerState.presentedSheet = nil
            appState.startNewList()
        }
    }
}
