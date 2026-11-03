import Foundation

struct PaywallContext: Hashable, Sendable {
    var estimatedMonthlySavingsHighCents: Int?
    var demoSavingsCents: Int?
    var demoProductCount: Int = 0
    var cadencePhrase: String?
    var prioritizedBenefits: [PaywallBenefit] = PaywallBenefit.allCases
    var householdLabel: String?
    var frequencyLabel: String?
    var postalCode: String?
    var listItemCount: Int = 0

    var orderedBenefits: [PaywallBenefit] {
        var ordered: [PaywallBenefit] = []
        for benefit in prioritizedBenefits + PaywallBenefit.allCases where !ordered.contains(benefit) {
            ordered.append(benefit)
        }
        return ordered
    }
}

struct PaywallDates: Sendable {
    var now: Date = .init()

    var reminderDate: Date {
        Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now
    }

    var chargeDate: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
    }

    func formatted(_ date: Date) -> String {
        Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

extension PaywallContext {
    static let preview = PaywallContext(
        estimatedMonthlySavingsHighCents: 54_000,
        demoSavingsCents: 990,
        demoProductCount: 2,
        cadencePhrase: "tu próxima compra semanal",
        prioritizedBenefits: [.dictate, .compare]
    )
}
