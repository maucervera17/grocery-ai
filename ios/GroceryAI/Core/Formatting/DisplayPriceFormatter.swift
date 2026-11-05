import Foundation

enum DisplayPriceFormatter {
    static func string(cents: Int) -> String {
        let fractionLength = cents.isMultiple(of: 100) ? 0 : 2
        return (Decimal(cents) / 100).formatted(
            .currency(code: "MXN")
                .locale(Locale(identifier: "es_MX"))
                .precision(.fractionLength(fractionLength))
        )
    }
}
