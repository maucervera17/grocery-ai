import Foundation

enum SavingsEstimator {
    struct Estimate: Equatable, Sendable {
        let lowCents: Int
        let highCents: Int

        var annualHighCents: Int { highCents * 12 }
    }

    private static let referenceMonthlySpendCents = 600_000

    private static let lowRate = 0.04
    private static let highRate = 0.09

    static func estimate(
        spend: SpendRange?,
        householdSize: HouseholdSize?
    ) -> Estimate {
        let monthlySpendCents: Int
        if let midpoint = spend?.midpointCents {
            monthlySpendCents = midpoint
        } else {
            let multiplier = (householdSize ?? .threeFour).spendMultiplier
            monthlySpendCents = Int((Double(referenceMonthlySpendCents) * multiplier).rounded())
        }

        return Estimate(
            lowCents: roundedToTenPesos(Double(monthlySpendCents) * lowRate),
            highCents: roundedToTenPesos(Double(monthlySpendCents) * highRate)
        )
    }

    private static func roundedToTenPesos(_ cents: Double) -> Int {
        Int((cents / 1_000).rounded()) * 1_000
    }
}
