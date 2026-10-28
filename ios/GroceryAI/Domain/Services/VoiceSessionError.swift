import Foundation

enum VoiceSessionError: LocalizedError, Sendable {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "El servidor devolvió una sesión de voz inválida."
        case let .server(message):
            message
        }
    }
}
