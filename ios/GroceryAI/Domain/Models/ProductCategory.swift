import Foundation

enum ProductCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case produce
    case dairy
    case eggs
    case meat
    case bakery
    case pantry
    case beverages
    case frozen
    case household
    case personalCare = "personal_care"
    case other

    var fallbackEmoji: String {
        switch self {
        case .produce: "🍎"
        case .dairy: "🥛"
        case .eggs: "🥚"
        case .meat: "🥩"
        case .bakery: "🍞"
        case .pantry: "🥫"
        case .beverages: "🧃"
        case .frozen: "❄️"
        case .household: "🧻"
        case .personalCare: "🧴"
        case .other: "🛒"
        }
    }

    static func inferred(from productName: String) -> ProductCategory {
        let name = productName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_MX"))

        let categories: [(ProductCategory, [String])] = [
            (.produce, ["aguacate", "cebolla", "jitomate", "limon", "manzana", "naranja", "papa", "platano", "tomate", "zanahoria"]),
            (.dairy, ["crema", "leche", "mantequilla", "queso", "yogur"]),
            (.eggs, ["huevo"]),
            (.meat, ["carne", "cerdo", "jamon", "pollo", "salchicha"]),
            (.bakery, ["bolillo", "pan", "tortilla"]),
            (.pantry, ["aceite", "arroz", "atun", "avena", "azucar", "frijol", "harina", "pasta", "sal"]),
            (.beverages, ["agua", "cafe", "jugo", "refresco", "te"]),
            (.frozen, ["congelado", "helado"]),
            (.household, ["detergente", "jabon para", "limpiador", "papel", "servilleta"]),
            (.personalCare, ["champu", "desodorante", "pasta dental", "shampoo"])
        ]

        return categories.first { _, keywords in
            keywords.contains { name.contains($0) }
        }?.0 ?? .other
    }
}
