import Foundation

enum PaywallBenefit: CaseIterable, Hashable, Sendable {
    case compare
    case dictate
    case history

    var title: String {
        switch self {
        case .compare:
            "Compara tu lista completa en Walmart, Bodega Aurrera y Chedraui"
        case .dictate:
            "Escribe, dicta o pega tu lista y Barasu la arma"
        case .history:
            "Historial y repetir compra en un toque"
        }
    }

    var systemImage: String {
        switch self {
        case .compare:
            "storefront"
        case .dictate:
            "mic"
        case .history:
            "clock.arrow.circlepath"
        }
    }
}
