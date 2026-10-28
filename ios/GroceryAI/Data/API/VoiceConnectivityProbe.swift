import Foundation

struct VoiceConnectivityProbe: Sendable {
    private let endpoint = URL(string: "https://livekit.rtc.elevenlabs.io")!

    func verifyReachability() async throws {
        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 8
        )
        request.httpMethod = "GET"

        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = start.duration(to: clock.now)
            guard let response = response as? HTTPURLResponse else {
                VoiceDiagnostics.error("ElevenLabs reachability probe returned a non-HTTP response")
                throw VoiceConnectivityError.unreachable
            }

            VoiceDiagnostics.event(
                "ElevenLabs reachability probe returned HTTP \(response.statusCode) in \(elapsed)"
            )
        } catch {
            VoiceDiagnostics.error(
                "ElevenLabs reachability probe failed: \(error.localizedDescription)"
            )
            throw VoiceConnectivityError.unreachable
        }
    }
}

enum VoiceConnectivityError: LocalizedError {
    case unreachable

    var errorDescription: String? {
        "No se pudo contactar el servicio de voz. Revisa tu red o VPN e inténtalo de nuevo."
    }
}
