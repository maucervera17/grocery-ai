import Foundation

enum HouseholdSize: String, CaseIterable, Hashable, Sendable {
    case solo
    case two
    case threeFour
    case fivePlus

    var title: String {
        switch self {
        case .solo: "Solo para mí"
        case .two: "2 personas"
        case .threeFour: "3 a 4 personas"
        case .fivePlus: "5 o más"
        }
    }

    var systemImage: String {
        switch self {
        case .solo: "person.fill"
        case .two: "person.2.fill"
        case .threeFour: "person.3.fill"
        case .fivePlus: "person.3.fill"
        }
    }

    var spendMultiplier: Double {
        switch self {
        case .solo: 0.5
        case .two: 0.8
        case .threeFour: 1.0
        case .fivePlus: 1.3
        }
    }

    var householdPhrase: String {
        switch self {
        case .solo: "Compras solo para ti"
        case .two: "Hogar de 2 personas"
        case .threeFour: "Hogar de 3–4 personas"
        case .fivePlus: "Hogar de 5 o más"
        }
    }
}

enum ShoppingFrequency: String, CaseIterable, Hashable, Sendable {
    case severalPerWeek
    case weekly
    case biweekly
    case everyThreeWeeks
    case monthly

    var title: String {
        switch self {
        case .severalPerWeek: "Varias veces por semana"
        case .weekly: "Cada semana"
        case .biweekly: "Cada 15 días"
        case .everyThreeWeeks: "Cada 3 semanas"
        case .monthly: "Una vez al mes"
        }
    }

    var systemImage: String {
        switch self {
        case .severalPerWeek: "calendar.badge.clock"
        case .weekly: "calendar"
        case .biweekly: "calendar.circle"
        case .everyThreeWeeks: "calendar.badge.plus"
        case .monthly: "calendar.badge.minus"
        }
    }

    /// Average trips in a month (4.33 weeks).
    var tripsPerMonth: Double {
        switch self {
        case .severalPerWeek: 8.66
        case .weekly: 4.33
        case .biweekly: 2.17
        case .everyThreeWeeks: 1.43
        case .monthly: 1
        }
    }

    var cadencePhrase: String {
        switch self {
        case .severalPerWeek: "varias veces por semana"
        case .weekly: "cada semana"
        case .biweekly: "cada 15 días"
        case .everyThreeWeeks: "cada 3 semanas"
        case .monthly: "una vez al mes"
        }
    }
}

enum SpendRange: String, CaseIterable, Hashable, Sendable {
    case under2000
    case between2000and4000
    case between4000and7000
    case between7000and10000
    case over10000
    case unsure

    var title: String {
        switch self {
        case .under2000: "Menos de $2,000"
        case .between2000and4000: "$2,000 – $4,000"
        case .between4000and7000: "$4,000 – $7,000"
        case .between7000and10000: "$7,000 – $10,000"
        case .over10000: "Más de $10,000"
        case .unsure: "No estoy seguro"
        }
    }

    var systemImage: String {
        self == .unsure ? "questionmark.circle" : "banknote"
    }

    var midpointCents: Int? {
        switch self {
        case .under2000: 100_000
        case .between2000and4000: 300_000
        case .between4000and7000: 550_000
        case .between7000and10000: 850_000
        case .over10000: 1_200_000
        case .unsure: nil
        }
    }
}

enum StoreChoice: String, CaseIterable, Hashable, Sendable {
    case walmart
    case bodegaAurrera
    case chedraui
    case soriana
    case laComer
    case mercado
    case other

    static let supported: [StoreChoice] = [.walmart, .bodegaAurrera, .chedraui]

    /// "Walmart", "Walmart y Chedraui", "Walmart, Bodega Aurrera y Chedraui".
    static func joinedTitles(_ stores: [StoreChoice]) -> String {
        let titles = stores.map(\.title)
        guard let last = titles.last else { return "" }
        guard titles.count > 1 else { return last }
        return titles.dropLast().joined(separator: ", ") + " y " + last
    }
    static let comingSoon: [StoreChoice] = [.soriana, .laComer]

    var title: String {
        switch self {
        case .walmart: "Walmart"
        case .bodegaAurrera: "Bodega Aurrera"
        case .chedraui: "Chedraui"
        case .soriana: "Soriana"
        case .laComer: "La Comer"
        case .mercado: "Mercado o tianguis"
        case .other: "Otro"
        }
    }

    var retailerID: RetailerID? {
        switch self {
        case .walmart: .walmart
        case .bodegaAurrera: .bodegaAurrera
        case .chedraui: .chedraui
        default: nil
        }
    }

    var isSupportedByBarasu: Bool {
        retailerID != nil
    }

    /// Phrase used after "en": "en Walmart", "en tu mercado o tianguis".
    var spendPlacePhrase: String {
        switch self {
        case .mercado: "tu mercado o tianguis"
        case .other: "tu tienda"
        default: title
        }
    }

    var unsupportedNotice: String? {
        switch self {
        case .soriana, .laComer:
            "Aún no tenemos precios de \(title). Te mostramos cuánto costaría tu súper en las tiendas que sí comparamos."
        case .mercado, .other:
            "No tenemos precios de \(spendPlacePhrase). Te mostramos cuánto costaría tu súper en las tiendas que sí comparamos."
        default:
            nil
        }
    }

    var systemImage: String? {
        switch self {
        case .mercado: "basket"
        case .other: "ellipsis.circle"
        default: nil
        }
    }

    var logoAssetName: String? {
        switch self {
        case .walmart: "RetailerWalmart"
        case .bodegaAurrera: "RetailerBodegaAurrera"
        case .chedraui: "RetailerChedraui"
        case .soriana: "RetailerSoriana"
        case .laComer: "RetailerLaComer"
        case .mercado, .other: nil
        }
    }
}

enum ImportMethod: String, CaseIterable, Hashable, Sendable {
    case camera
    case paste
    case dictate
    case write
    case suggested

    var title: String {
        switch self {
        case .camera: "Tomar foto de tu lista"
        case .paste: "Pegar texto"
        case .dictate: "Dictar"
        case .write: "Escribir"
        case .suggested: "Usar una lista sugerida"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: "camera"
        case .paste: "doc.on.clipboard"
        case .dictate: "mic"
        case .write: "square.and.pencil"
        case .suggested: "basket"
        }
    }
}

struct OnboardingAnswers: Hashable, Sendable {
    var householdSize: HouseholdSize?
    var shoppingFrequency: ShoppingFrequency?
    var usualStore: StoreChoice?
    var comparisonStores: Set<StoreChoice> = []
    var postalCode = ""
    var spendAdjustment: SpendRange?
    var importMethod: ImportMethod?
    var importedItems: [ProductRequest] = []

    var orderedComparisonStores: [StoreChoice] {
        StoreChoice.supported.filter { comparisonStores.contains($0) }
    }

    var profile: ShoppingProfile {
        ShoppingProfile(
            householdSize: householdSize?.rawValue,
            shoppingFrequency: shoppingFrequency?.rawValue,
            usualStore: usualStore?.rawValue,
            comparisonStores: orderedComparisonStores.map(\.rawValue),
            postalCode: postalCode.isEmpty ? nil : postalCode
        )
    }
}
