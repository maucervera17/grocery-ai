import Foundation

struct VoiceSessionTokenClient: Sendable {
    var baseURL: URL = APIConfiguration.baseURL
    var session: URLSession = .shared

    func fetchToken() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/voice/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceSessionError.invalidResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard !payload.conversationToken.isEmpty else {
                throw VoiceSessionError.invalidResponse
            }
            return payload.conversationToken
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
