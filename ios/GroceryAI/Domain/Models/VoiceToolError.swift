import Foundation

struct VoiceToolError: LocalizedError, Encodable, Sendable {
    let error: String

    var errorDescription: String? { error }
}
