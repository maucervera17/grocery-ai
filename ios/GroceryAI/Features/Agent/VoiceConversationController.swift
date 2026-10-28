import Combine
import ElevenLabs
import Foundation
import Observation

@MainActor
@Observable
final class VoiceConversationController {
    private(set) var state: VoiceConversationState = .idle

    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let tokenClient: VoiceSessionTokenClient
    @ObservationIgnored private var conversation: Conversation?
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var processedUserEvents: Set<Int> = []
    @ObservationIgnored private var processedAgentEvents: Set<Int> = []
    @ObservationIgnored private var processingTool = false

    init(
        appState: AppState,
        tokenClient: VoiceSessionTokenClient = VoiceSessionTokenClient()
    ) {
        self.appState = appState
        self.tokenClient = tokenClient
    }

    func toggleConversation() async {
        if state.isActive {
            await endConversation()
        } else {
            await startConversation()
        }
    }

    func startConversation() async {
        guard !state.isActive else { return }

        state = .connecting
        processedUserEvents.removeAll()
        processedAgentEvents.removeAll()

        do {
            let token = try await tokenClient.fetchToken()
            let config = makeConfiguration()
            let activeConversation = try await ElevenLabs.startConversation(
                conversationToken: token,
                config: config
            )
            conversation = activeConversation
            observe(activeConversation)
            state = .listening
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    func endConversation() async {
        guard state.isActive || conversation != nil else { return }
        let activeConversation = conversation
        conversation = nil
        cancellables.removeAll()
        processingTool = false
        state = .idle
        await activeConversation?.endConversation()
    }

    private func makeConfiguration() -> ConversationConfig {
        ConversationConfig(
            conversationOverrides: ConversationOverrides(textOnly: false),
            onDisconnect: { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.conversationDidEnd()
                }
            },
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.conversationDidFail(error.localizedDescription)
                }
            },
            onAgentResponse: { [weak self] text, eventID in
                Task { @MainActor [weak self] in
                    self?.receiveAgentMessage(text, eventID: eventID)
                }
            },
            onUserTranscript: { [weak self] text, eventID in
                Task { @MainActor [weak self] in
                    self?.receiveUserMessage(text, eventID: eventID)
                }
            },
            onUnhandledClientToolCall: { [weak self] toolCall in
                Task { @MainActor [weak self] in
                    await self?.handle(toolCall)
                }
            }
        )
    }

    private func observe(_ conversation: Conversation) {
        cancellables.removeAll()
        conversation.$agentState
            .sink { [weak self] agentState in
                guard let self, state.isActive, state != .muted else { return }
                switch agentState {
                case .listening:
                    state = .listening
                case .thinking:
                    state = .thinking
                case .speaking:
                    state = .speaking
                }
            }
            .store(in: &cancellables)

        conversation.$isMuted
            .sink { [weak self] isMuted in
                guard let self, state.isActive else { return }
                state = isMuted ? .muted : .listening
            }
            .store(in: &cancellables)
    }

    private func receiveUserMessage(_ text: String, eventID: Int) {
        guard processedUserEvents.insert(eventID).inserted else { return }
        appState.appendVoiceMessage(role: .user, text: text)
    }

    private func receiveAgentMessage(_ text: String, eventID: Int) {
        guard processedAgentEvents.insert(eventID).inserted else { return }
        appState.appendVoiceMessage(role: .agent, text: text)
    }

    private func handle(_ toolCall: ClientToolCallEvent) async {
        guard let conversation else { return }
        guard !processingTool else {
            try? await conversation.sendToolResult(
                for: toolCall.toolCallId,
                result: VoiceToolError(error: "Hay una operación en curso."),
                isError: true
            )
            return
        }

        processingTool = true
        defer { processingTool = false }

        do {
            switch toolCall.toolName {
            case "barasu_search":
                let parameters = try JSONDecoder().decode(
                    VoiceSearchParameters.self,
                    from: toolCall.parametersData
                )
                guard parameters.action == "update_draft" else {
                    throw VoiceToolError(error: "En iOS, la voz por ahora permite agregar, cambiar y quitar productos de la lista.")
                }
                let result = await appState.updateDraftFromVoice(parameters.message)
                try await conversation.sendToolResult(for: toolCall.toolCallId, result: result)
            case "barasu_save":
                throw VoiceToolError(error: "Guardar ofertas todavía no está disponible en iOS.")
            default:
                throw VoiceToolError(error: "Herramienta no compatible: \(toolCall.toolName).")
            }
        } catch {
            try? await conversation.sendToolResult(
                for: toolCall.toolCallId,
                result: VoiceToolError(error: error.localizedDescription),
                isError: true
            )
        }
    }

    private func conversationDidEnd() {
        conversation = nil
        cancellables.removeAll()
        processingTool = false
        state = .idle
    }

    private func conversationDidFail(_ message: String) {
        conversation = nil
        cancellables.removeAll()
        processingTool = false
        state = .failed(message: message)
    }
}
