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
    case monthly

    var title: String {
        switch self {
        case .severalPerWeek: "Varias veces por semana"
        case .weekly: "Cada semana"
        case .biweekly: "Cada 15 días"
        case .monthly: "Una vez al mes"
        }
    }

    var systemImage: String {
        switch self {
        case .severalPerWeek: "calendar.badge.clock"
        case .weekly: "calendar"
        case .biweekly: "calendar.circle"
        case .monthly: "calendar.badge.minus"
        }
    }

    var tripsPerMonth: Int {
        switch self {
        case .severalPerWeek: 10
        case .weekly: 4
        case .biweekly: 2
        case .monthly: 1
        }
    }

    var cadencePhrase: String {
        switch self {
        case .severalPerWeek: "varias veces por semana"
        case .weekly: "cada semana"
        case .biweekly: "cada 15 días"
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
    case costco
    case mercado
    case other

    var title: String {
        switch self {
        case .walmart: "Walmart"
        case .bodegaAurrera: "Bodega Aurrera"
        case .chedraui: "Chedraui"
        case .soriana: "Soriana"
        case .laComer: "La Comer"
        case .costco: "Costco"
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

    var logoAssetName: String? {
        switch self {
        case .walmart: "RetailerWalmart"
        case .bodegaAurrera: "RetailerBodegaAurrera"
        case .chedraui: "RetailerChedraui"
        case .soriana: "RetailerSoriana"
        case .laComer: "RetailerLaComer"
        case .costco: "RetailerCostco"
        case .mercado, .other: nil
        }
    }
}

enum CompareHabit: String, CaseIterable, Hashable, Sendable {
    case never
    case sometimes
    case always

    var title: String {
        switch self {
        case .never: "Nunca, compro donde siempre"
        case .sometimes: "A veces, con folletos u ofertas"
        case .always: "Siempre, aunque me toma tiempo"
        }
    }

    var systemImage: String {
        switch self {
        case .never: "cart"
        case .sometimes: "doc.text.magnifyingglass"
        case .always: "scalemass"
        }
    }

    var insightMessage: String {
        switch self {
        case .never:
            "Comprar siempre en la misma tienda puede costarte más de lo que crees."
        case .sometimes:
            "Las ofertas cambian cada semana. Barasu las revisa por ti."
        case .always:
            "Ya sabes que vale la pena. Ahora sin perder tiempo."
        }
    }
}

enum ShoppingGoal: String, CaseIterable, Hashable, Sendable {
    case saveMoney
    case saveTime
    case forgetNothing
    case organize

    var title: String {
        switch self {
        case .saveMoney: "Ahorrar dinero"
        case .saveTime: "Ahorrar tiempo"
        case .forgetNothing: "No olvidar nada"
        case .organize: "Organizar mis compras"
        }
    }

    var systemImage: String {
        switch self {
        case .saveMoney: "dollarsign.circle"
        case .saveTime: "clock"
        case .forgetNothing: "checklist"
        case .organize: "tray.full"
        }
    }
}

enum PainPoint: String, CaseIterable, Hashable, Sendable {
    case overspend
    case dontKnowCheapest
    case forgetThings
    case listTakesTime
    case repeatList

    var title: String {
        switch self {
        case .overspend: "Gasto más de lo planeado"
        case .dontKnowCheapest: "No sé dónde está más barato"
        case .forgetThings: "Se me olvidan cosas"
        case .listTakesTime: "Hacer la lista me toma tiempo"
        case .repeatList: "Repetir la misma lista cada semana"
        }
    }

    var systemImage: String {
        switch self {
        case .overspend: "arrow.up.right.circle"
        case .dontKnowCheapest: "map"
        case .forgetThings: "brain.head.profile"
        case .listTakesTime: "pencil.and.list.clipboard"
        case .repeatList: "repeat"
        }
    }
}

enum ListHabit: String, CaseIterable, Hashable, Sendable {
    case paper
    case notes
    case whatsapp
    case reminders
    case memory
    case noList

    var title: String {
        switch self {
        case .paper: "En papel"
        case .notes: "En las notas del celular"
        case .whatsapp: "En WhatsApp"
        case .reminders: "En Recordatorios"
        case .memory: "De memoria"
        case .noList: "No hago lista"
        }
    }

    var systemImage: String {
        switch self {
        case .paper: "doc.plaintext"
        case .notes: "note.text"
        case .whatsapp: "bubble.left"
        case .reminders: "checklist"
        case .memory: "brain"
        case .noList: "list.bullet"
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

    init(listHabit: ListHabit?) {
        switch listHabit {
        case .paper:
            self = .camera
        case .notes, .whatsapp, .reminders:
            self = .paste
        case .memory:
            self = .dictate
        case .noList, .none:
            self = .suggested
        }
    }
}

struct OnboardingAnswers: Hashable, Sendable {
    var householdSize: HouseholdSize?
    var shoppingFrequency: ShoppingFrequency?
    var monthlySpend: SpendRange?
    var usualStores: Set<StoreChoice> = []
    var comparesToday: CompareHabit?
    var goals: [ShoppingGoal] = []
    var painPoints: Set<PainPoint> = []
    var listHabit: ListHabit?
    var postalCode = ""
    var importMethod: ImportMethod?
    var importedItems: [ProductRequest] = []
}
