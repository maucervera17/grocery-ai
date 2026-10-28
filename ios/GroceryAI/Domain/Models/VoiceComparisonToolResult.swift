import Foundation

struct VoiceComparisonToolResult: Encodable, Sendable {
    let reply: String
    let status: String
    let totalPriceCents: Int?
    let storeCount: Int
    let unmatchedCount: Int

    enum CodingKeys: String, CodingKey {
        case reply
        case status
        case totalPriceCents = "total_price_cents"
        case storeCount = "store_count"
        case unmatchedCount = "unmatched_count"
    }
}
