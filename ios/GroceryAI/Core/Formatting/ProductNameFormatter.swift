import Foundation

enum ProductNameFormatter {
    /// "papel de baño" → "Papel de baño". Leaves the rest of the name untouched.
    static func display(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return trimmed }
        return String(first).uppercased(with: Locale(identifier: "es_MX")) + trimmed.dropFirst()
    }
}
