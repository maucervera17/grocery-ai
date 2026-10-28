import SwiftUI

struct AgentComposerOverlay: View {
    @Bindable var appState: AppState
    @Bindable var composerState: AgentComposerState
    @Bindable var voiceController: VoiceConversationController

    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if case .failed = appState.loadingState {
                AgentErrorActionsView(onRetry: send, onDismiss: appState.clearError)
            }

            if composerState.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               appState.loadingState != .updatingDraft {
                AgentComposerSuggestionsView(
                    hasDraft: !appState.draft.isEmpty,
                    hasOrders: !appState.orders.isEmpty,
                    onInsertText: insertSuggestion,
                    onRepeatLastOrder: repeatLastOrder,
                    onShowOrders: showPreviousOrders
                )
                .padding(.vertical, AppSpacing.extraSmall)
            }

            AgentComposer(
                text: $composerState.text,
                isFocused: $inputIsFocused,
                prompt: composerPrompt,
                isLoading: appState.loadingState == .updatingDraft,
                onSend: send,
                onAddContent: showAddContent,
                voiceState: voiceController.state,
                onToggleVoice: toggleVoice
            )
        }
        .onChange(of: composerState.focusRequest) {
            inputIsFocused = true
        }
    }

    private func send() {
        let message = composerState.text
        inputIsFocused = false
        Task {
            let succeeded = await appState.send(message)
            if succeeded, composerState.text == message {
                composerState.text = ""
            }
        }
    }

    private func toggleVoice() {
        inputIsFocused = false
        Task { await voiceController.toggleConversation() }
    }

    private func showAddContent() {
        composerState.presentedSheet = .addContent(.products)
    }

    private func showPreviousOrders() {
        composerState.presentedSheet = .addContent(.orders)
    }

    private func repeatLastOrder() {
        guard let order = appState.orders.first else { return }
        appState.repeatOrder(order)
    }

    private func insertSuggestion(_ suggestion: String) {
        composerState.text = suggestion
        composerState.requestFocus()
    }

    private var composerPrompt: String {
        appState.draft.isEmpty
            ? "Agrega productos y cantidades"
            : "Agrega, cambia o quita productos"
    }
}
