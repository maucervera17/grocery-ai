import SwiftUI

struct ProductThumbnail: View {
    let imageURL: URL?
    var category: ProductCategory = .other
    var size: CGFloat = 64

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        AsyncImage(url: imageURL, transaction: Transaction(animation: .easeInOut)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty where imageURL != nil:
                ProgressView()
                    .tint(colors.textSecondary)
            case .empty, .failure:
                Text(category.fallbackEmoji)
                    .font(.title2)
            @unknown default:
                Text(category.fallbackEmoji)
                    .font(.title2)
            }
        }
        .frame(width: size, height: size)
        .background(colors.backgroundSecondary)
        .clipShape(.rect(cornerRadius: AppRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(colors.borderSubtle, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
