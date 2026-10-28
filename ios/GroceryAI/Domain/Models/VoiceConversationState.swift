import Foundation

enum VoiceConversationState: Equatable, Sendable {
    case idle
    case connecting
    case listening
    case thinking
    case speaking
    case muted
    case failed(message: String)

    var isActive: Bool {
        switch self {
        case .connecting, .listening, .thinking, .speaking, .muted:
            true
        case .idle, .failed:
            false
        }
    }

    var promptOverride: String? {
        guard case let .failed(message) = self else { return nil }
        return message
    }

    var statusText: String {
        switch self {
        case .idle: "Hablar con Barasu"
        case .connecting: "Conectando…"
        case .listening: "Te escucho…"
        case .thinking: "Actualizando tu lista…"
        case .speaking: "Barasu está respondiendo…"
        case .muted: "Micrófono silenciado"
        case .failed: "Reintentar voz"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: "mic.fill"
        case .connecting: "ellipsis"
        case .listening: "waveform"
        case .thinking: "sparkles"
        case .speaking: "waveform.badge.magnifyingglass"
        case .muted: "mic.slash.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}
