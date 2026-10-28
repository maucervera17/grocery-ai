import Foundation

struct VoiceDraftToolResult: Encodable, Sendable {
    let reply: String
    let status: String
    let draftItems: [ProductRequest]

    enum CodingKeys: String, CodingKey {
        case reply
        case status
        case draftItems = "draft_items"
    }
}
