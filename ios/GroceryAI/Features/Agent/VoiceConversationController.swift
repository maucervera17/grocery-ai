import AVFAudio
import Combine
import ElevenLabs
import Foundation
import Observation

@MainActor
@Observable
final class VoiceConversationController {
    private(set) var state: VoiceConversationState = .idle
    private(set) var feedbackText = "Hablar con Barasu"

    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let tokenClient: VoiceSessionTokenClient
    @ObservationIgnored private let connectivityProbe: VoiceConnectivityProbe
    @ObservationIgnored private let searchClient: VoiceSearchToolClient
    @ObservationIgnored private var conversation: Conversation?
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var processedUserEvents: Set<Int> = []
    @ObservationIgnored private var processedAgentEvents: Set<Int> = []
    @ObservationIgnored private var processingTool = false
    @ObservationIgnored private var noAudioFeedbackTask: Task<Void, Never>?
    @ObservationIgnored private var hasDetectedVoice = false
    @ObservationIgnored private var inputLevel = 0.0

    init(
        appState: AppState,
        tokenClient: VoiceSessionTokenClient = VoiceSessionTokenClient(),
        connectivityProbe: VoiceConnectivityProbe = VoiceConnectivityProbe(),
        searchClient: VoiceSearchToolClient = VoiceSearchToolClient()
    ) {
        self.appState = appState
        self.tokenClient = tokenClient
        self.connectivityProbe = connectivityProbe
        self.searchClient = searchClient
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
        feedbackText = "Verificando micrófono…"
        inputLevel = 0
        hasDetectedVoice = false
        processedUserEvents.removeAll()
        processedAgentEvents.removeAll()
        VoiceDiagnostics.event("Voice start requested")
        logAudioRoute(context: "Before connection")

        do {
            guard await microphoneAccessIsGranted() else {
                let message = "Permite el micrófono en Ajustes para usar la voz."
                VoiceDiagnostics.error("Voice start blocked because microphone access is unavailable")
                feedbackText = message
                state = .failed(message: message)
                return
            }

            VoiceDiagnostics.event("Microphone permission is granted")
            feedbackText = "Autenticando con Barasu…"
            let token = try await tokenClient.fetchToken()
            feedbackText = "Verificando servicio de voz…"
            try await connectivityProbe.verifyReachability()
            feedbackText = "Conectando audio…"
            let config = makeConfiguration()
            let activeConversation = try await ElevenLabs.startConversation(
                conversationToken: token,
                config: config,
                onAgentReady: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.agentDidBecomeReady()
                    }
                },
                onDisconnect: { [weak self] reason in
                    Task { @MainActor [weak self] in
                        self?.conversationDidEnd(reason: reason)
                    }
                }
            )
            conversation = activeConversation
            observe(activeConversation)
            if activeConversation.isMuted {
                VoiceDiagnostics.event("SDK reported a muted microphone after startup; requesting unmute")
                try await activeConversation.setMuted(false)
            }
            VoiceDiagnostics.event("Voice conversation is active; muted=\(activeConversation.isMuted)")
            logAudioRoute(context: "After connection")
            state = .listening
            feedbackText = "Micrófono activo • habla ahora"
            scheduleNoAudioFeedback()
        } catch is CancellationError {
            VoiceDiagnostics.event("Voice startup was cancelled")
            feedbackText = "Hablar con Barasu"
            state = .idle
        } catch {
            VoiceDiagnostics.error("Voice start failed: \(error.localizedDescription)")
            let message = userFacingMessage(for: error)
            feedbackText = message
            state = .failed(message: message)
        }
    }

    func endConversation() async {
        guard state.isActive || conversation != nil else { return }
        let activeConversation = conversation
        conversation = nil
        cancellables.removeAll()
        noAudioFeedbackTask?.cancel()
        noAudioFeedbackTask = nil
        processingTool = false
        inputLevel = 0
        feedbackText = "Hablar con Barasu"
        state = .idle
        VoiceDiagnostics.event("Voice conversation ended by the user")
        await activeConversation?.endConversation()
    }

    private func makeConfiguration() -> ConversationConfig {
        ConversationConfig(
            conversationOverrides: ConversationOverrides(textOnly: false),
            onStartupStateChange: { [weak self] startupState in
                Task { @MainActor [weak self] in
                    self?.receiveStartupState(startupState)
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
            onInterruption: { [weak self] eventID in
                Task { @MainActor [weak self] in
                    self?.receiveInterruption(eventID: eventID)
                }
            },
            onVadScore: { [weak self] score in
                Task { @MainActor [weak self] in
                    self?.receiveVadScore(score)
                }
            },
            onUnhandledClientToolCall: { [weak self] toolCall in
                Task { @MainActor [weak self] in
                    await self?.handle(toolCall)
                }
            }
        )
    }

    private func microphoneAccessIsGranted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            true
        case .undetermined:
            await AVAudioApplication.requestRecordPermission()
        case .denied:
            false
        @unknown default:
            false
        }
    }

    private func receiveStartupState(_ startupState: ConversationStartupState) {
        VoiceDiagnostics.event("ElevenLabs startup state: \(String(describing: startupState))")
        switch startupState {
        case .idle:
            feedbackText = "Preparando voz…"
        case .resolvingToken:
            feedbackText = "Validando sesión…"
        case .connectingRoom:
            feedbackText = "Conectando audio…"
        case .waitingForAgent:
            feedbackText = "Esperando a Barasu…"
        case .agentReady:
            feedbackText = "Barasu conectado…"
        case .sendingConversationInit:
            feedbackText = "Preparando conversación…"
        case .active:
            feedbackText = "Micrófono activo • habla ahora"
        case .failed:
            feedbackText = "Falló la conexión de voz"
        }
    }

    private func agentDidBecomeReady() {
        VoiceDiagnostics.event("ElevenLabs agent reported ready")
        feedbackText = "Barasu conectado • habla ahora"
    }

    private func observe(_ conversation: Conversation) {
        cancellables.removeAll()
        conversation.$agentState
            .sink { [weak self] agentState in
                guard let self, state.isActive, state != .muted else { return }
                switch agentState {
                case .listening:
                    state = .listening
                    feedbackText = hasDetectedVoice
                        ? "Listo para seguir escuchando"
                        : "Micrófono activo • habla ahora"
                    scheduleNoAudioFeedback()
                case .thinking:
                    state = .thinking
                    feedbackText = "Entendí tu voz • procesando…"
                    inputLevel = 0
                case .speaking:
                    state = .speaking
                    feedbackText = "Barasu está respondiendo…"
                    inputLevel = 0
                }
                VoiceDiagnostics.event("Agent state changed: \(String(describing: agentState))")
            }
            .store(in: &cancellables)

        conversation.$isMuted
            .sink { [weak self] isMuted in
                guard let self, state.isActive else { return }
                state = isMuted ? .muted : .listening
                feedbackText = isMuted ? "Micrófono silenciado" : "Micrófono activo • habla ahora"
                VoiceDiagnostics.event("Microphone mute state changed: muted=\(isMuted)")
            }
            .store(in: &cancellables)
    }

    private func receiveUserMessage(_ text: String, eventID: Int) {
        guard processedUserEvents.insert(eventID).inserted else { return }
        VoiceDiagnostics.event("User transcript received: event=\(eventID), characters=\(text.count)")
        feedbackText = "Transcripción recibida • procesando…"
        inputLevel = 0
        appState.appendVoiceMessage(role: .user, text: text)
    }

    private func receiveAgentMessage(_ text: String, eventID: Int) {
        guard processedAgentEvents.insert(eventID).inserted else { return }
        VoiceDiagnostics.event("Agent response received: event=\(eventID), characters=\(text.count)")
        feedbackText = "Respuesta recibida"
        appState.appendVoiceMessage(role: .agent, text: text)
    }

    private func receiveInterruption(eventID: Int) {
        VoiceDiagnostics.event("Agent interruption received: event=\(eventID)")
        feedbackText = "Interrupción detectada • te escucho"
    }

    private func receiveVadScore(_ score: Double) {
        let normalizedScore = min(max(score, 0), 1)
        inputLevel = normalizedScore
        guard normalizedScore >= 0.15 else { return }

        if !hasDetectedVoice {
            VoiceDiagnostics.event("Voice activity detected by server VAD")
        }
        hasDetectedVoice = true
        noAudioFeedbackTask?.cancel()
        noAudioFeedbackTask = nil
        if state == .listening {
            feedbackText = "Detectando tu voz…"
        }
    }

    private func handle(_ toolCall: ClientToolCallEvent) async {
        guard let conversation else { return }
        VoiceDiagnostics.event("Client tool call received: name=\(toolCall.toolName), id=\(toolCall.toolCallId)")
        guard !processingTool else {
            VoiceDiagnostics.error("Client tool call rejected because another tool is running")
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
                VoiceDiagnostics.event("Voice search action received: \(parameters.action)")
                switch parameters.action {
                case "update_draft":
                    feedbackText = "Actualizando tu lista…"
                    let result = await appState.updateDraftFromVoice(parameters.message)
                    try await conversation.sendToolResult(for: toolCall.toolCallId, result: result)
                case "product_prices":
                    feedbackText = "Consultando precios…"
                    let result = try await searchClient.searchProduct(
                        message: parameters.message,
                        currentItems: appState.draft.items,
                        postalCode: appState.postalCode
                    )
                    try await conversation.sendToolResult(for: toolCall.toolCallId, result: result)
                case "select_best":
                    feedbackText = "Comparando tu lista…"
                    let result = await appState.compareFromVoice()
                    try await conversation.sendToolResult(for: toolCall.toolCallId, result: result)
                default:
                    throw VoiceToolError(error: "Esta acción todavía no está disponible en iOS: \(parameters.action).")
                }
                VoiceDiagnostics.event("Client tool result sent successfully: id=\(toolCall.toolCallId)")
            case "barasu_save":
                throw VoiceToolError(error: "Guardar ofertas todavía no está disponible en iOS.")
            default:
                throw VoiceToolError(error: "Herramienta no compatible: \(toolCall.toolName).")
            }
        } catch {
            VoiceDiagnostics.error("Client tool call failed: \(error.localizedDescription)")
            try? await conversation.sendToolResult(
                for: toolCall.toolCallId,
                result: VoiceToolError(error: error.localizedDescription),
                isError: true
            )
        }
    }

    private func scheduleNoAudioFeedback() {
        noAudioFeedbackTask?.cancel()
        guard !hasDetectedVoice else { return }
        noAudioFeedbackTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(6))
            } catch {
                return
            }
            guard let self, state == .listening, !hasDetectedVoice else { return }
            feedbackText = "No detecto voz • revisa el micrófono"
            VoiceDiagnostics.error("No VAD activity was received within six seconds of listening")
            logAudioRoute(context: "No voice activity")
        }
    }

    private func logAudioRoute(context: String) {
        let session = AVAudioSession.sharedInstance()
        let inputs = session.currentRoute.inputs
            .map { "\($0.portType.rawValue):\($0.portName)" }
            .joined(separator: ",")
        let outputs = session.currentRoute.outputs
            .map { "\($0.portType.rawValue):\($0.portName)" }
            .joined(separator: ",")
        VoiceDiagnostics.event(
            "\(context) audio route: inputs=[\(inputs)], outputs=[\(outputs)], "
                + "category=\(session.category.rawValue), mode=\(session.mode.rawValue)"
        )
    }

    private func conversationDidEnd(reason: DisconnectionReason) {
        VoiceDiagnostics.event("Voice conversation disconnected: \(String(describing: reason))")
        conversation = nil
        cancellables.removeAll()
        noAudioFeedbackTask?.cancel()
        noAudioFeedbackTask = nil
        processingTool = false
        inputLevel = 0
        feedbackText = "La conversación terminó"
        state = .idle
    }

    private func conversationDidFail(_ message: String) {
        VoiceDiagnostics.error("Voice conversation failed: \(message)")
        conversation = nil
        cancellables.removeAll()
        noAudioFeedbackTask?.cancel()
        noAudioFeedbackTask = nil
        processingTool = false
        inputLevel = 0
        feedbackText = message
        state = .failed(message: message)
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? VoiceConnectivityError {
            return localizedError.localizedDescription
        }

        let technicalMessage = error.localizedDescription.lowercased()
        if technicalMessage.contains("timed out") || technicalMessage.contains("network") {
            return "La conexión de voz tardó demasiado. Revisa tu red o VPN e inténtalo de nuevo."
        }
        return error.localizedDescription
    }
}
