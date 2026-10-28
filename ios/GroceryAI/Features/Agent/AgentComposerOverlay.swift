import SwiftUI

struct AgentComposerOverlay: View {
    @Bindable var appState: AppState
    @Bindable var composerState: AgentComposerState
    @Bindable var voiceController: VoiceConversationController

    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if case .failed = appState.loadingState {
                AgentErrorActionsView(onRetry: retry, onDismiss: appState.clearError)
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
                voiceFeedback: voiceController.feedbackText,
                onToggleVoice: toggleVoice
            )
        }
        .onChange(of: composerState.focusRequest) {
            inputIsFocused = true
        }
    }

    private func send() {
        let message = composerState.text
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        composerState.text = ""
        inputIsFocused = false
        Task {
            await appState.send(message)
        }
    }

    private func retry() {
        Task {
            await appState.retryFailedSend()
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
