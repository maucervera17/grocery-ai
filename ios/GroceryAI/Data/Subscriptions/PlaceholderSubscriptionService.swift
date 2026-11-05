import Foundation
import Observation

@MainActor
@Observable
final class PlaceholderSubscriptionService: SubscriptionServicing {
    static let isProDefaultsKey = "barasu.placeholderIsPro"

    private(set) var isPro: Bool

    let plans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: .annual,
            title: "Anual",
            priceCents: 200_000,
            periodName: "año",
            trialDays: 7
        ),
        SubscriptionPlan(
            id: .monthly,
            title: "Mensual",
            priceCents: 20_000,
            periodName: "mes",
            trialDays: nil
        )
    ]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isPro = defaults.bool(forKey: Self.isProDefaultsKey)
    }

    func purchase(_ plan: SubscriptionPlanID) async throws {
        try await Task.sleep(for: .seconds(1))
        setPro(true)
    }

    func restore() async throws -> Bool {
        isPro
    }

    func resetForDebug() {
        setPro(false)
    }

    private func setPro(_ value: Bool) {
        isPro = value
        defaults.set(value, forKey: Self.isProDefaultsKey)
    }
}
