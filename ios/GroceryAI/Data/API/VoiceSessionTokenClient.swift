import Foundation

struct VoiceSessionTokenClient: Sendable {
    var baseURL: URL = APIConfiguration.baseURL
    var session: URLSession = .shared

    func fetchToken() async throws -> String {
        VoiceDiagnostics.event("Requesting temporary voice session from Barasu backend")
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/voice/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        try APIAccess.authorize(&request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            VoiceDiagnostics.error("Voice session endpoint returned a non-HTTP response")
            throw VoiceSessionError.invalidResponse
        }

        VoiceDiagnostics.event("Voice session endpoint returned HTTP \(httpResponse.statusCode)")

        if (200..<300).contains(httpResponse.statusCode) {
            let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard !payload.conversationToken.isEmpty else {
                VoiceDiagnostics.error("Voice session response contained an empty token")
                throw VoiceSessionError.invalidResponse
            }
            VoiceDiagnostics.event("Temporary voice session received successfully")
            return payload.conversationToken
        }

        if httpResponse.statusCode == 401 {
            throw VoiceSessionError.server("Acceso incorrecto. Actualiza la contraseña en Ajustes.")
        }

        let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        throw VoiceSessionError.server(error?.message ?? "No se pudo iniciar la voz.")
    }

    private struct TokenResponse: Decodable {
        let conversationToken: String

        enum CodingKeys: String, CodingKey {
            case conversationToken = "conversation_token"
        }
    }

    private struct ErrorResponse: Decodable {
        let message: String
    }
}
