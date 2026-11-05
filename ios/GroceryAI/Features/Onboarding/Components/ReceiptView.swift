import SwiftUI

struct ReceiptView: View {
    struct Line: Identifiable {
        let id = UUID()
        let label: String
        var secondary: String?
        var price: String
        var logoAssetName: String?
        var priceIsSuccess = false
    }

    var title: String?
    var logoAssetName: String?
    var logoName: String?
    var lines: [Line] = []
    var totalLabel: String?
    var totalPrice: String?
    var stamp: String?
    var footerText: String?
    var showTornEdge = true

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                if title != nil || logoAssetName != nil {
                    header(colors: colors)
                }
                ForEach(lines) { line in
                    lineRow(line, colors: colors)
                    if line.id != lines.last?.id || totalPrice != nil {
                        dashedSeparator(colors: colors)
                    }
                }
                if let totalPrice {
                    HStack {
                        Text(totalLabel ?? "Total")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colors.textPrimary)
                        Spacer()
                        Text(totalPrice)
                            .font(.title3.weight(.semibold))
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(colors.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                }
                if let footerText {
                    Text(footerText)
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.extraSmall)
                }
            }
            .padding(AppSpacing.large)
            .padding(.bottom, showTornEdge ? 6 : 0)
        }
        .background {
            ReceiptPaperShape(tornEdge: showTornEdge)
                .fill(paperColor)
                .shadow(color: shadowColor, radius: 12, y: 4)
        }
        .overlay {
            if colorScheme == .light {
                ReceiptPaperShape(tornEdge: showTornEdge)
                    .stroke(theme.colors(for: colorScheme).borderSubtle, lineWidth: 0.5)
            }
        }
        .clipShape(ReceiptPaperShape(tornEdge: showTornEdge))
        .overlay(alignment: .topTrailing) {
            if let stamp {
                Text(stamp)
                    .font(.caption2.bold())
                    .foregroundStyle(stampColor)
                    .padding(.horizontal, AppSpacing.small)
                    .padding(.vertical, AppSpacing.extraSmall)
                    .background(colors.statusSuccess.opacity(0.14), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(paperColor, lineWidth: 2)
                    }
                    .offset(y: -AppSpacing.small)
            }
        }
    }

    private func header(colors: AppThemeColors) -> some View {
        HStack(spacing: AppSpacing.medium) {
            if let logoAssetName {
                logoTile(logoAssetName)
            }
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
            }
            if let logoName {
                Text(logoName)
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func lineRow(_ line: Line, colors: AppThemeColors) -> some View {
        // Accessibility sizes: price below the label so names never break mid-word.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.extraSmall))
            : AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.medium))
        return layout {
            if let logo = line.logoAssetName {
                logoTile(logo)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(line.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colors.textPrimary)
                if let secondary = line.secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: AppSpacing.small)
            }
            Text(line.price)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(line.priceIsSuccess ? stampColor : colors.textPrimary)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private func logoTile(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 18)
            .frame(width: 28, height: 28)
            .background(.white, in: .rect(cornerRadius: 8))
    }

    private func dashedSeparator(colors: AppThemeColors) -> some View {
        DashedLine()
            .stroke(
                colors.borderSubtle,
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
            .frame(height: 1)
    }

    private var stampColor: Color {
        colorScheme == .dark
            ? theme.colors(for: colorScheme).statusSuccess
            : Color(red: 0.082, green: 0.478, blue: 0.22)
    }

    private var paperColor: Color {
        let colors = theme.colors(for: colorScheme)
        return colorScheme == .dark ? colors.surfaceElevated : colors.cellBackground
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.06)
    }
}

struct ReceiptPaperShape: Shape {
    var tornEdge = true
    var cornerRadius: CGFloat = 18
    var toothWidth: CGFloat = 10
    var toothDepth: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let bottom = tornEdge ? rect.maxY - toothDepth : rect.maxY

        path.move(to: CGPoint(x: r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        if tornEdge {
            let count = max(1, (rect.width / toothWidth).rounded())
            let tooth = rect.width / count
            var x = rect.maxX
            while x > rect.minX {
                let mid = x - tooth / 2
                let next = max(x - tooth, rect.minX)
                path.addLine(to: CGPoint(x: mid, y: rect.maxY))
                path.addLine(to: CGPoint(x: next, y: bottom))
                x = next
            }
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: bottom))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}
