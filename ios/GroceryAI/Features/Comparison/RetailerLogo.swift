import SwiftUI

struct RetailerLogo: View {
    let retailerID: RetailerID
    let retailerName: String

    var body: some View {
        Group {
            switch retailerID {
            case .chedraui:
                Image(.retailerChedraui)
                    .resizable()
                    .scaledToFit()
            case .bodegaAurrera:
                Image(.retailerBodegaAurrera)
                    .resizable()
                    .scaledToFit()
            case .walmart:
                Image(.retailerWalmart)
                    .resizable()
                    .scaledToFit()
            case .unknown:
                Image(systemName: "storefront")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 32)
        .accessibilityLabel(retailerName)
    }
}
