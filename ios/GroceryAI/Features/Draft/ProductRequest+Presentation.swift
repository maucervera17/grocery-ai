import Foundation

extension ProductRequest {
    var quantityDescription: String {
        let formatted = quantity.formatted(.number.precision(.fractionLength(0...2)))
        let unitName = quantity == 1 ? unit.displayName : unit.pluralDisplayName
        return "\(formatted) \(unitName)"
    }
}
