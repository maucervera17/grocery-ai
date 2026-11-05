import Foundation

enum PaywallAlert: Hashable, Sendable {
    case purchaseFailed(message: String)
    case restoreFailed(message: String)
    case noPurchasesFound

    var title: String {
        switch self {
        case .purchaseFailed:
            "No pudimos completar la compra"
        case .restoreFailed:
            "No pudimos restaurar tus compras"
        case .noPurchasesFound:
            "No encontramos compras anteriores"
        }
    }

    var message: String {
        switch self {
        case .purchaseFailed(let message), .restoreFailed(let message):
            message
        case .noPurchasesFound:
            "Si ya tienes una suscripción, revisa que uses la misma cuenta de Apple."
        }
    }
}
