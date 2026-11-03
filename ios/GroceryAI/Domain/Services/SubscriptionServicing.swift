import Foundation

enum SubscriptionPlanID: String, CaseIterable, Hashable, Sendable {
    case annual
    case monthly
}

struct SubscriptionPlan: Identifiable, Hashable, Sendable {
    let id: SubscriptionPlanID
    let title: String
    let priceCents: Int
    let periodName: String
    let trialDays: Int?
}

@MainActor
protocol SubscriptionServicing: AnyObject {
    var isPro: Bool { get }
    var plans: [SubscriptionPlan] { get }
    func purchase(_ plan: SubscriptionPlanID) async throws
    func restore() async throws -> Bool
    func resetForDebug()
}
