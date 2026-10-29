import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var appState: AppState
    @State private var composerState: AgentComposerState
    @State private var voiceController: VoiceConversationController
    @State private var errorMessage = ""
    @State private var isShowingErrorAlert = false

    init() {
        let appState = AppState()
        _appState = State(initialValue: appState)
        _composerState = State(initialValue: AgentComposerState())
        _voiceController = State(initialValue: VoiceConversationController(appState: appState))
    }

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Agente", systemImage: "bubble.left.and.bubble.right", value: AppTab.agent) {
                NavigationStack {
                    AgentView(
                        appState: appState,
                        composerState: composerState,
                        voiceController: voiceController
                    )
                }
            }

            Tab("Historial", systemImage: "clock", value: AppTab.history) {
                NavigationStack {
                    HistoryView(
                        orders: appState.orders,
                        frequentProducts: appState.frequentProductOptions,
                        onRepeatOrder: appState.repeatOrder
                    )
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .tint(BarasuPalette.accent)
        .environment(\.appTheme, .grocery)
        .task {
            appState.configurePersistence(modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await voiceController.endConversation() }
        }
        .onChange(of: appState.selectedTab) { _, tab in
            guard tab != .agent else { return }
            Task { await voiceController.endConversation() }
        }
        .onChange(of: appState.loadingState) { _, loadingState in
            presentErrorIfNeeded(loadingState)
        }
        .alert("No se pudo completar", isPresented: $isShowingErrorAlert) {
            Button("Aceptar", action: appState.clearError)
        } message: {
            Text(errorMessage)
        }
    }

    private func presentErrorIfNeeded(_ loadingState: ChatLoadingState) {
        guard case let .failed(message) = loadingState else { return }

        composerState.presentedSheet = nil
        appState.comparisonPlan = nil
        errorMessage = message
        Task { @MainActor in
            await Task.yield()
            isShowingErrorAlert = true
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: LocalAppStateRecord.self, inMemory: true)
}
