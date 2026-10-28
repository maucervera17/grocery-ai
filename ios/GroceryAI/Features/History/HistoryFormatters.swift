import Foundation

enum MoneyFormatter {
    static func string(cents: Int, currencyCode: String) -> String {
        (Double(cents) / 100).formatted(.currency(code: currencyCode))
    }
}

enum ProductQuantityFormatter {
    static func string(quantity: Double, unit: ProductUnit) -> String {
        let value = quantity.formatted(.number.precision(.fractionLength(0...2)))
        return "\(value) \(unitLabel(unit))"
    }

    private static func unitLabel(_ unit: ProductUnit) -> String {
        switch unit {
        case .gram: "g"
        case .kilogram: "kg"
        case .milliliter: "ml"
        case .liter: "L"
        case .piece: "pzas."
        case .package: "paq."
        case .dozen: "doc."
        }
    }
}
