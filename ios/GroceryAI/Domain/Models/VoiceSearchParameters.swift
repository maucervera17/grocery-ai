import Foundation

struct VoiceSearchParameters: Decodable, Sendable {
    let action: String
    let message: String
}
